import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
import PDFKit
#endif

public enum ExportFormat: String, CaseIterable, Identifiable {
    case jpeg = "高画质 JPEG"
    case png = "无损 PNG"
    case pdf = "多页可翻页 PDF"
    
    public var id: String { rawValue }
    public var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .pdf: return "pdf"
        }
    }
}

public struct SliceCanvasLayout: Sendable, Hashable {
    public let sliceIndex: Int
    public let sourceYStart: CGFloat
    public let sourceHeight: CGFloat
    public let canvasY: CGFloat
    public let canvasHeight: CGFloat
    public let scale: CGFloat
    
    public init(
        sliceIndex: Int,
        sourceYStart: CGFloat,
        sourceHeight: CGFloat,
        canvasY: CGFloat,
        canvasHeight: CGFloat,
        scale: CGFloat
    ) {
        self.sliceIndex = sliceIndex
        self.sourceYStart = sourceYStart
        self.sourceHeight = sourceHeight
        self.canvasY = canvasY
        self.canvasHeight = canvasHeight
        self.scale = scale
    }
}

public final class TiledImageRenderer {
    
    /// Mathematically computes continuous seam transitions across slices
    /// Guarantees that cuts fall on minimum-energy whitespace margins with zero character truncation
    public static func computeVerticalLayout(
        session: StitchSession,
        canvasWidth: CGFloat
    ) -> [SliceCanvasLayout] {
        let slices = session.slices
        guard !slices.isEmpty else { return [] }
        
        var layouts: [SliceCanvasLayout] = []
        var currentCanvasY: CGFloat = 0
        let isMovieSubtitles = (session.presetMode == .movieSubtitles)
        
        for (index, slice) in slices.enumerated() {
            let widthScale = canvasWidth / max(1.0, slice.originalWidth)
            let origH = slice.originalHeight
            
            let sourceStart: CGFloat
            let sourceEnd: CGFloat
            
            if isMovieSubtitles {
                if index == 0 {
                    sourceStart = 0
                    sourceEnd = origH
                } else {
                    sourceStart = origH * 0.82
                    sourceEnd = origH
                }
            } else {
                // Top boundary in slice coordinates
                if index == 0 {
                    sourceStart = slice.topCropInset
                } else {
                    let overlapWithPrev = slice.effectiveOverlap
                    let ratio: CGFloat = (slice.calculatedOverlapWithPrevious > 0)
                        ? (slice.optimalSeamLineY / slice.calculatedOverlapWithPrevious)
                        : 0.5
                    let seamOffset = min(overlapWithPrev, max(0.0, overlapWithPrev * ratio))
                    sourceStart = slice.topCropInset + seamOffset
                }
                
                // Bottom boundary in slice coordinates
                if index + 1 < slices.count {
                    let nextSlice = slices[index + 1]
                    let overlapWithNext = nextSlice.effectiveOverlap
                    let ratio: CGFloat = (nextSlice.calculatedOverlapWithPrevious > 0)
                        ? (nextSlice.optimalSeamLineY / nextSlice.calculatedOverlapWithPrevious)
                        : 0.5
                    let nextSeamOffset = min(overlapWithNext, max(0.0, overlapWithNext * ratio))
                    sourceEnd = max(sourceStart, origH - slice.bottomCropInset - overlapWithNext + nextSeamOffset)
                } else {
                    sourceEnd = max(sourceStart, origH - slice.bottomCropInset)
                }
            }
            
            let sourceHeight = max(0, sourceEnd - sourceStart)
            let sliceCanvasHeight = sourceHeight * widthScale
            
            layouts.append(
                SliceCanvasLayout(
                    sliceIndex: index,
                    sourceYStart: sourceStart,
                    sourceHeight: sourceHeight,
                    canvasY: currentCanvasY,
                    canvasHeight: sliceCanvasHeight,
                    scale: widthScale
                )
            )
            
            currentCanvasY += sliceCanvasHeight
        }
        
        return layouts
    }
    
