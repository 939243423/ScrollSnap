import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

public final class FloatingChromeRemover: Sendable {
    public static let shared = FloatingChromeRemover()
    
    private init() {}
    
    #if canImport(UIKit)
    /// Detects and eliminates repeated floating buttons (e.g. "回到顶部", floating audio widgets, video mini-windows)
    /// that stay at fixed screen positions while the content scrolls underneath.
    public func detectFloatingOverlays(
        topImage: UIImage,
        bottomImage: UIImage,
        scrollOffset: CGFloat
    ) -> [CGRect] {
        guard let topCG = topImage.cgImage, let botCG = bottomImage.cgImage else { return [] }
        return detectFloatingOverlays(topCG: topCG, botCG: botCG, scrollOffset: scrollOffset)
    }
    
    public func detectFloatingOverlays(
        topCG: CGImage,
        botCG: CGImage,
        scrollOffset: CGFloat
    ) -> [CGRect] {
        guard abs(scrollOffset) > 20 else { return [] } // Must have actual scroll motion
        
        let width = min(topCG.width, botCG.width)
        let height = min(topCG.height, botCG.height)
        
        // Scan bottom-right and bottom-left quadrants (where floating buttons almost always live)
        let candidateZones: [CGRect] = [
            CGRect(x: CGFloat(width) * 0.72, y: CGFloat(height) * 0.65, width: CGFloat(width) * 0.25, height: CGFloat(height) * 0.25), // Bottom Right
            CGRect(x: CGFloat(width) * 0.03, y: CGFloat(height) * 0.65, width: CGFloat(width) * 0.25, height: CGFloat(height) * 0.25)  // Bottom Left
        ]
        
        var detectedOverlays: [CGRect] = []
        for zone in candidateZones {
            if isStaticRegionAcrossFrames(topCG: topCG, botCG: botCG, rect: zone) {
                detectedOverlays.append(zone)
            }
        }
        
        return detectedOverlays
    }
    
    private func isStaticRegionAcrossFrames(topCG: CGImage, botCG: CGImage, rect: CGRect) -> Bool {
        guard let topCrop = topCG.cropping(to: rect),
              let botCrop = botCG.cropping(to: rect) else {
            return false
        }
        
        // Downsample to 16x16 thumbnail to test similarity
        let size = 16
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx1 = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let ctx2 = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return false
        }
        
        ctx1.draw(topCrop, in: CGRect(x: 0, y: 0, width: size, height: size))
        ctx2.draw(botCrop, in: CGRect(x: 0, y: 0, width: size, height: size))
        
        guard let d1 = ctx1.data, let d2 = ctx2.data else { return false }
        let b1 = d1.bindMemory(to: UInt8.self, capacity: size * size)
        let b2 = d2.bindMemory(to: UInt8.self, capacity: size * size)
        
        var diffSum: Int = 0
        for i in 0..<(size * size) {
            diffSum += abs(Int(b1[i]) - Int(b2[i]))
        }
        
        let avgDiff = Double(diffSum) / Double(size * size)
        // If average pixel difference across frames is < 8 in a scrolling context, it is a static floating widget!
        return avgDiff < 8.0
    }
    #endif
}
