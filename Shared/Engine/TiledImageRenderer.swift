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

public final class TiledImageRenderer {
    
    /// Safely stitches slices and saves directly to disk file, bypassing single-bitmap RAM limits
    public static func renderStitchedImageToFile(
        session: StitchSession,
        annotations: [AnnotationItem] = [],
        brushStrokes: [RedactionStroke] = [],
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
            var currentY: CGFloat = 0
            
            for (index, slice) in session.slices.enumerated() {
                guard let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
                      let image = UIImage(contentsOfFile: fileURL.path) else {
                    continue
                }
                
                let visibleHeight = slice.visibleHeight
                let drawRect = CGRect(x: 0, y: currentY, width: originalCanvasWidth, height: visibleHeight)
                
                cgContext.saveGState()
                cgContext.clip(to: drawRect)
                
                let imageDrawRect = CGRect(
                    x: 0,
                    y: currentY - slice.topCropInset,
                    width: originalCanvasWidth,
                    height: slice.originalHeight
                )
                image.draw(in: imageDrawRect)
                
                // Draw legacy redactions
                for redaction in slice.redactions {
                    let rX = drawRect.minX + redaction.relativeRect.minX * drawRect.width
                    let rY = drawRect.minY + redaction.relativeRect.minY * drawRect.height
                    let rW = redaction.relativeRect.width * drawRect.width
                    let rH = redaction.relativeRect.height * drawRect.height
                    let redactionRect = CGRect(x: rX, y: rY, width: rW, height: rH)
                    applyRedaction(in: cgContext, rect: redactionRect, style: redaction.style)
                }
                
                cgContext.restoreGState()
                
                let nextOverlap: CGFloat = (index + 1 < session.slices.count) ? session.slices[index + 1].effectiveOverlap : 0
                currentY += (visibleHeight - nextOverlap)
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
                
                var currentY: CGFloat = 0
                for (index, slice) in session.slices.enumerated() {
                    let sliceTop = currentY
                    let sliceBottom = currentY + slice.visibleHeight
                    
                    // Streaming check: only decode slice if it intersects this page's viewport
                    if sliceBottom > sourceY && sliceTop < pageEndY {
                        autoreleasepool {
                            if let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
                               let image = UIImage(contentsOfFile: fileURL.path) {
                                let drawRect = CGRect(x: 0, y: currentY, width: canvasWidth, height: slice.visibleHeight)
                                cgContext.saveGState()
                                cgContext.clip(to: drawRect)
                                image.draw(in: CGRect(x: 0, y: currentY - slice.topCropInset, width: canvasWidth, height: slice.originalHeight))
                                cgContext.restoreGState()
                            }
                        }
                    }
                    
                    let nextOverlap = (index + 1 < session.slices.count) ? session.slices[index + 1].effectiveOverlap : 0
                    currentY += (slice.visibleHeight - nextOverlap)
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
                applyRedaction(in: context, rect: rect, style: item.isBlackout ? .blackout : .pixelatedMosaic)
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
                context.setStrokeColor(UIColor(white: 0.12, alpha: 1.0).cgColor)
                context.addPath(path)
                context.strokePath()
                
            case .frostedGlass:
                context.setStrokeColor(UIColor.white.withAlphaComponent(0.88).cgColor)
                context.setShadow(offset: .zero, blur: 8.0 * scale, color: UIColor.white.withAlphaComponent(0.6).cgColor)
                context.addPath(path)
                context.strokePath()
                
            case .pixelateMosaic:
                context.setStrokeColor(UIColor.gray.withAlphaComponent(0.90).cgColor)
                context.setLineDash(phase: 0, lengths: [6.0 * scale, 6.0 * scale])
                context.setLineCap(.square)
                context.addPath(path)
                context.strokePath()
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

    private static func applyRedaction(in context: CGContext, rect: CGRect, style: RedactionRegion.RedactionStyle) {
        context.saveGState()
        switch style {
        case .blackout:
            context.setFillColor(UIColor.black.cgColor)
            context.fill(rect)
        case .pixelatedMosaic:
            context.setFillColor(UIColor.darkGray.withAlphaComponent(0.88).cgColor)
            context.fill(rect)
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.25).cgColor)
            context.setLineWidth(1)
            let blockSize: CGFloat = 12
            for x in stride(from: rect.minX, through: rect.maxX, by: blockSize) {
                context.strokeLineSegments(between: [CGPoint(x: x, y: rect.minY), CGPoint(x: x, y: rect.maxY)])
            }
            for y in stride(from: rect.minY, through: rect.maxY, by: blockSize) {
                context.strokeLineSegments(between: [CGPoint(x: rect.minX, y: y), CGPoint(x: rect.maxX, y: y)])
            }
        }
        context.restoreGState()
    }
    #endif
}
