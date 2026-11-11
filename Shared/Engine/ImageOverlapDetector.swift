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
    
    // MARK: - Column Fingerprint Data Structure
    
    private struct ColumnFingerprintData {
        let sampleWidth: Int
        let height: Int
        let numCols: Int
        let samples: [UInt8]
        let rowVariance: [Double]
    }
    
    // MARK: - 2D Grayscale Bitmap Downsampler
    
    /// Downscales a high-resolution screenshot into a standardized 2D grayscale analysis buffer (width ~320).
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
    
    // MARK: - Spatial Column Fingerprint Extraction
    
    /// Extracts a 32-column vertical spatial fingerprint and row variances across the screen.
    private static func extractFingerprint(buffer: ImageBuffer2D, numCols: Int = 32) -> ColumnFingerprintData {
        let W = buffer.width
        let H = buffer.height
        let marginX = max(8, Int(Double(W) * 0.05))
        let activeWidth = max(20, W - 2 * marginX)
        
        var colX = [Int](repeating: 0, count: numCols)
        for m in 0..<numCols {
            colX[m] = marginX + Int(round(Double(m) * Double(activeWidth - 1) / Double(numCols - 1)))
        }
        
        var samples = [UInt8](repeating: 0, count: H * numCols)
        var variances = [Double](repeating: 0.0, count: H)
        
        buffer.data.withUnsafeBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else { return }
            for y in 0..<H {
                let rowOffset = y * W
                let outOffset = y * numCols
                var sumVal: Int = 0
                var sumSqVal: Int = 0
                for m in 0..<numCols {
                    let v = Int(base[rowOffset + colX[m]])
                    samples[outOffset + m] = UInt8(v)
                    sumVal += v
                    sumSqVal += v * v
                }
                let mean = Double(sumVal) / Double(numCols)
                variances[y] = max(0.0, (Double(sumSqVal) / Double(numCols)) - (mean * mean))
            }
        }
        
        return ColumnFingerprintData(
            sampleWidth: W,
            height: H,
            numCols: numCols,
            samples: samples,
            rowVariance: variances
        )
    }
    
    // MARK: - Static Chrome Isolation
    
    /// Detects repeating static top navigation bars and bottom tab/input bars
    /// by comparing the 32-column fingerprints of identical row positions.
    private static func analyzeStaticChrome(
        topFP: ColumnFingerprintData,
        botFP: ColumnFingerprintData
    ) -> (topChromeRows: Int, botChromeRows: Int) {
        let H = min(topFP.height, botFP.height)
        let numCols = topFP.numCols
        
        var staticDiff = [Double](repeating: 0.0, count: H)
        for y in 0..<H {
            let off = y * numCols
            var diffSum: Int = 0
            for m in 0..<numCols {
                diffSum += abs(Int(topFP.samples[off + m]) - Int(botFP.samples[off + m]))
            }
            staticDiff[y] = Double(diffSum) / Double(numCols)
        }
        
        // Scan from top downward (max top chrome: 65% of screen for split media)
        var topChrome = 0
        let maxTopScan = min(Int(Double(H) * 0.65), H - 80)
        var consecutiveMoving = 0
        for y in 0..<maxTopScan {
            let isMoving = (staticDiff[y] > 11.0) && (topFP.rowVariance[y] > 3.0 || botFP.rowVariance[y] > 3.0)
            if isMoving {
                consecutiveMoving += 1
                if consecutiveMoving >= 3 {
                    topChrome = max(0, y - 2)
                    break
                }
            } else {
                consecutiveMoving = 0
            }
        }
        
        // Scan from bottom upward (max bottom chrome: 35% of screen)
        var botChrome = 0
        let maxBotScan = min(Int(Double(H) * 0.35), H - 80)
        consecutiveMoving = 0
        for i in 0..<maxBotScan {
            let y = H - 1 - i
            guard y >= 0 else { break }
            let isMoving = (staticDiff[y] > 11.0) && (topFP.rowVariance[y] > 3.0 || botFP.rowVariance[y] > 3.0)
            if isMoving {
                consecutiveMoving += 1
                if consecutiveMoving >= 3 {
                    botChrome = max(0, i - 2)
                    break
                }
            } else {
                consecutiveMoving = 0
            }
        }
        
        // Verify confirmed static UI features
        var confirmedTop = 0
        for y in 0..<topChrome {
            if staticDiff[y] < 8.0 && (topFP.rowVariance[y] > 2.0 || botFP.rowVariance[y] > 2.0) {
                confirmedTop += 1
            }
        }
        if confirmedTop < 2 {
            topChrome = 0
        }
        
        var confirmedBot = 0
        for i in 0..<botChrome {
            let y = H - 1 - i
            if staticDiff[y] < 8.0 && (topFP.rowVariance[y] > 2.0 || botFP.rowVariance[y] > 2.0) {
                confirmedBot += 1
            }
        }
        if confirmedBot < 2 {
            botChrome = 0
        }
        
        return (topChrome, botChrome)
    }
    
    // MARK: - Global Spatial Displacement Search
    
    /// Finds the exact global displacement across all candidate displacements in the active scrolling zone.
    private static func findDisplacementCandidate(
        topFP: ColumnFingerprintData,
        botFP: ColumnFingerprintData,
        topChrome: Int,
        botChrome: Int,
        expectedDisplacement: CGFloat? = nil
    ) -> (displacement: CGFloat, confidence: Double, isReverse: Bool) {
        let H = min(topFP.height, botFP.height)
        let numCols = topFP.numCols
        
        let yTop = topChrome
        let yBot = H - botChrome
        guard yBot > yTop + 30 else {
            return (0, 0, false)
        }
        
        let minD = 4
        let maxD = max(minD, yBot - yTop - 15)
        
        var bestD = 0
        var minScore = Double.greatestFiniteMagnitude
        
        // Forward scroll search: content in topFP at y moved to botFP at y - d
        for d in minD...maxD {
            let K = yBot - yTop - d
            guard K >= 15 else { continue }
            
            var texturedSum: Int = 0
            var texturedRows: Int = 0
            var totalSum: Int = 0
            
            for k in 0..<K {
                let yA = yTop + d + k
                let yB = yTop + k
                
                let offA = yA * numCols
                let offB = yB * numCols
                
                let isTextured = (topFP.rowVariance[yA] > 3.5 || botFP.rowVariance[yB] > 3.5)
                var rowDiff: Int = 0
                for m in 0..<numCols {
                    rowDiff += abs(Int(topFP.samples[offA + m]) - Int(botFP.samples[offB + m]))
                }
                
                totalSum += rowDiff
                if isTextured {
                    texturedSum += rowDiff
                    texturedRows += 1
                }
            }
            
            let effectiveScore: Double
            if texturedRows >= 10 {
                effectiveScore = Double(texturedSum) / Double(texturedRows * numCols)
            } else {
                effectiveScore = Double(totalSum) / Double(K * numCols)
            }
            
            var velocityPenalty = 0.0
            if let expected = expectedDisplacement {
                let dist = abs(CGFloat(d) - expected)
                velocityPenalty = Double(dist / 50.0) * 0.15
            }
            
            let totalScore = effectiveScore + velocityPenalty
            if totalScore < minScore {
                minScore = totalScore
                bestD = d
            }
        }
        
        let forwardConfidence: Double
        if minScore < 30.0 {
            forwardConfidence = max(0.50, min(1.0, 1.0 - (minScore / 32.0)))
        } else {
            forwardConfidence = 0.0
        }
        
        if forwardConfidence > 0.70 {
            return (CGFloat(bestD), forwardConfidence, false)
        }
        
        // Reverse Sequence Fallback Check (newest to oldest):
        var bestRevD = 0
        var minRevScore = Double.greatestFiniteMagnitude
        for d in minD...maxD {
            let K = yBot - yTop - d
            guard K >= 15 else { continue }
            var texturedSum: Int = 0
            var texturedRows: Int = 0
            var totalSum: Int = 0
            
            for k in 0..<K {
                let yB = yTop + d + k
                let yA = yTop + k
                let offA = yA * numCols
                let offB = yB * numCols
                let isTextured = (topFP.rowVariance[yA] > 3.5 || botFP.rowVariance[yB] > 3.5)
                var rowDiff: Int = 0
                for m in 0..<numCols {
                    rowDiff += abs(Int(topFP.samples[offA + m]) - Int(botFP.samples[offB + m]))
                }
                totalSum += rowDiff
                if isTextured {
                    texturedSum += rowDiff
                    texturedRows += 1
                }
            }
            let score = texturedRows >= 10 ? (Double(texturedSum) / Double(texturedRows * numCols)) : (Double(totalSum) / Double(K * numCols))
            if score < minRevScore {
                minRevScore = score
                bestRevD = d
            }
        }
        
        let revConfidence: Double
        if minRevScore < 30.0 {
            revConfidence = max(0.40, min(1.0, 1.0 - (minRevScore / 32.0)))
        } else {
            revConfidence = 0.0
        }
        
        if revConfidence > forwardConfidence + 0.15 && revConfidence > 0.45 {
            return (CGFloat(bestRevD), revConfidence, true)
        }
        
        return (CGFloat(bestD), forwardConfidence, false)
    }
    
    // MARK: - Full-Resolution 1-Pixel Subpixel Refinement
    
    /// Refines the coarse displacement to exact 1-pixel resolution using 3 distinct multi-band anchors
    /// inside the verified overlap region, followed by parabolic interpolation.
    private static func refineFullResolutionMultiBand(
        topImage: CGImage,
        bottomImage: CGImage,
        coarseDy: CGFloat,
        scaleY: CGFloat,
        topCrop: CGFloat,
        botCrop: CGFloat
    ) -> (fineDisplacement: CGFloat, confidence: Double) {
        let origW = min(topImage.width, bottomImage.width)
        let origH = min(topImage.height, bottomImage.height)
        guard origW > 60, origH > 200 else {
            return (coarseDy * scaleY, 0.8)
        }
        
        let targetDy = coarseDy * scaleY
        let rawOverlap = CGFloat(origH) - targetDy
        guard rawOverlap > 30 else {
            return (targetDy, 0.8)
        }
        
        let startYB = topCrop + 10
        let endYB = min(CGFloat(origH) - botCrop - 20, rawOverlap - 10)
        guard endYB > startYB + 30 else {
            return (targetDy, 0.8)
        }
        
        let anchorRatios: [CGFloat] = [0.25, 0.50, 0.75]
        let patchH = 32
        let sampleW = min(origW - 40, 480)
        let startX = (origW - sampleW) / 2
        let searchRadius = 6
        
        var refinedVotes: [CGFloat] = []
        var bestErrors: [Double] = []
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        for ratio in anchorRatios {
            let yB = Int(startYB + (endYB - startYB) * ratio)
            guard yB + patchH < origH else { continue }
            
            var patchB = [UInt8](repeating: 0, count: sampleW * patchH)
            guard let ctxB = CGContext(
                data: &patchB,
                width: sampleW,
                height: patchH,
                bitsPerComponent: 8,
                bytesPerRow: sampleW,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { continue }
            ctxB.interpolationQuality = .none
            ctxB.draw(bottomImage, in: CGRect(x: -startX, y: -yB, width: origW, height: origH))
            
            var sumVal = 0
            var sumSqVal = 0
            let totalPix = sampleW * patchH
            for b in patchB {
                let v = Int(b)
                sumVal += v
                sumSqVal += v * v
            }
            let mean = Double(sumVal) / Double(totalPix)
            let variance = (Double(sumSqVal) / Double(totalPix)) - (mean * mean)
            guard variance > 6.0 else { continue }
            
            let baseYA = yB + Int(round(targetDy))
            let searchMinYA = baseYA - searchRadius
            let searchMaxYA = baseYA + searchRadius
            guard searchMinYA >= 0, searchMaxYA + patchH <= origH else { continue }
            
            let stripH = (searchMaxYA - searchMinYA) + patchH
            var stripA = [UInt8](repeating: 0, count: sampleW * stripH)
            guard let ctxA = CGContext(
                data: &stripA,
                width: sampleW,
                height: stripH,
                bitsPerComponent: 8,
                bytesPerRow: sampleW,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { continue }
            ctxA.interpolationQuality = .none
            ctxA.draw(topImage, in: CGRect(x: -startX, y: -searchMinYA, width: origW, height: origH))
            
            var bestDelta = 0
            var minMAD = Double.greatestFiniteMagnitude
            var errorMap: [Int: Double] = [:]
            
            for delta in (-searchRadius)...searchRadius {
                let offA = (delta + searchRadius) * sampleW
                var diffSum = 0
                for r in 0..<patchH {
                    let rA = offA + r * sampleW
                    let rB = r * sampleW
                    for c in stride(from: 0, to: sampleW, by: 2) {
                        diffSum += abs(Int(stripA[rA + c]) - Int(patchB[rB + c]))
                    }
                }
                let mad = Double(diffSum) / Double(sampleW * patchH / 2)
                errorMap[delta] = mad
                if mad < minMAD {
                    minMAD = mad
                    bestDelta = delta
                }
            }
            
            if minMAD < 28.0 {
                var subDelta = CGFloat(bestDelta)
                if let e0 = errorMap[bestDelta],
                   let eM1 = errorMap[bestDelta - 1],
                   let eP1 = errorMap[bestDelta + 1] {
                    let denom = 2.0 * (eM1 + eP1 - 2.0 * e0)
                    if abs(denom) > 0.0001 {
                        let shift = (eM1 - eP1) / denom
                        if abs(shift) <= 0.5 {
                            subDelta += CGFloat(shift)
                        }
                    }
                }
                let fineDy = round(targetDy) + subDelta
                refinedVotes.append(fineDy)
                bestErrors.append(minMAD)
            }
        }
        
        guard !refinedVotes.isEmpty else {
            return (targetDy, 0.8)
        }
        
        let finalDy = refinedVotes.reduce(0.0, +) / CGFloat(refinedVotes.count)
        let avgErr = bestErrors.reduce(0.0, +) / Double(bestErrors.count)
        let conf = max(0.60, min(1.0, 1.0 - (avgErr / 30.0)))
        return (finalDy, conf)
    }
    
    // MARK: - Core 2D Overlap Detection Entry Point
    
    /// Calculates optimal vertical overlap using 32-column spatial fingerprint cross-correlation,
    /// 3-band full-resolution 1-pixel subpixel refinement, and scenario-adaptive minimal energy seam carving.
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
        
        let topFP = extractFingerprint(buffer: topBuf)
        let botFP = extractFingerprint(buffer: botBuf)
        
        // Step 1: Detect static chrome rows
        let chrome = analyzeStaticChrome(topFP: topFP, botFP: botFP)
        
        // Step 2: Global spatial displacement candidate search
        let coarseMatch = findDisplacementCandidate(
            topFP: topFP,
            botFP: botFP,
            topChrome: chrome.topChromeRows,
            botChrome: chrome.botChromeRows,
            expectedDisplacement: expectedDisplacement.map { $0 / topBuf.scaleY }
        )
        
        guard coarseMatch.confidence > 0.20 && coarseMatch.displacement > 2.0 else {
            return OverlapMatchResult(offset: 0, confidence: coarseMatch.confidence, optimalSeamY: 0)
        }
        
        // Step 3: Full-Resolution 1-Pixel Subpixel Refinement
        let refined = refineFullResolutionMultiBand(
            topImage: topSlice,
            bottomImage: bottomSlice,
            coarseDy: coarseMatch.displacement,
            scaleY: topBuf.scaleY,
            topCrop: bottomSliceTopCrop,
            botCrop: topSliceBottomCrop
        )
        
        let displacement = refined.fineDisplacement
        let rawFullOverlap = CGFloat(topH) - displacement
        guard rawFullOverlap > 10 else {
            return OverlapMatchResult(offset: 0, confidence: refined.confidence, optimalSeamY: 0)
        }
        
        // Effective overlap of the visible cropped content
        let contentOverlap = max(0.0, rawFullOverlap - topSliceBottomCrop - bottomSliceTopCrop)
        guard contentOverlap > 5 else {
            return OverlapMatchResult(offset: 0, confidence: max(0.2, refined.confidence - 0.3), optimalSeamY: 0)
        }
        
        // Step 4: Scenario-Adaptive Minimal Energy Seam Carving
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
    
    // MARK: - Scenario & Scroll Zone Detection Entry Point
    
    /// Detects top navigation bars, split-screen video note players, and bottom input/tab bars
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
        
        let topFP = extractFingerprint(buffer: topBuf)
        let botFP = extractFingerprint(buffer: botBuf)
        
        let chrome = analyzeStaticChrome(topFP: topFP, botFP: botFP)
        let match = findDisplacementCandidate(
            topFP: topFP,
            botFP: botFP,
            topChrome: chrome.topChromeRows,
            botChrome: chrome.botChromeRows
        )
        
        let fullTopAnchor = CGFloat(chrome.topChromeRows) * topBuf.scaleY
        let fullBottomAnchor = CGFloat(chrome.botChromeRows) * topBuf.scaleY
        
        let isSplitMedia = fullTopAnchor > (CGFloat(origH) * 0.18)
        let isChatApp = !isSplitMedia && fullTopAnchor >= 100 && fullTopAnchor <= 380 && fullBottomAnchor >= 80 && fullBottomAnchor <= 380
        let isWebArticle = !isSplitMedia && !isChatApp && fullTopAnchor >= 60 && fullTopAnchor <= 320 && fullBottomAnchor >= 40 && fullBottomAnchor <= 240
        
        let scenario: AppLayoutScenario
        if isSplitMedia {
            scenario = .splitMedia
        } else if isChatApp {
            scenario = .chatApp
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
            isCardFeedDetected: false,
            isWebArticleDetected: isWebArticle,
            scrollVelocityEstimate: match.displacement * topBuf.scaleY,
            confidence: max(0.5, match.confidence),
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
                if res.isWebArticleDetected { webArticleVotes += 1 }
                scenarioVotes[res.scenario, default: 0] += 1
                maxConfidence = max(maxConfidence, res.confidence)
                velocities.append(res.scrollVelocityEstimate)
            }
        }
        
        let finalTop = detectedTops.isEmpty ? 0 : detectedTops.sorted()[detectedTops.count / 2]
        let finalBottom = detectedBottoms.isEmpty ? 0 : detectedBottoms.sorted()[detectedBottoms.count / 2]
        let finalVelocity = velocities.isEmpty ? 0 : velocities.sorted()[velocities.count / 2]
        let consensusScenario = scenarioVotes.max(by: { $0.value < $1.value })?.key ?? .generalScroll
        
        return ScrollZoneDetectionResult(
            topAnchorHeight: finalTop,
            bottomAnchorHeight: finalBottom,
            isSplitScreenMedia: splitMediaVotes > 0,
            isChatAppDetected: chatAppVotes > 0,
            isCardFeedDetected: false,
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
                if maxNearbyEdge > 0.06 {
                    edgePenalty = 0.10
                }
                if avgE < 0.025 {
                    scenarioBonus = -0.08
                }
            case .cardFeed:
                let isDividerPeak = hE_0 > 0.07 && hE_0 >= hE_m1 && hE_0 >= hE_p1
                if isDividerPeak {
                    scenarioBonus = -0.12
                } else if maxNearbyEdge > 0.08 {
                    edgePenalty = 0.06
                }
            case .webArticle:
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
