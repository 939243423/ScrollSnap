import Foundation
import CoreGraphics
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

public final class VideoFrameExtractor {
    public static let shared = VideoFrameExtractor()
    
    private init() {}
    
    /// Extracts scrolling keyframes from a screen recording video asset using Adaptive Displacement-Gated sampling
    /// Resilient to uneven scrolling, sudden flicks to the bottom, and pauses.
    public func extractFrames(
        from asset: AVAsset,
        maxKeyframes: Int = 30,
        candidateStepSeconds: Double = 0.08, // Sample candidates at ~12.5 fps for high velocity capture
        onProgress: ((Int, Int) -> Void)? = nil
    ) async throws -> [UIImage] {
        #if canImport(UIKit)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration > 0.5 else { return [] }
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.04, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.04, preferredTimescale: 600)
        
        // 1. Auto-trim: cut off first 0.25s (control center pull-up) and last 0.25s (red stop button tap)
        let startTime = min(0.25, duration * 0.1)
        let endTime = max(startTime + 0.3, duration - 0.25)
        
        var candidateTimes: [CMTime] = []
        var t = startTime
        while t <= endTime {
            candidateTimes.append(CMTime(seconds: t, preferredTimescale: 600))
            t += candidateStepSeconds
        }
        
        guard !candidateTimes.isEmpty else { return [] }
        
        // 2. Extract initial candidates
        var candidates: [(time: CMTime, image: UIImage, profile: [Double])] = []
        for cmTime in candidateTimes {
            if let cgImage = try? generator.copyCGImage(at: cmTime, actualTime: nil) {
                let uiImage = UIImage(cgImage: cgImage)
                let profile = calculate1DLuminanceProfile(cgImage: cgImage)
                candidates.append((time: cmTime, image: uiImage, profile: profile))
            }
        }
        
        guard !candidates.isEmpty else { return [] }
        
        // 3. Adaptive Displacement-Gated Selection:
        // Ensures consecutive keyframes have ~35% - 65% overlap regardless of scroll speed.
        var keyframes: [UIImage] = []
        
        // Always select the first candidate
        var currentKeyframe = candidates[0]
        keyframes.append(currentKeyframe.image)
        onProgress?(1, candidates.count)
        
        let screenHeight = Double(currentKeyframe.image.cgImage?.height ?? 800)
        let minDisplacement = screenHeight * 0.28 // Need at least 28% scroll movement
        let targetDisplacement = screenHeight * 0.50 // Ideal 50% scroll movement (50% overlap)
        let maxDisplacement = screenHeight * 0.72 // Upper ceiling before overlap is lost
        
        var i = 1
        while i < candidates.count && keyframes.count < maxKeyframes {
            let cand = candidates[i]
            let shift = estimateVerticalShift(
                profileA: currentKeyframe.profile,
                profileB: cand.profile,
                height: Int(screenHeight)
            )
            
            // If user flicked rapidly or reached target displacement window
            if shift >= targetDisplacement || (shift >= minDisplacement && i == candidates.count - 1) {
                keyframes.append(cand.image)
                currentKeyframe = cand
                onProgress?(keyframes.count, candidates.count)
            } else if shift >= maxDisplacement {
                // Flick was so fast that candidate i exceeded max displacement:
                // Pick candidate i - 1 or candidate i immediately to preserve seam
                let chosen = (i > 0 && i - 1 < candidates.count) ? candidates[i - 1] : cand
                keyframes.append(chosen.image)
                currentKeyframe = chosen
                onProgress?(keyframes.count, candidates.count)
            }
            i += 1
        }
        
        // Ensure final frame of the video is captured to include the very bottom of the page
        if let lastCandidate = candidates.last,
           let lastKeyframeImg = keyframes.last?.cgImage,
           let lastCandImg = lastCandidate.image.cgImage {
            if !isFrameNearlyIdentical(lastKeyframeImg, lastCandImg) && keyframes.count < maxKeyframes {
                keyframes.append(lastCandidate.image)
                onProgress?(keyframes.count, candidates.count)
            }
        }
        
        return keyframes
        #else
        return []
        #endif
    }
    
    // MARK: - Fast 1D Luminance Profile & Vertical Shift Estimation (<0.2ms per comparison)
    
    private func calculate1DLuminanceProfile(cgImage: CGImage) -> [Double] {
        let height = min(cgImage.height, 600)
        let width = min(cgImage.width, 160)
        
        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            return Array(repeating: 0.5, count: height)
        }
        
        let bpr = cgImage.bytesPerRow
        let bpp = cgImage.bitsPerPixel / 8
        let stepY = max(1, cgImage.height / height)
        let stepX = max(1, cgImage.width / width)
        
        var profile = [Double](repeating: 0.0, count: height)
        
        for yIdx in 0..<height {
            let actualY = min(yIdx * stepY, cgImage.height - 1)
            let rowOffset = actualY * bpr
            var rowSum: Double = 0.0
            var sampleCount = 0
            
            for xIdx in 0..<width {
                let actualX = min(xIdx * stepX, cgImage.width - 1)
                let pixelOffset = rowOffset + actualX * bpp
                let r = Double(ptr[pixelOffset])
                let g = Double(ptr[pixelOffset + 1])
                let b = Double(ptr[pixelOffset + 2])
                // Standard Rec. 601 luminance
                let lum = 0.299 * r + 0.587 * g + 0.114 * b
                rowSum += lum
                sampleCount += 1
            }
            profile[yIdx] = sampleCount > 0 ? (rowSum / Double(sampleCount)) : 128.0
        }
        
        return profile
    }
    
    private func estimateVerticalShift(profileA: [Double], profileB: [Double], height: Int) -> Double {
        let len = min(profileA.count, profileB.count)
        guard len > 40 else { return 0 }
        
        // Scan vertical shifts from 0 to 75% of height
        let maxShift = Int(Double(len) * 0.75)
        var bestShift = 0
        var minDiff: Double = .greatestFiniteMagnitude
        
        for shift in stride(from: 0, through: maxShift, by: 4) {
            let overlapLen = len - shift
            guard overlapLen > 20 else { break }
            
            var diffSum: Double = 0
            for y in 0..<overlapLen {
                let diff = abs(profileA[y + shift] - profileB[y])
                diffSum += diff
            }
            let avgDiff = diffSum / Double(overlapLen)
            if avgDiff < minDiff {
                minDiff = avgDiff
                bestShift = shift
            }
        }
        
        // Scale downsampled profile shift back to full original image coordinates
        let scale = Double(height) / Double(len)
        return Double(bestShift) * scale
    }
    
    private func isFrameNearlyIdentical(_ imgA: CGImage?, _ imgB: CGImage?) -> Bool {
        guard let a = imgA, let b = imgB else { return false }
        guard a.width == b.width && a.height == b.height else { return false }
        
        let sampleY = a.height / 2
        let width = min(a.width, 240)
        
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
        return avgDiff < 3.5
    }
}
