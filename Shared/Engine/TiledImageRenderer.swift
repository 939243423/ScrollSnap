import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

public final class TiledImageRenderer {
    
    /// Safely stitches slices and saves directly to disk file, bypassing single-bitmap RAM limits
    public static func renderStitchedImageToFile(
        session: StitchSession,
        outputURL: URL,
        quality: CGFloat = 0.92
    ) throws {
        guard !session.slices.isEmpty else {
            throw StitchError.emptySlices
        }
        
        let totalHeight = session.totalEstimatedHeight
        let canvasWidth = session.slices.first?.originalWidth ?? 393
        
        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0 // Slices already stored in target pixel dimensions
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: canvasWidth, height: totalHeight),
            format: format
        )
        
        let renderedData = renderer.jpegData(withCompressionQuality: quality) { context in
            let cgContext = context.cgContext
            var currentY: CGFloat = 0
            
            for (index, slice) in session.slices.enumerated() {
                guard let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
                      let image = UIImage(contentsOfFile: fileURL.path) else {
                    continue
                }
                
                let visibleHeight = slice.visibleHeight
                let drawRect = CGRect(x: 0, y: currentY, width: canvasWidth, height: visibleHeight)
                
                cgContext.saveGState()
                cgContext.clip(to: drawRect)
                
                // Draw image shifted by topCropInset so cropped top region is clipped away
                let imageDrawRect = CGRect(
                    x: 0,
                    y: currentY - slice.topCropInset,
                    width: canvasWidth,
                    height: slice.originalHeight
                )
                image.draw(in: imageDrawRect)
                
                // Draw non-destructive redactions relative to visible rect
                for redaction in slice.redactions {
                    let rX = drawRect.minX + redaction.relativeRect.minX * drawRect.width
                    let rY = drawRect.minY + redaction.relativeRect.minY * drawRect.height
                    let rW = redaction.relativeRect.width * drawRect.width
                    let rH = redaction.relativeRect.height * drawRect.height
                    let redactionRect = CGRect(x: rX, y: rY, width: rW, height: rH)
                    
                    applyRedaction(in: cgContext, rect: redactionRect, style: redaction.style)
                }
                
                cgContext.restoreGState()
                
                // Advance Y by visible height minus overlap with next slice
                let nextOverlap: CGFloat
                if index + 1 < session.slices.count {
                    nextOverlap = session.slices[index + 1].effectiveOverlap
                } else {
                    nextOverlap = 0
                }
                currentY += (visibleHeight - nextOverlap)
            }
        }
        
        try renderedData.write(to: outputURL, options: .atomic)
        #endif
    }
    
    #if canImport(UIKit)
    private static func applyRedaction(in context: CGContext, rect: CGRect, style: RedactionRegion.RedactionStyle) {
        context.saveGState()
        switch style {
        case .blackout:
            context.setFillColor(UIColor.black.cgColor)
            context.fill(rect)
        case .pixelatedMosaic:
            context.setFillColor(UIColor.darkGray.withAlphaComponent(0.85).cgColor)
            context.fill(rect)
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.2).cgColor)
            context.setLineWidth(1)
            let blockSize: CGFloat = 12
            for x in stride(from: rect.minX, through: rect.maxX, by: blockSize) {
                context.strokeLineSegments(between: [CGPoint(x: x, y: rect.minY), CGPoint(x: x, y: rect.maxY)])
            }
            for y in stride(from: rect.minY, through: rect.maxY, by: blockSize) {
                context.strokeLineSegments(between: [CGPoint(x: rect.minX, y: y), CGPoint(x: rect.maxX, y: y)])
            }
        case .frostedBlur:
            context.setFillColor(UIColor.systemBackground.withAlphaComponent(0.8).cgColor)
            context.fill(rect)
        }
        context.restoreGState()
    }
    #endif
}

public enum StitchError: Error {
    case emptySlices
    case fileNotFound(String)
    case memoryLimitExceeded
    case renderFailed
}
