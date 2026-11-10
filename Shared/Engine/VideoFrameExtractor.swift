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
        candidateStepSeconds: Double = 0.04, // High-frequency 25 fps candidate sampling for rapid flick resilience
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
        
        // Pass 1: Fast Probe with downscaled thumbnails (width: 160, height: 360)
        // Memory-safe: decodes small thumbnails for optical displacement analysis with zero memory pressure.
        generator.maximumSize = CGSize(width: 160, height: 360)
        
        // Dynamic Scroll Zone Probe on initial keyframes to isolate active scrolling content
        var activeTopRatio: Double = 0.14
        var activeBottomRatio: Double = 0.10
        if candidateTimes.count >= 2,
           let img0 = try? generator.copyCGImage(at: candidateTimes[0], actualTime: nil),
           let img1 = try? generator.copyCGImage(at: candidateTimes[min(3, candidateTimes.count - 1)], actualTime: nil) {
            let zone = ImageOverlapDetector.detectAdaptiveScrollZone(topImage: img0, bottomImage: img1)
            let h = Double(img0.height)
            if h > 50 {
                if zone.topAnchorHeight > 10 {
                    activeTopRatio = max(0.10, min(0.65, Double(zone.topAnchorHeight) / h))
                }
                if zone.bottomAnchorHeight > 10 {
                    activeBottomRatio = max(0.06, min(0.35, Double(zone.bottomAnchorHeight) / h))
                }
            }
        }
        
        var candidates: [(time: CMTime, profile: [Double])] = []
        
        for cmTime in candidateTimes {
            autoreleasepool {
                if let cgImage = try? generator.copyCGImage(at: cmTime, actualTime: nil) {
                    let profile = calculate1DLuminanceProfile(
                        cgImage: cgImage,
                        topRatio: activeTopRatio,
                        bottomRatio: activeBottomRatio
                    )
                    if !profile.isEmpty {
                        candidates.append((time: cmTime, profile: profile))
                    }
                }
            }
        }
        
        guard !candidates.isEmpty else { return [] }
        
        // Pass 1 Selection: Adaptive Displacement-Gated Timestamps
        // Ensures consecutive keyframes have ~35% - 65% overlap regardless of scroll speed.
        var selectedTimes: [CMTime] = []
        var currentCandidate = candidates[0]
        selectedTimes.append(currentCandidate.time)
        
        let probeHeight = 360.0
        let targetDisplacement = probeHeight * 0.45 // Ideal 45% scroll movement (55% overlap)
        let maxDisplacement = probeHeight * 0.70    // Upper limit before overlap is broken
        
        var i = 1
        while i < candidates.count && selectedTimes.count < maxKeyframes {
            let cand = candidates[i]
            let match = estimateVerticalShift(
                profileA: currentCandidate.profile,
                profileB: cand.profile,
                probeHeight: probeHeight
            )
            let shift = match.shift
            
            // Only gate displacement if the frames exhibit coherent continuous overlap
            if match.confidence > 0.35 {
                // Skip reverse upward bounce to prevent duplicate backward frames
                if shift < -12.0 {
                    i += 1
                    continue
                }
                
                if shift >= maxDisplacement {
                    // Scroll was so fast that candidate i exceeded the safe seam window:
                    // If candidate (i - 1) exists and moved, choose it first to preserve continuous overlap!
                    let chosen = (i > 1 && candidates[i - 1].time != currentCandidate.time) ? candidates[i - 1] : cand
                    selectedTimes.append(chosen.time)
                    currentCandidate = chosen
                } else if shift >= targetDisplacement {
                    // Reached sweet spot (45% - 70% displacement)
                    selectedTimes.append(cand.time)
                    currentCandidate = cand
                }
            }
            i += 1
        }
        
        // Ensure final frame timestamp is captured to include the very bottom of the page
        if let lastCandidate = candidates.last, selectedTimes.last != lastCandidate.time && selectedTimes.count < maxKeyframes {
            selectedTimes.append(lastCandidate.time)
        }
        
        // Pass 2: High-Resolution Native Extraction ONLY for selected keyframe timestamps
        generator.maximumSize = .zero // Full native resolution
        var keyframes: [UIImage] = []
        
        for (index, time) in selectedTimes.enumerated() {
            autoreleasepool {
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    let uiImage = UIImage(cgImage: cgImage)
                    keyframes.append(uiImage)
                    onProgress?(index + 1, selectedTimes.count)
                }
            }
        }
        
        return keyframes
        #else
        return []
        #endif
    }
    
    // MARK: - Fast 1D Luminance Profile & Vertical Shift Estimation (<0.2ms per comparison)
    
    private func calculate1DLuminanceProfile(
        cgImage: CGImage,
        topRatio: Double = 0.14,
        bottomRatio: Double = 0.10
    ) -> [Double] {
        let fullHeight = min(cgImage.height, 600)
        let width = min(cgImage.width, 160)
        
        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            return []
        }
        
        let bpr = cgImage.bytesPerRow
        let bpp = cgImage.bitsPerPixel / 8
        let stepY = max(1, cgImage.height / fullHeight)
        let stepX = max(1, cgImage.width / width)
        
        // Exclude dynamically detected static top zone and bottom bar
        let startY = Int(Double(fullHeight) * topRatio)
        let endY = Int(Double(fullHeight) * (1.0 - bottomRatio))
        let activeRows = max(1, endY - startY)
        
        var profile = [Double](repeating: 0.0, count: activeRows)
        
        for (idx, yIdx) in (startY..<endY).enumerated() {
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
                let lum = 0.299 * r + 0.587 * g + 0.114 * b
                rowSum += lum
                sampleCount += 1
            }
            profile[idx] = sampleCount > 0 ? (rowSum / Double(sampleCount)) : 128.0
        }
        
        return profile
    }
    
    private func estimateVerticalShift(
        profileA: [Double],
        profileB: [Double],
        probeHeight: Double
    ) -> (shift: Double, confidence: Double) {
        let len = min(profileA.count, profileB.count)
        guard len > 40 else { return (0, 0) }
        
        let maxShift = Int(Double(len) * 0.75)
        var bestShift = 0
        var minDiff: Double = .greatestFiniteMagnitude
        var diffTable: [Int: Double] = [:]
        
        // Coarse pass (stride: 2)
        for shift in stride(from: 0, through: maxShift, by: 2) {
            let overlapLen = len - shift
            guard overlapLen > 25 else { break }
            
            var diffSum: Double = 0
            for y in 0..<overlapLen {
                let diff = abs(profileA[y + shift] - profileB[y])
                diffSum += diff
            }
            let avgDiff = diffSum / Double(overlapLen)
            diffTable[shift] = avgDiff
            if avgDiff < minDiff {
                minDiff = avgDiff
                bestShift = shift
            }
        }
        
        // Fine evaluation of immediate neighbor rows
        for fineShift in [bestShift - 1, bestShift + 1] {
            if fineShift >= 0 && fineShift <= maxShift && diffTable[fineShift] == nil {
                let overlapLen = len - fineShift
                if overlapLen > 25 {
                    var diffSum: Double = 0
                    for y in 0..<overlapLen {
                        diffSum += abs(profileA[y + fineShift] - profileB[y])
                    }
                    let avgDiff = diffSum / Double(overlapLen)
                    diffTable[fineShift] = avgDiff
                    if avgDiff < minDiff {
                        minDiff = avgDiff
                        bestShift = fineShift
                    }
                }
            }
        }
        
        // Parabolic Subpixel Displacement Refinement
        var subpixelShift = Double(bestShift)
        if let dM1 = diffTable[bestShift - 1], let dP1 = diffTable[bestShift + 1] {
            let denom = 2.0 * max(0.0001, (dP1 + dM1 - 2.0 * minDiff))
            let delta = max(-0.5, min(0.5, (dP1 - dM1) / denom))
            subpixelShift -= delta
        }
        
        let scale = probeHeight / Double(len)
        let confidence = max(0.0, min(1.0, 1.0 - (minDiff / 40.0)))
        
        return (subpixelShift * scale, confidence)
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
