import Foundation
import CoreGraphics
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

public final class VideoFrameExtractor {
    public static let shared = VideoFrameExtractor()
    
    private init() {}
    
    /// Extracts scrolling keyframes from a screen recording video asset
    public func extractFrames(
        from asset: AVAsset,
        maxFrames: Int = 24,
        sampleIntervalSeconds: Double = 0.4
    ) async throws -> [UIImage] {
        #if canImport(UIKit)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration > 0.5 else { return [] }
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        var targetTimes: [NSValue] = []
        var t = 0.2 // skip initial notification bar / control center pull-up
        let maxTime = min(duration - 0.1, Double(maxFrames) * sampleIntervalSeconds)
        
        while t <= maxTime && targetTimes.count < maxFrames {
            let time = CMTime(seconds: t, preferredTimescale: 600)
            targetTimes.append(NSValue(time: time))
            t += sampleIntervalSeconds
        }
        
        guard !targetTimes.isEmpty else { return [] }
        
        var extractedImages: [UIImage] = []
        for val in targetTimes {
            let cmTime = val.timeValue
            if let cgImage = try? generator.copyCGImage(at: cmTime, actualTime: nil) {
                let uiImage = UIImage(cgImage: cgImage)
                // Filter out identical stationary frames
                if let last = extractedImages.last {
                    if !isFrameNearlyIdentical(last.cgImage, cgImage) {
                        extractedImages.append(uiImage)
                    }
                } else {
                    extractedImages.append(uiImage)
                }
            }
        }
        
        return extractedImages
        #else
        return []
        #endif
    }
    
    /// Quick check if two video frames are static (no scrolling movement between them)
    private func isFrameNearlyIdentical(_ imgA: CGImage?, _ imgB: CGImage?) -> Bool {
        guard let a = imgA, let b = imgB else { return false }
        guard a.width == b.width && a.height == b.height else { return false }
        
        let sampleY = a.height / 2
        let width = min(a.width, 300)
        
        guard let dataA = a.dataProvider?.data,
              let dataB = b.dataProvider?.data,
              let ptrA = CFDataGetBytePtr(dataA),
              let ptrB = CFDataGetBytePtr(dataB) else {
            return false
        }
        
        let bprA = a.bytesPerRow
        let bprB = b.bytesPerRow
        var diffSum: Int = 0
        let bytesPerPixel = a.bitsPerPixel / 8
        
        for x in stride(from: 0, to: width, by: 4) {
            let offsetA = sampleY * bprA + x * bytesPerPixel
            let offsetB = sampleY * bprB + x * bytesPerPixel
            diffSum += abs(Int(ptrA[offsetA]) - Int(ptrB[offsetB]))
        }
        
        let avgDiff = Double(diffSum) / Double(width / 4)
        return avgDiff < 4.0 // Less than 4% color variance indicates stationary screen
    }
}
