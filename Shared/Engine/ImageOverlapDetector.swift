import Foundation
import CoreGraphics
#if canImport(Accelerate)
import Accelerate
#endif

public struct OverlapMatchResult {
    public let offset: CGFloat
    public let confidence: Double
    public let optimalSeamY: CGFloat
    
    public init(offset: CGFloat, confidence: Double, optimalSeamY: CGFloat) {
        self.offset = offset
        self.confidence = confidence
        self.optimalSeamY = optimalSeamY
    }
}

public struct StaticChromeDetectionResult {
    public let topBarHeight: CGFloat
    public let bottomBarHeight: CGFloat
    
    public init(topBarHeight: CGFloat, bottomBarHeight: CGFloat) {
        self.topBarHeight = topBarHeight
        self.bottomBarHeight = bottomBarHeight
    }
}

public struct ScrollZoneDetectionResult {
    public let topAnchorHeight: CGFloat
    public let bottomAnchorHeight: CGFloat
    public let isSplitScreenMedia: Bool
    public let isChatAppDetected: Bool
    public let isCardFeedDetected: Bool
    public let isWebArticleDetected: Bool
    public let scrollVelocityEstimate: CGFloat
    public let confidence: Double
    public let scenario: AppLayoutScenario
    
    public init(
        topAnchorHeight: CGFloat,
        bottomAnchorHeight: CGFloat,
        isSplitScreenMedia: Bool,
        isChatAppDetected: Bool = false,
        isCardFeedDetected: Bool = false,
        isWebArticleDetected: Bool = false,
        scrollVelocityEstimate: CGFloat,
        confidence: Double,
        scenario: AppLayoutScenario = .generalScroll
    ) {
        self.topAnchorHeight = topAnchorHeight
        self.bottomAnchorHeight = bottomAnchorHeight
        self.isSplitScreenMedia = isSplitScreenMedia
        self.isChatAppDetected = isChatAppDetected
        self.isCardFeedDetected = isCardFeedDetected
        self.isWebArticleDetected = isWebArticleDetected
        self.scrollVelocityEstimate = scrollVelocityEstimate
        self.confidence = confidence
        self.scenario = scenario
    }
}

public struct ImageBuffer2D {
    public let width: Int
    public let height: Int
    public let data: [UInt8]
    public let scaleX: CGFloat
    public let scaleY: CGFloat
    
    public init(width: Int, height: Int, data: [UInt8], scaleX: CGFloat, scaleY: CGFloat) {
        self.width = width
        self.height = height
        self.data = data
        self.scaleX = scaleX
        self.scaleY = scaleY
    }
    
    @inline(__always)
    public func pixel(x: Int, y: Int) -> UInt8 {
        return data[y * width + x]
    }
}

public struct ImageProfile1D {
    public let luminance: [Double]
    public let horizontalEdgeEnergy: [Double]
    public let combinedFeature: [Double]
    
    public init(luminance: [Double], horizontalEdgeEnergy: [Double], combinedFeature: [Double]? = nil) {
        self.luminance = luminance
        self.horizontalEdgeEnergy = horizontalEdgeEnergy
        if let combined = combinedFeature {
            self.combinedFeature = combined
        } else {
            var combined = [Double](repeating: 0.0, count: luminance.count)
            for i in 0..<luminance.count {
                let lum = luminance[i]
                let edge = i < horizontalEdgeEnergy.count ? horizontalEdgeEnergy[i] : 0.0
                combined[i] = lum * 0.35 + edge * 0.65
            }
            self.combinedFeature = combined
        }
    }
}

public final class ImageOverlapDetector {
    
    // MARK: - 2D Grayscale Bitmap Downsampler
    
