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
        
        // Dynamic adaptive candidate probe rate:
        // Shorter recordings (<= 12s): 25 fps (0.04s) for high flick responsiveness
        // Medium recordings (12s - 30s): 20 fps (0.05s)
        // Long recordings (> 30s): 16.7 fps (0.06s) to conserve memory and accelerate processing
        let effectiveStep: Double
        if duration <= 12.0 {
            effectiveStep = candidateStepSeconds
        } else if duration <= 30.0 {
            effectiveStep = max(candidateStepSeconds, 0.05)
        } else {
            effectiveStep = max(candidateStepSeconds, 0.06)
        }
        
        var candidateTimes: [CMTime] = []
        var t = startTime
        while t <= endTime {
            candidateTimes.append(CMTime(seconds: t, preferredTimescale: 600))
            t += effectiveStep
        }
        
        guard !candidateTimes.isEmpty else { return [] }
        
        // Pass 1: Fast Probe with downscaled thumbnails (width: 160, height: 360)
        // Memory-safe: decodes small thumbnails for optical displacement analysis with zero memory pressure.
        generator.maximumSize = CGSize(width: 160, height: 360)
        
        // Dynamic Scroll Zone Probe across candidates to isolate active scrolling content
        var activeTopRatio: Double = 0.12
        var activeBottomRatio: Double = 0.08
        if candidateTimes.count >= 4 {
            let testIndices = [1, min(4, candidateTimes.count - 1), min(10, candidateTimes.count - 1), min(20, candidateTimes.count - 1)]
            for idx in testIndices {
                if let img0 = try? generator.copyCGImage(at: candidateTimes[0], actualTime: nil),
                   let img1 = try? generator.copyCGImage(at: candidateTimes[idx], actualTime: nil) {
                    let zone = ImageOverlapDetector.detectAdaptiveScrollZone(topImage: img0, bottomImage: img1)
                    let h = Double(img0.height)
                    if h > 50 && zone.confidence > 0.40 && zone.scrollVelocityEstimate > 8 {
                        if zone.topAnchorHeight > 10 {
                            activeTopRatio = max(0.08, min(0.65, Double(zone.topAnchorHeight) / h))
                        }
                        if zone.bottomAnchorHeight > 10 {
                            activeBottomRatio = max(0.04, min(0.35, Double(zone.bottomAnchorHeight) / h))
                        }
                        break
                    }
                }
            }
        }
        
        var candidates: [CandidateFrameSignature] = []
        
        for cmTime in candidateTimes {
            autoreleasepool {
                if let cgImage = try? generator.copyCGImage(at: cmTime, actualTime: nil) {
                    if let sig = extractCandidateSignature(
                        cgImage: cgImage,
                        time: cmTime,
                        topRatio: activeTopRatio,
                        bottomRatio: activeBottomRatio
                    ) {
                        candidates.append(sig)
                    }
                }
            }
        }
        
        guard !candidates.isEmpty else { return [] }
        
        // Pass 1 Selection: Adaptive Displacement-Gated Timestamps with Sharpness Lookahead
        // Ensures consecutive keyframes have ~35% - 65% overlap and filters out motion blur.
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
                sigA: currentCandidate,
                sigB: cand,
                probeHeight: probeHeight
            )
            let shift = match.shift
            
            // Only gate displacement if the frames exhibit coherent continuous overlap
            if match.confidence > 0.35 {
                // Skip reverse upward bounce to prevent duplicate backward frames
                if shift < -8.0 {
                    i += 1
                    continue
                }
                
                if shift >= maxDisplacement {
                    // Scroll was so fast that candidate i exceeded the safe seam window:
                    // If candidate (i - 1) exists and moved, choose it first to preserve continuous overlap!
                    let chosen = (i > 1 && candidates[i - 1].time != currentCandidate.time) ? candidates[i - 1] : cand
                    selectedTimes.append(chosen.time)
                    let wasPrevious = (chosen.time == candidates[i - 1].time)
                    currentCandidate = chosen
                    if wasPrevious {
                        // Re-evaluate candidate i against the updated currentCandidate
                        continue
                    }
                } else if shift >= targetDisplacement {
                    // Reached target displacement window!
                    // Lookahead: inspect candidate frames in window [i, i+1, i+2] that stay within maxDisplacement
                    // and select the candidate with the highest sharpness (least motion blur)
                    var bestCand = cand
                    var bestSharpness = cand.sharpness
                    var bestIdx = i
                    
                    let lookaheadLimit = min(candidates.count, i + 3)
                    for nextIdx in (i + 1)..<lookaheadLimit {
                        let nextCand = candidates[nextIdx]
                        let nextMatch = estimateVerticalShift(
                            sigA: currentCandidate,
                            sigB: nextCand,
                            probeHeight: probeHeight
                        )
                        if nextMatch.confidence > 0.35 && nextMatch.shift < maxDisplacement {
                            if nextCand.sharpness > bestSharpness {
                                bestSharpness = nextCand.sharpness
                                bestCand = nextCand
                                bestIdx = nextIdx
                            }
                        } else {
                            break
                        }
                    }
                    
                    selectedTimes.append(bestCand.time)
                    currentCandidate = bestCand
                    i = bestIdx
                }
            }
            i += 1
        }
        
        // Ensure final frame timestamp is captured to include the very bottom of the page
        // Avoid duplicate ending frames if the video was stationary at the end
        if let lastCandidate = candidates.last, selectedTimes.last != lastCandidate.time {
            let lastMatch = estimateVerticalShift(
                sigA: currentCandidate,
                sigB: lastCandidate,
                probeHeight: probeHeight
            )
            if lastMatch.confidence > 0.35 && lastMatch.shift > 15.0 && selectedTimes.count < maxKeyframes {
                selectedTimes.append(lastCandidate.time)
            } else if lastMatch.confidence > 0.35 && lastMatch.shift > 4.0 && !selectedTimes.isEmpty {
                // Subtle forward settling (4..15px): replace last timestamp to capture exact bottom without duplicates
                selectedTimes[selectedTimes.count - 1] = lastCandidate.time
            }
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
    
    // MARK: - Candidate Frame Signature & Multi-Column Spatial Fingerprint
    
    private struct CandidateFrameSignature {
        let time: CMTime
        let numCols: Int
        let activeRows: Int
        let samples: [UInt8]       // numCols * activeRows
        let rowVariances: [Double] // activeRows
        let sharpness: Double
    }
    
    private func extractCandidateSignature(
        cgImage: CGImage,
        time: CMTime,
        topRatio: Double = 0.12,
        bottomRatio: Double = 0.08,
        numCols: Int = 16
    ) -> CandidateFrameSignature? {
        let fullHeight = min(cgImage.height, 600)
        let width = cgImage.width
        guard fullHeight > 50, width > 20 else { return nil }
        
        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            return nil
        }
        
        let bpr = cgImage.bytesPerRow
        let bpp = cgImage.bitsPerPixel / 8
        let stepY = max(1, cgImage.height / fullHeight)
        
        let startY = Int(Double(fullHeight) * topRatio)
        let endY = Int(Double(fullHeight) * (1.0 - bottomRatio))
        let activeRows = max(1, endY - startY)
        
        // Sample 16 columns spanning from 0.06W to 0.94W to capture left avatars (x ~ 0.08W),
        // right avatars (x ~ 0.92W), and sparse text bubbles across the chat screen.
        let marginX = max(4, Int(Double(width) * 0.06))
        let activeWidth = max(10, width - 2 * marginX)
        var sampleCols = [Int](repeating: 0, count: numCols)
        for m in 0..<numCols {
            sampleCols[m] = marginX + Int(round(Double(m) * Double(activeWidth - 1) / Double(max(1, numCols - 1))))
        }
        
        var samples = [UInt8](repeating: 0, count: activeRows * numCols)
        var variances = [Double](repeating: 0.0, count: activeRows)
        var totalGrad = 0.0
        
        for (idx, yIdx) in (startY..<endY).enumerated() {
            let actualY = min(yIdx * stepY, cgImage.height - 1)
            let rowOffset = actualY * bpr
            let outOffset = idx * numCols
            
            var sumVal = 0
            var sumSqVal = 0
            
            for (m, x) in sampleCols.enumerated() {
                let pixelOffset = rowOffset + x * max(1, bpp)
                let lum: UInt8
                if bpp >= 3 {
                    let r = Double(ptr[pixelOffset])
                    let g = Double(ptr[pixelOffset + 1])
                    let b = Double(ptr[pixelOffset + 2])
                    lum = UInt8(max(0, min(255, Int(round(0.299 * r + 0.587 * g + 0.114 * b)))))
                } else {
                    lum = ptr[pixelOffset]
                }
                samples[outOffset + m] = lum
                let v = Int(lum)
                sumVal += v
                sumSqVal += v * v
            }
            
            let mean = Double(sumVal) / Double(numCols)
            variances[idx] = max(0.0, (Double(sumSqVal) / Double(numCols)) - (mean * mean))
            
            if idx > 0 {
                let prevOut = (idx - 1) * numCols
                var rowGrad = 0
                for m in 0..<numCols {
                    rowGrad += abs(Int(samples[outOffset + m]) - Int(samples[prevOut + m]))
                }
                totalGrad += Double(rowGrad) / Double(numCols)
            }
        }
        
        let sharpness = activeRows > 1 ? (totalGrad / Double(activeRows - 1)) : 0.0
        
        return CandidateFrameSignature(
            time: time,
            numCols: numCols,
            activeRows: activeRows,
            samples: samples,
            rowVariances: variances,
            sharpness: sharpness
        )
    }
    
    private func estimateVerticalShift(
        sigA: CandidateFrameSignature,
        sigB: CandidateFrameSignature,
        probeHeight: Double
    ) -> (shift: Double, confidence: Double) {
        let len = min(sigA.activeRows, sigB.activeRows)
        guard len > 40 else { return (0, 0) }
        let numCols = sigA.numCols
        
        let maxShift = Int(Double(len) * 0.75)
        let maxReverseShift = min(30, Int(Double(len) * 0.15))
        var bestShift = 0
        var minScore: Double = .greatestFiniteMagnitude
        var scoreTable: [Int: Double] = [:]
        
        var totalTextured = 0
        for y in 0..<len {
            if sigA.rowVariances[y] > 3.0 || sigB.rowVariances[y] > 3.0 {
                totalTextured += 1
            }
        }
        
        let evaluateShift: (Int) -> Double? = { shift in
            let overlapLen = shift >= 0 ? (len - shift) : (len + shift)
            guard overlapLen > 20 else { return nil }
            
            var texturedSum = 0
            var texturedRows = 0
            var totalSum = 0
            
            for k in 0..<overlapLen {
                let yA = shift >= 0 ? (shift + k) : k
                let yB = shift >= 0 ? k : (-shift + k)
                
                let isTextured = (sigA.rowVariances[yA] > 3.0 || sigB.rowVariances[yB] > 3.0)
                let offA = yA * numCols
                let offB = yB * numCols
                
                var rowDiff = 0
                for m in 0..<numCols {
                    let diff = abs(Int(sigA.samples[offA + m]) - Int(sigB.samples[offB + m]))
                    rowDiff += min(diff, 60)
                }
                
                totalSum += rowDiff
                if isTextured {
                    texturedSum += rowDiff
                    texturedRows += 1
                }
            }
            
            if texturedRows >= 3 {
                let meanDiff = Double(texturedSum) / Double(texturedRows * numCols)
                let textureSupport = min(1.0, Double(texturedRows) / Double(max(3, totalTextured)))
                return meanDiff - (textureSupport * 0.8)
            } else {
                return (Double(totalSum) / Double(overlapLen * numCols)) + 15.0
            }
        }
        
        // Coarse pass across both reverse bounce [-maxReverseShift ... 0] and forward scroll [0 ... maxShift]
        for shift in stride(from: -maxReverseShift, through: maxShift, by: 2) {
            guard let score = evaluateShift(shift) else { continue }
            scoreTable[shift] = score
            if score < minScore {
                minScore = score
                bestShift = shift
            }
        }
        
        // Fine evaluation of immediate neighbor rows
        for fineShift in [bestShift - 1, bestShift + 1] {
            if fineShift >= -maxReverseShift && fineShift <= maxShift && scoreTable[fineShift] == nil {
                if let score = evaluateShift(fineShift) {
                    scoreTable[fineShift] = score
                    if score < minScore {
                        minScore = score
                        bestShift = fineShift
                    }
                }
            }
        }
        
        // Parabolic Subpixel Displacement Refinement
        var subpixelShift = Double(bestShift)
        if let s0 = scoreTable[bestShift],
           let sM1 = scoreTable[bestShift - 1],
           let sP1 = scoreTable[bestShift + 1] {
            let denom = 2.0 * max(0.0001, (sP1 + sM1 - 2.0 * s0))
            let delta = max(-0.5, min(0.5, (sP1 - sM1) / denom))
            subpixelShift -= delta
        }
        
        let scale = probeHeight / Double(len)
        let confidence: Double
        if minScore < 25.0 {
            confidence = max(0.40, min(1.0, 1.0 - (minScore / 28.0)))
        } else {
            confidence = 0.0
        }
        
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