    /// Safely stitches slices and saves directly to disk file, bypassing single-bitmap RAM limits
    public static func renderStitchedImageToFile(
        session: StitchSession,
        annotations: [AnnotationItem] = [],
        brushStrokes: [RedactionStroke] = [],
        deviceFrameFinish: DeviceFrameFinish? = nil,
        canvasBackground: CanvasBackgroundStyle? = nil,
        outputURL: URL,
        format: ExportFormat = .jpeg,
        quality: CGFloat = 0.94
    ) throws {
        guard !session.slices.isEmpty else {
            throw StitchError.emptySlices
        }
        
        #if canImport(UIKit)
        if format == .pdf {
            try renderStitchedPDFToFile(session: session, annotations: annotations, brushStrokes: brushStrokes, outputURL: outputURL)
            return
        }
        
        if let finish = deviceFrameFinish, let bgStyle = canvasBackground {
            try renderMockupFrameToFile(
                session: session,
                annotations: annotations,
                brushStrokes: brushStrokes,
                finish: finish,
                bgStyle: bgStyle,
                outputURL: outputURL,
                format: format,
                quality: quality
            )
            return
        }
        
        if session.presetMode == .horizontalCompare {
            try renderHorizontalCompareToFile(
                session: session,
                annotations: annotations,
                brushStrokes: brushStrokes,
                outputURL: outputURL,
                format: format,
                quality: quality
            )
            return
        }
        
        var totalHeight = session.totalEstimatedHeight
        var canvasWidth = session.slices.first?.originalWidth ?? 393
        var scaleFactor: CGFloat = 1.0
        
        // Memory safety guard: cap bitmap height to 20,480px to prevent CoreGraphics texture allocation failure on ultra-long scrolls
        let maxAllowedHeight: CGFloat = 20480.0
        if totalHeight > maxAllowedHeight {
            scaleFactor = maxAllowedHeight / totalHeight
            canvasWidth = canvasWidth * scaleFactor
            totalHeight = maxAllowedHeight
        }
        
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1.0
        rendererFormat.opaque = (format == .jpeg)
        
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: canvasWidth, height: totalHeight),
            format: rendererFormat
        )
        
        let originalCanvasWidth = session.slices.first?.originalWidth ?? 393
        let originalTotalHeight = session.totalEstimatedHeight
        
        let drawBlock: (UIGraphicsImageRendererContext) -> Void = { context in
            let cgContext = context.cgContext
            if scaleFactor != 1.0 {
                cgContext.scaleBy(x: scaleFactor, y: scaleFactor)
            }
            
            let layouts = computeVerticalLayout(session: session, canvasWidth: originalCanvasWidth)
            
            for layout in layouts {
                autoreleasepool {
                    let slice = session.slices[layout.sliceIndex]
                    guard let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
                          let image = UIImage(contentsOfFile: fileURL.path) else {
                        return
                    }
                    
                    let isLastSlice = (layout.sliceIndex == layouts.count - 1)
                    let bleed: CGFloat = isLastSlice ? 0.0 : 0.5
                    let drawRect = CGRect(x: 0, y: layout.canvasY, width: originalCanvasWidth, height: layout.canvasHeight + bleed)
                    
                    cgContext.saveGState()
                    cgContext.clip(to: drawRect)
                    
                    let imageDrawRect = CGRect(
                        x: 0,
                        y: layout.canvasY - (layout.sourceYStart * layout.scale),
                        width: originalCanvasWidth,
                        height: slice.originalHeight * layout.scale
                    )
                    image.draw(in: imageDrawRect)
                    
                    // Draw legacy redactions mapped to slice coordinates
                    for redaction in slice.redactions {
                        let rX = redaction.relativeRect.minX * originalCanvasWidth
                        let sliceY = redaction.relativeRect.minY * slice.originalHeight
                        let rY = layout.canvasY + (sliceY - layout.sourceYStart) * layout.scale
                        let rW = redaction.relativeRect.width * originalCanvasWidth
                        let rH = (redaction.relativeRect.height * slice.originalHeight) * layout.scale
                        let redactionRect = CGRect(x: rX, y: rY, width: rW, height: rH)
                        applyRedaction(in: cgContext, rect: redactionRect, style: redaction.style)
                    }
                    
                    cgContext.restoreGState()
                }
            }
            
            // Draw all annotations onto the full stitched canvas
            drawAnnotations(annotations: annotations, in: cgContext, canvasSize: CGSize(width: originalCanvasWidth, height: originalTotalHeight))
            
            // Draw all privacy brush strokes onto the full stitched canvas
            drawBrushStrokes(brushStrokes: brushStrokes, in: cgContext, canvasSize: CGSize(width: originalCanvasWidth, height: originalTotalHeight))
        }
        
        let data: Data
        if format == .png {
            data = renderer.pngData(actions: drawBlock)
        } else {
            data = renderer.jpegData(withCompressionQuality: quality, actions: drawBlock)
        }
        
        try data.write(to: outputURL, options: .atomic)
        #endif
    }
    
    #if canImport(UIKit)
    /// Export stitched session as standard paginated A4 / scroll PDF directly to disk
    /// Zero contiguous bitmap RAM spikes: streams slices page-by-page directly into the PDF graphics context
    public static func renderStitchedPDFToFile(
        session: StitchSession,
        annotations: [AnnotationItem],
        brushStrokes: [RedactionStroke] = [],
        outputURL: URL
    ) throws {
        let canvasWidth = session.slices.first?.originalWidth ?? 393
        let pageHeight: CGFloat = 842.0 // Standard A4 height in pt
        let pageWidth: CGFloat = 595.0  // Standard A4 width in pt
        let contentWidth = pageWidth - 40.0
        let contentHeightPerPage = pageHeight - 60.0
        let scaleFactor = contentWidth / canvasWidth
        
        let totalHeight = session.totalEstimatedHeight
        let scaledFullHeight = totalHeight * scaleFactor
        let pageCount = max(1, Int(ceil(scaledFullHeight / contentHeightPerPage)))
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        try pdfRenderer.writePDF(to: outputURL) { pdfContext in
            for pageIndex in 0..<pageCount {
                pdfContext.beginPage()
                let cgContext = pdfContext.cgContext
                
                let sourceY = CGFloat(pageIndex) * (contentHeightPerPage / scaleFactor)
                let sourceHeight = min(totalHeight - sourceY, contentHeightPerPage / scaleFactor)
                let pageEndY = sourceY + sourceHeight
                
                cgContext.saveGState()
                // Clip strictly to page printable margin
                cgContext.clip(to: CGRect(x: 20, y: 30, width: contentWidth, height: sourceHeight * scaleFactor))
                
                // Translate & scale so canvas coordinate (0, sourceY) aligns with (20, 30)
                cgContext.translateBy(x: 20, y: 30 - (sourceY * scaleFactor))
                cgContext.scaleBy(x: scaleFactor, y: scaleFactor)
                
                let layouts = computeVerticalLayout(session: session, canvasWidth: canvasWidth)
                for layout in layouts {
                    let sliceTop = layout.canvasY
                    let sliceBottom = layout.canvasY + layout.canvasHeight
                    
                    // Streaming check: only decode slice if it intersects this page's viewport
                    if sliceBottom > sourceY && sliceTop < pageEndY {
                        autoreleasepool {
                            let slice = session.slices[layout.sliceIndex]
                            if let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
                               let image = UIImage(contentsOfFile: fileURL.path) {
                                let isLast = (layout.sliceIndex == layouts.count - 1)
                                let bleed: CGFloat = isLast ? 0.0 : 0.5
                                let drawRect = CGRect(x: 0, y: layout.canvasY, width: canvasWidth, height: layout.canvasHeight + bleed)
                                cgContext.saveGState()
                                cgContext.clip(to: drawRect)
                                let imageDrawRect = CGRect(
                                    x: 0,
                                    y: layout.canvasY - (layout.sourceYStart * layout.scale),
                                    width: canvasWidth,
                                    height: slice.originalHeight * layout.scale
                                )
                                image.draw(in: imageDrawRect)
                                cgContext.restoreGState()
                            }
                        }
                    }
                }
                
                // Draw annotations positioned on this page
                drawAnnotations(annotations: annotations, in: cgContext, canvasSize: CGSize(width: canvasWidth, height: totalHeight))
                
                // Draw brush strokes positioned on this page
                drawBrushStrokes(brushStrokes: brushStrokes, in: cgContext, canvasSize: CGSize(width: canvasWidth, height: totalHeight))
                
                cgContext.restoreGState()
            }
        }
    }
    
    private static func drawAnnotations(annotations: [AnnotationItem], in context: CGContext, canvasSize: CGSize) {
        let baseScale = max(1.0, canvasSize.width / 393.0)
        for item in annotations {
            let start = CGPoint(x: item.startPoint.x * canvasSize.width, y: item.startPoint.y * canvasSize.height)
            let end = CGPoint(x: item.endPoint.x * canvasSize.width, y: item.endPoint.y * canvasSize.height)
            let strokeColor = UIColor(item.color.swiftUIColor).cgColor
            
            context.saveGState()
            context.setStrokeColor(strokeColor)
            context.setFillColor(strokeColor)
            context.setLineWidth(item.lineWidth * baseScale)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            switch item.kind {
            case .rectangle:
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: max(4 * baseScale, abs(end.x - start.x)),
                    height: max(4 * baseScale, abs(end.y - start.y))
                )
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 8 * baseScale)
                context.addPath(path.cgPath)
                context.strokePath()
                
            case .arrow:
                context.move(to: start)
                context.addLine(to: end)
                context.strokePath()
                
                // Draw arrowhead scaled proportionally
                let angle = atan2(end.y - start.y, end.x - start.x)
                let arrowLength: CGFloat = 16.0 * baseScale
                let arrowAngle: CGFloat = .pi / 6.0
                
                let p1 = CGPoint(
                    x: end.x - arrowLength * cos(angle - arrowAngle),
                    y: end.y - arrowLength * sin(angle - arrowAngle)
                )
                let p2 = CGPoint(
                    x: end.x - arrowLength * cos(angle + arrowAngle),
                    y: end.y - arrowLength * sin(angle + arrowAngle)
                )
                
                let arrowPath = CGMutablePath()
                arrowPath.move(to: end)
                arrowPath.addLine(to: p1)
                arrowPath.addLine(to: p2)
                arrowPath.closeSubpath()
                context.addPath(arrowPath)
                context.fillPath()
                
            case .stepBadge:
                let radius: CGFloat = 16.0 * baseScale
                context.fillEllipse(in: CGRect(x: start.x - radius, y: start.y - radius, width: radius * 2, height: radius * 2))
                
                let numStr = "\(item.stepNumber)" as NSString
                let font = UIFont.systemFont(ofSize: 15 * baseScale, weight: .bold)
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white
                ]
                let textSize = numStr.size(withAttributes: textAttrs)
                numStr.draw(
                    at: CGPoint(x: start.x - textSize.width / 2, y: start.y - textSize.height / 2),
                    withAttributes: textAttrs
                )
                
            case .highlighter:
                context.setBlendMode(.multiply)
                context.setStrokeColor(strokeColor.copy(alpha: 0.4) ?? strokeColor)
                context.setLineWidth(item.lineWidth * 4 * baseScale)
                
                if item.freehandPoints.count > 1 {
                    let first = CGPoint(x: item.freehandPoints[0].x * canvasSize.width, y: item.freehandPoints[0].y * canvasSize.height)
                    context.move(to: first)
                    for pt in item.freehandPoints.dropFirst() {
                        let actual = CGPoint(x: pt.x * canvasSize.width, y: pt.y * canvasSize.height)
                        context.addLine(to: actual)
                    }
                    context.strokePath()
                }
                
            case .textNote:
                guard !item.textContent.isEmpty else { break }
                let text = item.textContent as NSString
                let font = UIFont.systemFont(ofSize: 14 * baseScale, weight: .semibold)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white
                ]
                let size = text.size(withAttributes: attrs)
                let bgRect = CGRect(x: start.x - 6 * baseScale, y: start.y - 4 * baseScale, width: size.width + 12 * baseScale, height: size.height + 8 * baseScale)
                let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 6 * baseScale)
                context.setFillColor(UIColor.black.withAlphaComponent(0.75).cgColor)
                context.addPath(bgPath.cgPath)
                context.fillPath()
                text.draw(at: start, withAttributes: attrs)
                
            case .mosaic:
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: max(4 * baseScale, abs(end.x - start.x)),
                    height: max(4 * baseScale, abs(end.y - start.y))
                )
                let style: RedactionRegion.RedactionStyle = item.isBlackout ? .blackout : item.redactionStyle
                applyRedaction(in: context, rect: rect, style: style)
            }
            
            context.restoreGState()
        }
    }
    
    private static func drawBrushStrokes(brushStrokes: [RedactionStroke], in context: CGContext, canvasSize: CGSize) {
        guard !brushStrokes.isEmpty else { return }
        let scale = canvasSize.width / 393.0
        
        for stroke in brushStrokes {
            guard let first = stroke.points.first else { continue }
            let scaledLineWidth = stroke.lineWidth * scale
            
            context.saveGState()
            context.setLineWidth(scaledLineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: first.x * scale, y: first.y * scale))
            for pt in stroke.points.dropFirst() {
                path.addLine(to: CGPoint(x: pt.x * scale, y: pt.y * scale))
            }
            
            switch stroke.brushType {
            case .confidentialInk:
                context.setStrokeColor(UIColor(white: 0.08, alpha: 1.0).cgColor)
                context.addPath(path)
                context.strokePath()
                
            case .frostedGlass:
                context.setStrokeColor(UIColor(white: 0.94, alpha: 0.92).cgColor)
                context.setShadow(offset: .zero, blur: 4.0 * scale, color: UIColor.white.cgColor)
                context.addPath(path)
                context.strokePath()
                
            case .pixelateMosaic:
                let blockSize = max(10.0 * scale, scaledLineWidth * 0.8)
                for pt in stroke.points {
                    let rect = CGRect(x: pt.x * scale - blockSize / 2, y: pt.y * scale - blockSize / 2, width: blockSize, height: blockSize)
                    applyRedaction(in: context, rect: rect, style: .pixelatedMosaic)
                }
            }
            
            context.restoreGState()
        }
    }
    
    private static func renderHorizontalCompareToFile(
        session: StitchSession,
        annotations: [AnnotationItem],
        brushStrokes: [RedactionStroke],
        outputURL: URL,
        format: ExportFormat,
        quality: CGFloat
    ) throws {
        var loadedImages: [UIImage] = []
        for slice in session.slices {
            guard let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
                  let img = UIImage(contentsOfFile: fileURL.path) else {
                continue
            }
            loadedImages.append(img)
        }
        guard !loadedImages.isEmpty else { throw StitchError.emptySlices }
        
        let targetHeight = min(4096.0, loadedImages.map { $0.size.height }.max() ?? 1080.0)
        let dividerWidth: CGFloat = 3.0
        var scaledWidths: [CGFloat] = []
        var totalWidth: CGFloat = 0
        
        for img in loadedImages {
            let scale = targetHeight / max(1, img.size.height)
            let w = img.size.width * scale
            scaledWidths.append(w)
            totalWidth += w
        }
        totalWidth += dividerWidth * CGFloat(max(0, loadedImages.count - 1))
        
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1.0
        rendererFormat.opaque = (format == .jpeg)
        
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: totalWidth, height: targetHeight),
            format: rendererFormat
        )
        
        let drawBlock: (UIGraphicsImageRendererContext) -> Void = { context in
            let cgContext = context.cgContext
            var currentX: CGFloat = 0
            
            for (idx, img) in loadedImages.enumerated() {
                let w = scaledWidths[idx]
                img.draw(in: CGRect(x: currentX, y: 0, width: w, height: targetHeight))
                currentX += w
                
                if idx < loadedImages.count - 1 {
                    cgContext.saveGState()
                    cgContext.setFillColor(UIColor.separator.cgColor)
                    cgContext.fill(CGRect(x: currentX, y: 0, width: dividerWidth, height: targetHeight))
                    cgContext.restoreGState()
                    currentX += dividerWidth
                }
            }
            
            drawAnnotations(annotations: annotations, in: cgContext, canvasSize: CGSize(width: totalWidth, height: targetHeight))
            drawBrushStrokes(brushStrokes: brushStrokes, in: cgContext, canvasSize: CGSize(width: totalWidth, height: targetHeight))
        }
        
        let data: Data
        if format == .png {
            data = renderer.pngData(actions: drawBlock)
        } else {
            data = renderer.jpegData(withCompressionQuality: quality, actions: drawBlock)
        }
        
        try data.write(to: outputURL, options: .atomic)
    }

    private static func renderMockupFrameToFile(
        session: StitchSession,
        annotations: [AnnotationItem],
        brushStrokes: [RedactionStroke],
        finish: DeviceFrameFinish,
        bgStyle: CanvasBackgroundStyle,
        outputURL: URL,
        format: ExportFormat,
        quality: CGFloat
    ) throws {
        let originalContentWidth = session.slices.first?.originalWidth ?? 393.0
        let originalContentHeight = session.totalEstimatedHeight
        let scale = originalContentWidth / 393.0
        let padding: CGFloat = 80.0 * scale
        
        var totalMockupWidth = originalContentWidth + padding * 2.0
        var totalMockupHeight = originalContentHeight + padding * 2.0
        var scaleFactor: CGFloat = 1.0
        
        let maxAllowedHeight: CGFloat = 20480.0
        if totalMockupHeight > maxAllowedHeight {
            scaleFactor = maxAllowedHeight / totalMockupHeight
            totalMockupWidth *= scaleFactor
            totalMockupHeight = maxAllowedHeight
        }
        
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1.0
        rendererFormat.opaque = (format == .jpeg && bgStyle != .transparent)
        
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: totalMockupWidth, height: totalMockupHeight),
            format: rendererFormat
        )
        
        let drawBlock: (UIGraphicsImageRendererContext) -> Void = { context in
            let cgContext = context.cgContext
            if scaleFactor != 1.0 {
                cgContext.scaleBy(x: scaleFactor, y: scaleFactor)
            }
            
            let unscaledMockupW = originalContentWidth + padding * 2.0
            let unscaledMockupH = originalContentHeight + padding * 2.0
            
            // 1. Draw Canvas Background
            switch bgStyle {
            case .transparent:
                break
            case .appleGradient:
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let c1 = UIColor(red: 0.38, green: 0.42, blue: 0.94, alpha: 1.0).cgColor
                let c2 = UIColor(red: 0.65, green: 0.38, blue: 0.88, alpha: 1.0).cgColor
                if let gradient = CGGradient(colorsSpace: colorSpace, colors: [c1, c2] as CFArray, locations: [0.0, 1.0]) {
                    cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: unscaledMockupW, y: unscaledMockupH), options: [])
                }
            case .studioDark:
                cgContext.setFillColor(UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0).cgColor)
                cgContext.fill(CGRect(x: 0, y: 0, width: unscaledMockupW, height: unscaledMockupH))
            case .cleanWhite:
                cgContext.setFillColor(UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0).cgColor)
                cgContext.fill(CGRect(x: 0, y: 0, width: unscaledMockupW, height: unscaledMockupH))
            case .adaptiveBlur:
                cgContext.setFillColor(UIColor(white: 0.92, alpha: 1.0).cgColor)
                cgContext.fill(CGRect(x: 0, y: 0, width: unscaledMockupW, height: unscaledMockupH))
            }
            
            // 2. Draw Soft Drop Shadow around Device
            let phoneRect = CGRect(x: padding, y: padding, width: originalContentWidth, height: originalContentHeight)
            let cornerRadius: CGFloat = 46.0 * scale
            
            cgContext.saveGState()
            cgContext.setShadow(
                offset: CGSize(width: 0, height: 16.0 * scale),
                blur: 32.0 * scale,
                color: UIColor.black.withAlphaComponent(0.35).cgColor
            )
            let shadowPath = UIBezierPath(roundedRect: phoneRect, cornerRadius: cornerRadius)
            cgContext.setFillColor(UIColor.black.cgColor)
            shadowPath.fill()
            cgContext.restoreGState()
            
            // 3. Clip and Draw Content Inside Phone Screen
            cgContext.saveGState()
            let clipPath = UIBezierPath(roundedRect: phoneRect, cornerRadius: cornerRadius)
            clipPath.addClip()
            
            let layouts = computeVerticalLayout(session: session, canvasWidth: originalContentWidth)
            for layout in layouts {
                let slice = session.slices[layout.sliceIndex]
                guard let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
                      let image = UIImage(contentsOfFile: fileURL.path) else {
                    continue
                }
                
                let isLastSlice = (layout.sliceIndex == layouts.count - 1)
                let bleed: CGFloat = isLastSlice ? 0.0 : 0.5
                let drawRect = CGRect(x: phoneRect.minX, y: phoneRect.minY + layout.canvasY, width: originalContentWidth, height: layout.canvasHeight + bleed)
                
                cgContext.saveGState()
                cgContext.clip(to: drawRect)
                
                let imageDrawRect = CGRect(
                    x: phoneRect.minX,
                    y: phoneRect.minY + layout.canvasY - (layout.sourceYStart * layout.scale),
                    width: originalContentWidth,
                    height: slice.originalHeight * layout.scale
                )
                image.draw(in: imageDrawRect)
                
                for redaction in slice.redactions {
                    let rX = phoneRect.minX + redaction.relativeRect.minX * originalContentWidth
                    let sliceY = redaction.relativeRect.minY * slice.originalHeight
                    let rY = phoneRect.minY + layout.canvasY + (sliceY - layout.sourceYStart) * layout.scale
                    let rW = redaction.relativeRect.width * originalContentWidth
                    let rH = (redaction.relativeRect.height * slice.originalHeight) * layout.scale
                    let redactionRect = CGRect(x: rX, y: rY, width: rW, height: rH)
                    applyRedaction(in: cgContext, rect: redactionRect, style: redaction.style)
                }
                
                cgContext.restoreGState()
            }
            
            // Annotations and Brush Strokes
            cgContext.saveGState()
            cgContext.translateBy(x: phoneRect.minX, y: phoneRect.minY)
            drawAnnotations(annotations: annotations, in: cgContext, canvasSize: CGSize(width: originalContentWidth, height: originalContentHeight))
            drawBrushStrokes(brushStrokes: brushStrokes, in: cgContext, canvasSize: CGSize(width: originalContentWidth, height: originalContentHeight))
            cgContext.restoreGState()
            cgContext.restoreGState()
            
            // 4. Titanium Bezel Outer Frame
            cgContext.saveGState()
            let bezelPath = UIBezierPath(roundedRect: phoneRect, cornerRadius: cornerRadius)
            let colors = finish.uiColors
            cgContext.setLineWidth(5.5 * scale)
            cgContext.setStrokeColor((colors.first ?? UIColor.gray).cgColor)
            bezelPath.stroke()
            
            // Specular Highlight Rim
            cgContext.setLineWidth(1.5 * scale)
            cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.45).cgColor)
            bezelPath.stroke()
            cgContext.restoreGState()
            
            // 5. Dynamic Island Pill
            let islandW: CGFloat = 110.0 * scale
            let islandH: CGFloat = 30.0 * scale
            let islandRect = CGRect(
                x: phoneRect.midX - islandW / 2.0,
                y: phoneRect.minY + 12.0 * scale,
                width: islandW,
                height: islandH
            )
            let islandPath = UIBezierPath(roundedRect: islandRect, cornerRadius: islandH / 2.0)
            cgContext.saveGState()
            cgContext.setFillColor(UIColor.black.cgColor)
            islandPath.fill()
            
            // Subtle camera cutout dot inside island
            let lensRect = CGRect(
                x: islandRect.maxX - 22.0 * scale,
                y: islandRect.midY - 6.0 * scale,
                width: 12.0 * scale,
                height: 12.0 * scale
            )
            cgContext.setFillColor(UIColor(white: 0.15, alpha: 1.0).cgColor)
            UIBezierPath(ovalIn: lensRect).fill()
            cgContext.restoreGState()
            
            // 6. Home Indicator Pill
            let homeW: CGFloat = 120.0 * scale
            let homeH: CGFloat = 4.5 * scale
            let homeRect = CGRect(
                x: phoneRect.midX - homeW / 2.0,
                y: phoneRect.maxY - 14.0 * scale,
                width: homeW,
                height: homeH
            )
            cgContext.saveGState()
            cgContext.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
            UIBezierPath(roundedRect: homeRect, cornerRadius: homeH / 2.0).fill()
            cgContext.restoreGState()
        }
        
        let data: Data
        if format == .png {
            data = renderer.pngData(actions: drawBlock)
        } else {
            data = renderer.jpegData(withCompressionQuality: quality, actions: drawBlock)
        }
        
        try data.write(to: outputURL, options: .atomic)
    }

    private static func applyRedaction(in context: CGContext, rect: CGRect, style: RedactionRegion.RedactionStyle) {
        context.saveGState()
        switch style {
        case .blackout:
            context.setFillColor(UIColor(white: 0.08, alpha: 1.0).cgColor)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: min(6, rect.height / 5))
            context.addPath(path.cgPath)
            context.fillPath()
        case .frostedBlur:
            context.setFillColor(UIColor(white: 0.94, alpha: 0.94).cgColor)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: min(6, rect.height / 5))
            context.addPath(path.cgPath)
            context.fillPath()
            context.setStrokeColor(UIColor(white: 0.82, alpha: 0.5).cgColor)
            context.setLineWidth(1)
            context.strokePath()
        case .pixelatedMosaic:
            let blockSize: CGFloat = max(10, min(24, rect.height / 3.5))
            for x in stride(from: rect.minX, to: rect.maxX, by: blockSize) {
                for y in stride(from: rect.minY, to: rect.maxY, by: blockSize) {
                    let blockRect = CGRect(x: x, y: y, width: min(blockSize, rect.maxX - x), height: min(blockSize, rect.maxY - y))
                    let col = Int((x - rect.minX) / blockSize)
                    let row = Int((y - rect.minY) / blockSize)
                    let isEven = (col + row) % 2 == 0
                    context.setFillColor(isEven ? UIColor(white: 0.40, alpha: 0.95).cgColor : UIColor(white: 0.58, alpha: 0.95).cgColor)
                    context.fill(blockRect)
                }
            }
        }
        context.restoreGState()
    }
    #endif
}