    /// Downscales a high-resolution screenshot into a standardized 2D grayscale analysis buffer (width ~320).
    /// Preserves complete 2D spatial arrangement of text, icons, avatars, and UI geometry.
    public static func createGrayscaleBuffer(from cgImage: CGImage, targetWidth: Int = 320) -> ImageBuffer2D? {
        let origW = cgImage.width
        let origH = cgImage.height
        guard origW > 0, origH > 0 else { return nil }
        
        let tW = min(targetWidth, origW)
        let tH = max(1, Int(round(CGFloat(origH) * CGFloat(tW) / CGFloat(origW))))
        
        var bytes = [UInt8](repeating: 0, count: tW * tH)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &bytes,
            width: tW,
            height: tH,
            bitsPerComponent: 8,
            bytesPerRow: tW,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        ctx.interpolationQuality = .medium
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: tW, height: tH))
        
        let sX = CGFloat(origW) / CGFloat(tW)
        let sY = CGFloat(origH) / CGFloat(tH)
        return ImageBuffer2D(width: tW, height: tH, data: bytes, scaleX: sX, scaleY: sY)
    }
    
    // MARK: - 2D Multi-Patch Spatial Cross-Correlation
    
    /// Finds vertical displacement using 2D multi-patch spatial cross-correlation.
    /// Uses multiple independent 2D templates across the content area to eliminate periodic false matches.
    private static func match2DPatches(
        topBuf: ImageBuffer2D,
        botBuf: ImageBuffer2D,
        expectedDisplacement: CGFloat? = nil
    ) -> (displacement: CGFloat, confidence: Double, isReverseOrder: Bool) {
        let W = topBuf.width
        let H = topBuf.height
        guard W > 30, H > 100 else {
            return (0, 0, false)
        }
        
        let marginX = max(8, Int(Double(W) * 0.05))
        let activeWidth = W - 2 * marginX
        guard activeWidth > 20 else {
            return (0, 0, false)
        }
        
        let patchHeight = max(28, min(60, Int(Double(H) * 0.08)))
        
        // Multi-tier candidate vertical anchors in botBuf covering small, medium, and large scroll displacements (15%..85% overlap)
        let anchorRatios: [Double] = [0.10, 0.18, 0.28, 0.42, 0.60]
        var candidateMatches: [(dy: CGFloat, mad: Double)] = []
        
        topBuf.data.withUnsafeBufferPointer { topPtr in
            botBuf.data.withUnsafeBufferPointer { botPtr in
                guard let topBase = topPtr.baseAddress, let botBase = botPtr.baseAddress else { return }
                
                for ratio in anchorRatios {
                    let yB = Int(Double(H) * ratio)
                    guard yB + patchHeight < H - 20 else { continue }
                    
                    // Check patch texture variance (skip flat background)
                    var sumVal: Int = 0
                    var sumSqVal: Int = 0
                    let totalPixels = patchHeight * activeWidth
                    for r in 0..<patchHeight {
                        let rowOffset = (yB + r) * W
                        for c in marginX..<(W - marginX) {
                            let v = Int(botBase[rowOffset + c])
                            sumVal += v
                            sumSqVal += v * v
                        }
                    }
                    let mean = Double(sumVal) / Double(totalPixels)
                    let variance = Double(sumSqVal) / Double(totalPixels) - (mean * mean)
                    guard variance > 2.5 else { continue }
                    
                    // Downward scroll: content at yB in botBuf was LOWER in topBuf: yA in [yB + 6 ... H - patchHeight - 6]
                    let searchMin = yB + 4
                    let searchMax = H - patchHeight - 6
                    guard searchMin <= searchMax else { continue }
                    
                    var bestYA = searchMin
                    var minMAD = Double.greatestFiniteMagnitude
                    
                    // Coarse search with stride 2
                    for yA in stride(from: searchMin, through: searchMax, by: 2) {
                        var diffSum: Int = 0
                        for r in 0..<patchHeight {
                            let offsetA = (yA + r) * W
                            let offsetB = (yB + r) * W
                            for c in marginX..<(W - marginX) {
                                let diff = abs(Int(topBase[offsetA + c]) - Int(botBase[offsetB + c]))
                                diffSum += diff
                            }
                        }
                        let mad = Double(diffSum) / Double(totalPixels)
                        if mad < minMAD {
                            minMAD = mad
                            bestYA = yA
                        }
                    }
                    
                    // Fine search in [-2, +2] neighborhood of peak
                    let fineStart = max(searchMin, bestYA - 2)
                    let fineEnd = min(searchMax, bestYA + 2)
                    for yA in fineStart...fineEnd {
                        guard yA != bestYA else { continue }
                        var diffSum: Int = 0
                        for r in 0..<patchHeight {
                            let offsetA = (yA + r) * W
                            let offsetB = (yB + r) * W
                            for c in marginX..<(W - marginX) {
                                let diff = abs(Int(topBase[offsetA + c]) - Int(botBase[offsetB + c]))
                                diffSum += diff
                            }
                        }
                        let mad = Double(diffSum) / Double(totalPixels)
                        if mad < minMAD {
                            minMAD = mad
                            bestYA = yA
                        }
                    }
                    
                    if minMAD < 35.0 {
                        let dy = CGFloat(bestYA - yB)
                        candidateMatches.append((dy: dy, mad: minMAD))
                    }
                }
            }
        }
        
        // Multi-Patch Consensus Voting
        if !candidateMatches.isEmpty {
            var votes: [[(dy: CGFloat, mad: Double)]] = []
            for match in candidateMatches {
                var added = false
                for i in 0..<votes.count {
                    if abs(votes[i][0].dy - match.dy) <= 2.5 {
                        votes[i].append(match)
                        added = true
                        break
                    }
                }
                if !added {
                    votes.append([match])
                }
            }
            
            // Pick cluster with highest votes; break ties with lower MAD or matching velocity prior
            votes.sort { c1, c2 in
                if c1.count != c2.count {
                    return c1.count > c2.count
                }
                let minMad1 = c1.map(\.mad).min() ?? 999.0
                let minMad2 = c2.map(\.mad).min() ?? 999.0
                return minMad1 < minMad2
            }
            
            let bestCluster = votes[0]
            let avgDy = bestCluster.map(\.dy).reduce(0.0, +) / CGFloat(bestCluster.count)
            let avgMad = bestCluster.map(\.mad).reduce(0.0, +) / Double(bestCluster.count)
            let confidence = max(0.50, min(1.0, 1.0 - avgMad / 35.0 + (bestCluster.count > 1 ? 0.08 : 0.0)))
            
            return (displacement: avgDy, confidence: confidence, isReverseOrder: false)
        }
        
        // Reverse Sequence Fallback Check:
        // Test if images were selected in reverse (newest to oldest)
        var reverseCandidateMatches: [(dy: CGFloat, mad: Double)] = []
        topBuf.data.withUnsafeBufferPointer { topPtr in
            botBuf.data.withUnsafeBufferPointer { botPtr in
                guard let topBase = topPtr.baseAddress, let botBase = botPtr.baseAddress else { return }
                for ratio in anchorRatios {
                    let yA = Int(Double(H) * ratio)
                    guard yA + patchHeight < H - 20 else { continue }
                    let searchMin = yA + 4
                    let searchMax = H - patchHeight - 6
                    guard searchMin <= searchMax else { continue }
                    
                    var bestYB = searchMin
                    var minMAD = Double.greatestFiniteMagnitude
                    let totalPixels = patchHeight * activeWidth
                    
                    for yB in stride(from: searchMin, through: searchMax, by: 2) {
                        var diffSum: Int = 0
                        for r in 0..<patchHeight {
                            let offsetA = (yA + r) * W
                            let offsetB = (yB + r) * W
                            for c in marginX..<(W - marginX) {
                                let diff = abs(Int(topBase[offsetA + c]) - Int(botBase[offsetB + c]))
                                diffSum += diff
                            }
                        }
                        let mad = Double(diffSum) / Double(totalPixels)
                        if mad < minMAD {
                            minMAD = mad
                            bestYB = yB
                        }
                    }
                    if minMAD < 25.0 {
                        let dy = CGFloat(bestYB - yA)
                        reverseCandidateMatches.append((dy: dy, mad: minMAD))
                    }
                }
            }
        }
        
        if !reverseCandidateMatches.isEmpty {
            let bestRev = reverseCandidateMatches.min(by: { $0.mad < $1.mad })!
            let confidence = max(0.40, min(1.0, 1.0 - bestRev.mad / 35.0))
            return (displacement: bestRev.dy, confidence: confidence, isReverseOrder: true)
        }
        
        return (displacement: 0, confidence: 0, isReverseOrder: false)
    }
    
    // MARK: - Full-Resolution 2D Subpixel Refinement
    
    /// Refines the coarse 2D displacement at full original resolution to achieve exact sub-pixel alignment.
    private static func refineFullResolutionSubpixel(
        topImage: CGImage,
        bottomImage: CGImage,
        coarseDisplacement: CGFloat,
        scaleY: CGFloat
    ) -> (fineDisplacement: CGFloat, confidence: Double) {
        let origW = min(topImage.width, bottomImage.width)
        let origH = min(topImage.height, bottomImage.height)
        guard origW > 60, origH > 200 else {
            return (coarseDisplacement * scaleY, 0.5)
        }
        
        let targetDy = coarseDisplacement * scaleY
        let patchH = min(80, max(40, Int(Double(origH) * 0.05)))
        let patchStartB = max(100, min(origH - patchH - 120, Int(Double(origH) * 0.45)))
        
        // Sample strip across width with stride 2 for speed
        let sampleW = min(origW - 40, 480)
        let startX = (origW - sampleW) / 2
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var patchB = [UInt8](repeating: 0, count: sampleW * patchH)
        guard let ctxB = CGContext(
            data: &patchB,
            width: sampleW,
            height: patchH,
            bitsPerComponent: 8,
            bytesPerRow: sampleW,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return (targetDy, 0.8)
        }
        ctxB.interpolationQuality = .none
        ctxB.draw(bottomImage, in: CGRect(x: -startX, y: -patchStartB, width: origW, height: origH))
        
        let searchRadius = 10
        let searchMinDy = max(10, Int(round(targetDy)) - searchRadius)
        let searchMaxDy = min(origH - patchH - 20, Int(round(targetDy)) + searchRadius)
        guard searchMinDy <= searchMaxDy else {
            return (targetDy, 0.8)
        }
        
        let searchSpanH = (searchMaxDy - searchMinDy) + patchH
        let searchStartA = patchStartB + searchMinDy
        guard searchStartA + searchSpanH <= origH else {
            return (targetDy, 0.8)
        }
        
        var stripA = [UInt8](repeating: 0, count: sampleW * searchSpanH)
        guard let ctxA = CGContext(
            data: &stripA,
            width: sampleW,
            height: searchSpanH,
            bitsPerComponent: 8,
            bytesPerRow: sampleW,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return (targetDy, 0.8)
        }
        ctxA.interpolationQuality = .none
        ctxA.draw(topImage, in: CGRect(x: -startX, y: -searchStartA, width: origW, height: origH))
        
        var bestOffsetDy = searchMinDy
        var minDiffSum = Int.max
        var errors: [Int: Double] = [:]
        let totalCount = sampleW * patchH
        
        for dy in searchMinDy...searchMaxDy {
            let rowOffsetInA = (dy - searchMinDy) * sampleW
            var diffSum: Int = 0
            for r in 0..<patchH {
                let offA = rowOffsetInA + r * sampleW
                let offB = r * sampleW
                for c in stride(from: 0, to: sampleW, by: 2) {
                    diffSum += abs(Int(stripA[offA + c]) - Int(patchB[offB + c]))
                }
            }
            errors[dy] = Double(diffSum) / Double(totalCount / 2)
            if diffSum < minDiffSum {
                minDiffSum = diffSum
                bestOffsetDy = dy
            }
        }
        
        // Parabolic Subpixel Interpolation on error curve
        var subpixelDy = CGFloat(bestOffsetDy)
        if let e0 = errors[bestOffsetDy],
           let eM1 = errors[bestOffsetDy - 1],
           let eP1 = errors[bestOffsetDy + 1] {
            let denom = 2.0 * (eM1 + eP1 - 2.0 * e0)
            if abs(denom) > 0.0001 {
                let delta = (eM1 - eP1) / denom
                if abs(delta) <= 0.5 {
                    subpixelDy += CGFloat(delta)
                }
            }
        }
        
        let avgErr = Double(minDiffSum) / Double(totalCount / 2)
        let conf = max(0.60, min(1.0, 1.0 - avgErr / 35.0))
        return (fineDisplacement: subpixelDy, confidence: conf)
    }
    
    // MARK: - 2D Motion-Coherence Chrome & Scenario Detection
    
    /// Detects top navigation bars, split-screen video note players, and bottom input/tab bars
    /// with pixel-level precision using 2D static pixel consistency and hairline divider snapping.
    public static func detectAdaptiveScrollZone(
        topImage: CGImage,
        bottomImage: CGImage
    ) -> ScrollZoneDetectionResult {
        let origW = min(topImage.width, bottomImage.width)
        let origH = min(topImage.height, bottomImage.height)
        guard origW > 0, origH > 300 else {
            return ScrollZoneDetectionResult(
                topAnchorHeight: 0,
                bottomAnchorHeight: 0,
                isSplitScreenMedia: false,
                isChatAppDetected: false,
                scrollVelocityEstimate: 0,
                confidence: 0
            )
        }
        
        guard let topBuf = createGrayscaleBuffer(from: topImage, targetWidth: 320),
              let botBuf = createGrayscaleBuffer(from: bottomImage, targetWidth: 320) else {
            return ScrollZoneDetectionResult(
                topAnchorHeight: 0,
                bottomAnchorHeight: 0,
                isSplitScreenMedia: false,
                isChatAppDetected: false,
                scrollVelocityEstimate: 0,
                confidence: 0
            )
        }
        
        let W = topBuf.width
        let H = topBuf.height
        let marginX = max(8, Int(Double(W) * 0.05))
        let activeW = W - 2 * marginX
        
        // Find coarse displacement across 2D patches
        let coarseMatch = match2DPatches(topBuf: topBuf, botBuf: botBuf)
        let coarseDy = coarseMatch.displacement
        
        // --- 1. Top Chrome Detection (Scan from y=0 downward) ---
        var topChromeEnd = 0
        let maxTopScan = min(Int(Double(H) * 0.65), H - 100)
        
        topBuf.data.withUnsafeBufferPointer { topPtr in
            botBuf.data.withUnsafeBufferPointer { botPtr in
                guard let topBase = topPtr.baseAddress, let botBase = botPtr.baseAddress else { return }
                
                var consecutiveMovingRows = 0
                for y in 0..<maxTopScan {
                    var diffStaticSum = 0
                    var diffMotionSum = 0
                    let yaMotion = Int(round(CGFloat(y) + coarseDy))
                    
                    let offTop = y * W
                    let offBot = y * W
                    let offMotion = yaMotion * W
                    
                    for c in marginX..<(W - marginX) {
                        let vTop = Int(topBase[offTop + c])
                        let vBot = Int(botBase[offBot + c])
                        diffStaticSum += abs(vTop - vBot)
                        if yaMotion < H {
                            let vMotion = Int(topBase[offMotion + c])
                            diffMotionSum += abs(vMotion - vBot)
                        } else {
                            diffMotionSum += 255
                        }
                    }
                    
                    let diffStatic = Double(diffStaticSum) / Double(activeW)
                    let diffMotion = Double(diffMotionSum) / Double(activeW)
                    
                    // Moving row: motion diff is small, static diff is high (content is scrolling!)
                    if coarseDy > 20 && diffMotion < 10.0 && diffStatic > 14.0 {
                        consecutiveMovingRows += 1
                        if consecutiveMovingRows >= 3 {
                            topChromeEnd = max(0, y - 2)
                            break
                        }
                    } else {
                        consecutiveMovingRows = 0
                    }
                }
            }
        }
        
        // Hairline divider snapping near topChromeEnd
        var snapTop = topChromeEnd
        if topChromeEnd > 15 {
            let snapRange = max(4, topChromeEnd - 10)...min(maxTopScan, topChromeEnd + 10)
            var maxEdge = 0.0
            for y in snapRange {
                guard y + 1 < H else { break }
                var edgeSum = 0
                let off1 = (y + 1) * W
                let off0 = y * W
                for c in marginX..<(W - marginX) {
                    edgeSum += abs(Int(botBuf.data[off1 + c]) - Int(botBuf.data[off0 + c]))
                }
                let edge = Double(edgeSum) / Double(activeW)
                if edge > maxEdge {
                    maxEdge = edge
                    snapTop = y + 1
                }
            }
        }
        
        // Verify that 0..<snapTop actually contains confirmed static UI features (eliminates false top crop on pure docs)
        var confirmedStaticTopRows = 0
        if snapTop > 10 {
            topBuf.data.withUnsafeBufferPointer { topPtr in
                botBuf.data.withUnsafeBufferPointer { botPtr in
                    guard let topBase = topPtr.baseAddress, let botBase = botPtr.baseAddress else { return }
                    for y in 0..<snapTop {
                        var diffStaticSum = 0
                        var sumValB = 0
                        var sumSqValB = 0
                        let yaMotion = Int(round(CGFloat(y) + coarseDy))
                        var diffMotionSum = 0
                        let offA = y * W
                        let offB = y * W
                        let offM = yaMotion * W
                        for c in marginX..<(W - marginX) {
                            let vA = Int(topBase[offA + c])
                            let vB = Int(botBase[offB + c])
                            diffStaticSum += abs(vA - vB)
                            sumValB += vB
                            sumSqValB += vB * vB
                            if yaMotion < H {
                                diffMotionSum += abs(Int(topBase[offM + c]) - vB)
                            } else {
                                diffMotionSum += 255
                            }
                        }
                        let diffS = Double(diffStaticSum) / Double(activeW)
                        let diffM = Double(diffMotionSum) / Double(activeW)
                        let meanB = Double(sumValB) / Double(activeW)
                        let varB = Double(sumSqValB) / Double(activeW) - (meanB * meanB)
                        if diffS < 12.0 && diffM > 14.0 && varB > 2.5 {
                            confirmedStaticTopRows += 1
                        }
                    }
                }
            }
        }
        if confirmedStaticTopRows < 3 {
            snapTop = 0
        }
        
        let fullTopAnchor = CGFloat(snapTop) * topBuf.scaleY
        
        // --- 2. Bottom Chrome Detection (Scan from y=H-1 upward) ---
        var bottomChromeStart = H
        let maxBottomScan = min(Int(Double(H) * 0.35), H - 100)
        
        topBuf.data.withUnsafeBufferPointer { topPtr in
            botBuf.data.withUnsafeBufferPointer { botPtr in
                guard let topBase = topPtr.baseAddress, let botBase = botPtr.baseAddress else { return }
                
                var consecutiveMovingRows = 0
                for i in 0..<maxBottomScan {
                    let y = H - 1 - i
                    guard y >= 0 else { break }
                    
                    var diffStaticSum = 0
                    var sumValA = 0
                    var sumSqValA = 0
                    var sumValB = 0
                    var sumSqValB = 0
                    
                    let offA = y * W
                    let offB = y * W
                    
                    for c in marginX..<(W - marginX) {
                        let vA = Int(topBase[offA + c])
                        let vB = Int(botBase[offB + c])
                        diffStaticSum += abs(vA - vB)
                        sumValA += vA
                        sumSqValA += vA * vA
                        sumValB += vB
                        sumSqValB += vB * vB
                    }
                    
                    let diffStatic = Double(diffStaticSum) / Double(activeW)
                    let meanA = Double(sumValA) / Double(activeW)
                    let varA = Double(sumSqValA) / Double(activeW) - (meanA * meanA)
                    let meanB = Double(sumValB) / Double(activeW)
                    let varB = Double(sumSqValB) / Double(activeW) - (meanB * meanB)
                    
                    // If rows are visually distinct and either screen contains detail (text/cards), content has started!
                    if diffStatic > 12.0 && max(varA, varB) > 3.0 {
                        consecutiveMovingRows += 1
                        if consecutiveMovingRows >= 3 {
                            bottomChromeStart = min(H, y + 3)
                            break
                        }
                    } else {
                        consecutiveMovingRows = 0
                    }
                }
            }
        }
        
        // Hairline divider snapping near bottomChromeStart
        var snapBottom = bottomChromeStart
        if bottomChromeStart < H - 15 {
            let snapRange = max(H - maxBottomScan, bottomChromeStart - 10)...min(H - 2, bottomChromeStart + 10)
            var maxEdge = 0.0
            for y in snapRange {
                guard y + 1 < H else { break }
                var edgeSum = 0
                let off1 = (y + 1) * W
                let off0 = y * W
                for c in marginX..<(W - marginX) {
                    edgeSum += abs(Int(botBuf.data[off1 + c]) - Int(botBuf.data[off0 + c]))
                }
                let edge = Double(edgeSum) / Double(activeW)
                if edge > maxEdge {
                    maxEdge = edge
                    snapBottom = y
                }
            }
        }
        
        // Verify that snapBottom..<H actually contains confirmed static UI features (buttons, input field, tab bar)
        var confirmedStaticBottomRows = 0
        if snapBottom < H - 10 {
            topBuf.data.withUnsafeBufferPointer { topPtr in
                botBuf.data.withUnsafeBufferPointer { botPtr in
                    guard let topBase = topPtr.baseAddress, let botBase = botPtr.baseAddress else { return }
                    for y in snapBottom..<H {
                        var diffStaticSum = 0
                        var sumValB = 0
                        var sumSqValB = 0
                        let offA = y * W
                        let offB = y * W
                        for c in marginX..<(W - marginX) {
                            let vA = Int(topBase[offA + c])
                            let vB = Int(botBase[offB + c])
                            diffStaticSum += abs(vA - vB)
                            sumValB += vB
                            sumSqValB += vB * vB
                        }
                        let diffS = Double(diffStaticSum) / Double(activeW)
                        let meanB = Double(sumValB) / Double(activeW)
                        let varB = Double(sumSqValB) / Double(activeW) - (meanB * meanB)
                        if diffS < 12.0 && varB > 2.5 {
                            confirmedStaticBottomRows += 1
                        }
                    }
                }
            }
        }
        if confirmedStaticBottomRows < 3 {
            snapBottom = H
        }
        
        let fullBottomAnchor = CGFloat(H - snapBottom) * topBuf.scaleY
        
        // --- 3. Multi-Scenario Classification ---
        let isSplitMedia = fullTopAnchor > (CGFloat(origH) * 0.18)
        let isChatApp = !isSplitMedia && fullTopAnchor >= 120 && fullTopAnchor <= 380 && fullBottomAnchor >= 100 && fullBottomAnchor <= 380
        
        // Card Feed Check (regular horizontal dividers)
        var isCardFeed = false
        if !isSplitMedia && !isChatApp {
            var dividerRows: [Int] = []
            let bodyStart = snapTop + 10
            let bodyEnd = snapBottom - 10
            if bodyEnd > bodyStart + 100 {
                for y in (bodyStart + 1)..<(bodyEnd - 1) {
                    let off1 = (y + 1) * W
                    let off0 = y * W
                    var edgeSum = 0
                    for c in marginX..<(W - marginX) {
                        edgeSum += abs(Int(botBuf.data[off1 + c]) - Int(botBuf.data[off0 + c]))
                    }
                    let edge = Double(edgeSum) / Double(activeW)
                    if edge > 16.0 {
                        dividerRows.append(y)
                    }
                }
            }
            if dividerRows.count >= 2 {
                var periodicCount = 0
                for i in 1..<dividerRows.count {
                    let diff = dividerRows[i] - dividerRows[i - 1]
                    if diff >= 30 && diff <= 140 {
                        periodicCount += 1
                    }
                }
                if periodicCount >= 2 {
                    isCardFeed = true
                }
            }
        }
        
        let isWebArticle = !isSplitMedia && !isChatApp && !isCardFeed && fullTopAnchor >= 70 && fullTopAnchor <= 320 && fullBottomAnchor >= 45 && fullBottomAnchor <= 240
        
        let scenario: AppLayoutScenario
        if isSplitMedia {
            scenario = .splitMedia
        } else if isChatApp {
            scenario = .chatApp
        } else if isCardFeed {
            scenario = .cardFeed
        } else if isWebArticle {
            scenario = .webArticle
        } else {
            scenario = .generalScroll
        }
        
        return ScrollZoneDetectionResult(
            topAnchorHeight: fullTopAnchor,
            bottomAnchorHeight: fullBottomAnchor,
            isSplitScreenMedia: isSplitMedia,
            isChatAppDetected: isChatApp,
            isCardFeedDetected: isCardFeed,
            isWebArticleDetected: isWebArticle,
            scrollVelocityEstimate: coarseDy * topBuf.scaleY,
            confidence: max(0.5, coarseMatch.confidence),
            scenario: scenario
        )
    }
    
    /// Multi-Slice Spatial Consensus Voting across all adjacent slice pairs
    public static func detectConsensusScrollZone(
        slices: [CGImage]
    ) -> ScrollZoneDetectionResult {
        guard slices.count >= 2 else {
            return ScrollZoneDetectionResult(
                topAnchorHeight: 0,
                bottomAnchorHeight: 0,
                isSplitScreenMedia: false,
                isChatAppDetected: false,
                scrollVelocityEstimate: 0,
                confidence: 0
            )
        }
        
        var detectedTops: [CGFloat] = []
        var detectedBottoms: [CGFloat] = []
        var splitMediaVotes = 0
        var chatAppVotes = 0
        var cardFeedVotes = 0
        var webArticleVotes = 0
        var scenarioVotes: [AppLayoutScenario: Int] = [:]
        var maxConfidence = 0.0
        var velocities: [CGFloat] = []
        
        let pairCount = min(slices.count - 1, 4)
        for i in 0..<pairCount {
            let res = detectAdaptiveScrollZone(topImage: slices[i], bottomImage: slices[i + 1])
            if res.confidence > 0.40 {
                detectedTops.append(res.topAnchorHeight)
                detectedBottoms.append(res.bottomAnchorHeight)
                if res.isSplitScreenMedia { splitMediaVotes += 1 }
                if res.isChatAppDetected { chatAppVotes += 1 }
                if res.isCardFeedDetected { cardFeedVotes += 1 }
                if res.isWebArticleDetected { webArticleVotes += 1 }
                scenarioVotes[res.scenario, default: 0] += 1
                maxConfidence = max(maxConfidence, res.confidence)
                velocities.append(res.scrollVelocityEstimate)
            }
        }
        
        let finalTop: CGFloat
        if detectedTops.isEmpty {
            finalTop = 0
        } else {
            let sorted = detectedTops.sorted()
            finalTop = sorted[sorted.count / 2]
        }
        
        let finalBottom: CGFloat
        if detectedBottoms.isEmpty {
            finalBottom = 0
        } else {
            let sorted = detectedBottoms.sorted()
            finalBottom = sorted[sorted.count / 2]
        }
        
        let finalVelocity: CGFloat
        if velocities.isEmpty {
            finalVelocity = 0
        } else {
            let sorted = velocities.sorted()
            finalVelocity = sorted[sorted.count / 2]
        }
        
        let consensusScenario = scenarioVotes.max(by: { $0.value < $1.value })?.key ?? .generalScroll
        
        return ScrollZoneDetectionResult(
            topAnchorHeight: finalTop,
            bottomAnchorHeight: finalBottom,
            isSplitScreenMedia: splitMediaVotes > 0,
            isChatAppDetected: chatAppVotes > 0,
            isCardFeedDetected: cardFeedVotes > 0,
            isWebArticleDetected: webArticleVotes > 0,
            scrollVelocityEstimate: finalVelocity,
            confidence: max(0.5, maxConfidence),
            scenario: consensusScenario
        )
    }
    
    /// Detects repeating static top navigation bars and bottom bars
    public static func detectStaticChromeRegions(
        topImage: CGImage,
        bottomImage: CGImage
    ) -> StaticChromeDetectionResult {
        let zone = detectAdaptiveScrollZone(topImage: topImage, bottomImage: bottomImage)
        return StaticChromeDetectionResult(
            topBarHeight: zone.topAnchorHeight,
            bottomBarHeight: zone.bottomAnchorHeight
        )
    }
    
    // MARK: - Core 2D Overlap Detection Entry Point
    
    /// Calculates optimal vertical overlap using 2D Spatial Coarse-to-Fine Patch Matching,
    /// sub-pixel parabolic peak refinement, and scenario-adaptive minimal energy seam carving.
    public static func findOverlap(
        topSlice: CGImage,
        bottomSlice: CGImage,
        topSliceTopCrop: CGFloat = 0,
        topSliceBottomCrop: CGFloat = 0,
        bottomSliceTopCrop: CGFloat = 0,
        bottomSliceBottomCrop: CGFloat = 0,
        templateHeightPt: CGFloat = 120,
        minOverlapRatio: CGFloat = 0.05,
        maxOverlapRatio: CGFloat = 0.95,
        expectedDisplacement: CGFloat? = nil,
        scenario: AppLayoutScenario = .generalScroll
    ) -> OverlapMatchResult {
        let origW = min(topSlice.width, bottomSlice.width)
        let topH = topSlice.height
        let botH = bottomSlice.height
        guard origW > 0, topH > 100, botH > 100 else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        guard let topBuf = createGrayscaleBuffer(from: topSlice, targetWidth: 320),
              let botBuf = createGrayscaleBuffer(from: bottomSlice, targetWidth: 320) else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        // Step 1: 2D Multi-Patch Spatial Matching
        let coarseMatch = match2DPatches(
            topBuf: topBuf,
            botBuf: botBuf,
            expectedDisplacement: expectedDisplacement
        )
        
        guard coarseMatch.confidence > 0.20 && coarseMatch.displacement > 5.0 else {
            return OverlapMatchResult(offset: 0, confidence: coarseMatch.confidence, optimalSeamY: 0)
        }
        
        // Step 2: Full-Resolution 2D Subpixel Refinement
        let refined = refineFullResolutionSubpixel(
            topImage: topSlice,
            bottomImage: bottomSlice,
            coarseDisplacement: coarseMatch.displacement,
            scaleY: topBuf.scaleY
        )
        
        let displacement = refined.fineDisplacement
        let rawFullOverlap = CGFloat(topH) - displacement
        guard rawFullOverlap > 10 else {
            return OverlapMatchResult(offset: 0, confidence: refined.confidence, optimalSeamY: 0)
        }
        
        // Effective overlap of the visible cropped content
        let contentOverlap = max(0.0, rawFullOverlap - topSliceBottomCrop - bottomSliceTopCrop)
        guard contentOverlap > 10 else {
            return OverlapMatchResult(offset: 0, confidence: max(0.2, refined.confidence - 0.3), optimalSeamY: 0)
        }
        
        // Step 3: Scenario-Adaptive Minimal Energy Seam Carving
        // Search inside the content overlap zone [0 ... contentOverlap]
        // Row in topSlice: (topH - topSliceBottomCrop - contentOverlap) + k
        // Row in bottomSlice: bottomSliceTopCrop + k
        let topBaseRow = Int(CGFloat(topH) - topSliceBottomCrop - contentOverlap)
        let botBaseRow = Int(bottomSliceTopCrop)
        let maxK = Int(contentOverlap)
        
        let optimalK = findMinimalEnergySeamOffset(
            topSlice: topSlice,
            topBaseRow: topBaseRow,
            bottomBaseRow: botBaseRow,
            spanK: maxK,
            scenario: scenario
        )
        
        return OverlapMatchResult(
            offset: contentOverlap,
            confidence: refined.confidence,
            optimalSeamY: CGFloat(optimalK)
        )
    }
    
    /// Backward-compatible overload
    public static func findOverlap(
        topSlice: CGImage,
        bottomSlice: CGImage,
        topCropInset: CGFloat = 0,
        bottomCropInset: CGFloat = 0,
        templateHeightPt: CGFloat = 120,
        minOverlapRatio: CGFloat = 0.05,
        maxOverlapRatio: CGFloat = 0.95,
        expectedDisplacement: CGFloat? = nil,
        scenario: AppLayoutScenario = .generalScroll
    ) -> OverlapMatchResult {
        return findOverlap(
            topSlice: topSlice,
            bottomSlice: bottomSlice,
            topSliceTopCrop: 0,
            topSliceBottomCrop: bottomCropInset,
            bottomSliceTopCrop: topCropInset,
            bottomSliceBottomCrop: 0,
            templateHeightPt: templateHeightPt,
            minOverlapRatio: minOverlapRatio,
            maxOverlapRatio: maxOverlapRatio,
            expectedDisplacement: expectedDisplacement,
            scenario: scenario
        )
    }
    
    // MARK: - Minimal Energy Seam Line Search
    
    /// Evaluates edge energy and whitespace valleys within the content overlap window [0 ... spanK]
    /// to cleanly place the seam cut without slicing through message bubbles or text.
    private static func findMinimalEnergySeamOffset(
        topSlice: CGImage,
        topBaseRow: Int,
        bottomBaseRow: Int,
        spanK: Int,
        scenario: AppLayoutScenario
    ) -> Int {
        guard spanK > 6 else {
            return max(0, spanK / 2)
        }
        
        let profile = calculateVerticalProfile(cgImage: topSlice)
        let luminance = profile.luminance
        let horizontalEnergy = profile.horizontalEdgeEnergy
        
        let midK = spanK / 2
        let windowLen = max(1.0, Double(spanK))
        
        var minSmoothedEnergy = Double.greatestFiniteMagnitude
        var bestK = midK
        
        let scanStart = 4
        let scanEnd = max(scanStart, spanK - 4)
        guard scanStart <= scanEnd else {
            return midK
        }
        
        for k in scanStart...scanEnd {
            let y = topBaseRow + k
            guard y >= 2, y < luminance.count - 3 else { continue }
            
            let hE_m1 = horizontalEnergy[y - 1]
            let hE_0  = horizontalEnergy[y]
            let hE_p1 = horizontalEnergy[y + 1]
            let hE_m2 = horizontalEnergy[y - 2]
            let hE_p2 = horizontalEnergy[y + 2]
            
            let vE_m1 = abs(luminance[y] - luminance[y - 1])
            let vE_0  = abs(luminance[y + 1] - luminance[y - 1]) * 0.5
            let vE_p1 = abs(luminance[y + 1] - luminance[y])
            
            let lumContext = (luminance[y] + luminance[y - 1] + luminance[y + 1]) / 3.0
            let edgeWeight: Double = lumContext < 0.35 ? 0.85 : 0.70
            let vertWeight: Double = lumContext < 0.35 ? 0.30 : 0.25
            
            let e_m1 = hE_m1 * edgeWeight + vE_m1 * vertWeight
            let e_0  = hE_0  * edgeWeight + vE_0  * vertWeight
            let e_p1 = hE_p1 * edgeWeight + vE_p1 * vertWeight
            let avgE = e_0 * 0.50 + (e_m1 + e_p1) * 0.25
            
            let maxNearbyEdge = max(hE_m2, max(hE_m1, max(hE_p1, hE_p2)))
            var edgePenalty = 0.0
            var scenarioBonus = 0.0
            
            switch scenario {
            case .chatApp:
                // Chat apps: heavy penalty for cutting close to speech bubble edges,
                // strong bonus for empty whitespace valleys between bubbles
                if maxNearbyEdge > 0.06 {
                    edgePenalty = 0.10
                }
                if avgE < 0.025 {
                    scenarioBonus = -0.08
                }
            case .cardFeed:
                // Social / Card feeds: snap seam onto card divider hairlines or gray spacer strips
                let isDividerPeak = hE_0 > 0.07 && hE_0 >= hE_m1 && hE_0 >= hE_p1
                if isDividerPeak {
                    scenarioBonus = -0.12
                } else if maxNearbyEdge > 0.08 {
                    edgePenalty = 0.06
                }
            case .webArticle:
                // Web articles: snap seam into paragraph spacing or article breaks
                if maxNearbyEdge > 0.07 {
                    edgePenalty = 0.07
                }
                if avgE < 0.035 && hE_0 < 0.03 {
                    scenarioBonus = -0.06
                }
            case .splitMedia:
                if maxNearbyEdge > 0.07 {
                    edgePenalty = 0.06
                }
                if avgE < 0.03 {
                    scenarioBonus = -0.05
                }
            case .generalScroll:
                if maxNearbyEdge > 0.08 {
                    edgePenalty = 0.05
                }
            }
            
            let centerDistPenalty = (abs(Double(k - midK)) / windowLen) * 0.03
            let totalE = avgE + edgePenalty + scenarioBonus + centerDistPenalty
            
            if totalE < minSmoothedEnergy {
                minSmoothedEnergy = totalE
                bestK = k
            }
        }
        return bestK
    }
    
    // MARK: - 1D Vertical Luminance & Edge Profiling (Backward-Compatible)
    
    public static func calculateVerticalProfile(cgImage: CGImage) -> ImageProfile1D {
        let sampleWidth = 128
        let height = cgImage.height
        var luminance = [Double](repeating: 0.0, count: height)
        var edgeEnergy = [Double](repeating: 0.0, count: height)
        var combinedFeature = [Double](repeating: 0.0, count: height)
        
        let bytesPerRow = sampleWidth
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let context = CGContext(
            data: &rawData,
            width: sampleWidth,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return ImageProfile1D(luminance: luminance, horizontalEdgeEnergy: edgeEnergy, combinedFeature: combinedFeature)
        }
        
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: height))
        
        let safeLeft = max(2, Int(Double(sampleWidth) * 0.04))
        let safeRight = min(sampleWidth - 2, Int(Double(sampleWidth) * 0.92))
        let safeSpan = max(1, safeRight - safeLeft)
        let invScale = 1.0 / (Double(safeSpan) * 255.0)
        let invGradScale = 1.0 / (Double(max(1, safeSpan - 1)) * 255.0)
        
        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            var sumLum = Double(rawData[rowOffset + safeLeft])
            var sumGrad: Double = 0.0
            var prevVal = sumLum
            
            for x in (safeLeft + 1)..<safeRight {
                let val = Double(rawData[rowOffset + x])
                let diff = abs(val - prevVal)
                sumLum += val
                sumGrad += diff
                prevVal = val
            }
            
            luminance[y] = sumLum * invScale
            edgeEnergy[y] = sumGrad * invGradScale
        }
        
        for y in 0..<height {
            let vertDiff = (y > 0) ? abs(luminance[y] - luminance[y - 1]) : 0.0
            combinedFeature[y] = luminance[y] * 0.25 + edgeEnergy[y] * 0.55 + vertDiff * 0.20
        }
        return ImageProfile1D(luminance: luminance, horizontalEdgeEnergy: edgeEnergy, combinedFeature: combinedFeature)
    }
    
    public static func calculateVerticalLuminanceProfile(cgImage: CGImage) -> [Double] {
        return calculateVerticalProfile(cgImage: cgImage).luminance
    }
}
