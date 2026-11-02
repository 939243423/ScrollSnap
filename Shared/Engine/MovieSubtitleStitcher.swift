import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

public final class MovieSubtitleStitcher: Sendable {
    public static let shared = MovieSubtitleStitcher()
    
    private init() {}
    
    #if canImport(UIKit)
    /// Stitches images in Movie Subtitle format:
    /// The first image is drawn in full; subsequent images only have their bottom subtitle bar cropped and stacked below.
    public func stitchMovieSubtitles(
        images: [UIImage],
        subtitleRatio: CGFloat = 0.18 // Bottom 18% of the frame
    ) -> UIImage? {
        guard let first = images.first, let firstCG = first.cgImage else { return nil }
        guard images.count > 1 else { return first }
        
        let width = CGFloat(firstCG.width)
        let firstHeight = CGFloat(firstCG.height)
        let subtitleHeight = firstHeight * subtitleRatio
        
        let totalHeight = firstHeight + subtitleHeight * CGFloat(images.count - 1)
        
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1.0
        rendererFormat.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: totalHeight), format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Draw first full movie frame
            first.draw(in: CGRect(x: 0, y: 0, width: width, height: firstHeight))
            
            // Draw subsequent subtitle slices
            var currentY = firstHeight
            for image in images.dropFirst() {
                guard let cg = image.cgImage else { continue }
                let sourceSubtitleY = CGFloat(cg.height) - subtitleHeight
                let cropRect = CGRect(x: 0, y: sourceSubtitleY, width: width, height: subtitleHeight)
                
                if let croppedSubtitle = cg.cropping(to: cropRect) {
                    let subImg = UIImage(cgImage: croppedSubtitle)
                    subImg.draw(in: CGRect(x: 0, y: currentY, width: width, height: subtitleHeight))
                    
                    // Subtle hair-line separator
                    cgContext.saveGState()
                    cgContext.setStrokeColor(UIColor.black.withAlphaComponent(0.4).cgColor)
                    cgContext.setLineWidth(1)
                    cgContext.strokeLineSegments(between: [CGPoint(x: 0, y: currentY), CGPoint(x: width, y: currentY)])
                    cgContext.restoreGState()
                }
                currentY += subtitleHeight
            }
        }
    }
    
    /// Stitches images horizontally side-by-side (Before vs After comparison)
    public func stitchHorizontalComparison(
        images: [UIImage],
        dividerWidth: CGFloat = 2.0
    ) -> UIImage? {
        guard !images.isEmpty else { return nil }
        guard images.count > 1 else { return images.first }
        
        // Normalize to the maximum height among all images
        let targetHeight = images.map { $0.size.height }.max() ?? 800
        var totalWidth: CGFloat = 0
        var scaledWidths: [CGFloat] = []
        
        for img in images {
            let scale = targetHeight / img.size.height
            let w = img.size.width * scale
            scaledWidths.append(w)
            totalWidth += w
        }
        totalWidth += dividerWidth * CGFloat(images.count - 1)
        
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1.0
        rendererFormat.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: targetHeight), format: rendererFormat)
        
        return renderer.image { context in
            var currentX: CGFloat = 0
            for (index, img) in images.enumerated() {
                let w = scaledWidths[index]
                img.draw(in: CGRect(x: currentX, y: 0, width: w, height: targetHeight))
                currentX += w
                
                if index < images.count - 1 {
                    context.cgContext.setFillColor(UIColor.separator.cgColor)
                    context.cgContext.fill(CGRect(x: currentX, y: 0, width: dividerWidth, height: targetHeight))
                    currentX += dividerWidth
                }
            }
        }
    }
    #endif
}
