import Foundation
import CoreGraphics
#if canImport(Accelerate)
import Accelerate
#endif

public struct OverlapMatchResult {
    public let offset: CGFloat
    public let confidence: Double
    public let optimalSeamY: CGFloat
}

public struct StaticChromeDetectionResult {
    public let topBarHeight: CGFloat
    public let bottomBarHeight: CGFloat
}

public struct ScrollZoneDetectionResult {
    public let topAnchorHeight: CGFloat
    public let bottomAnchorHeight: CGFloat
    public let isSplitScreenMedia: Bool
    public let scrollVelocityEstimate: CGFloat
    public let confidence: Double
    
    public init(
        topAnchorHeight: CGFloat,
        bottomAnchorHeight: CGFloat,
        isSplitScreenMedia: Bool,
        scrollVelocityEstimate: CGFloat,
        confidence: Double
    ) {
        self.topAnchorHeight = topAnchorHeight
        self.bottomAnchorHeight = bottomAnchorHeight
        self.isSplitScreenMedia = isSplitScreenMedia
        self.scrollVelocityEstimate = scrollVelocityEstimate
        self.confidence = confidence
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
    
    /// Multi-scenario adaptive scroll zone detection (Auto-ROI):
    /// Analyzes screen geometry and vertical motion coherence to detect stationary navigation bars,
    /// bottom input/tab bars, and split-screen media players (e.g. Xiaohongshu video notes, Bilibili, Douyin).
    public static func detectAdaptiveScrollZone(
        topImage: CGImage,
        bottomImage: CGImage
    ) -> ScrollZoneDetectionResult {
        let width = min(topImage.width, bottomImage.width)
        let height = min(topImage.height, bottomImage.height)
        guard width > 0, height > 300 else {
            return ScrollZoneDetectionResult(
                topAnchorHeight: 0,
                bottomAnchorHeight: 0,
                isSplitScreenMedia: false,
                scrollVelocityEstimate: 0,
                confidence: 0
            )
        }
        
        let profileTop = calculateVerticalProfile(cgImage: topImage)
        let profileBottom = calculateVerticalProfile(cgImage: bottomImage)
        let featA = profileTop.combinedFeature
        let featB = profileBottom.combinedFeature
        
        // Step 1: Detect dominant scroll displacement in lower-middle body (50% ~ 85% height)
        let probeStart = Int(Double(height) * 0.55)
        let probeLen = min(140, Int(Double(height) * 0.12))
        var dominantDisplacement: Int = 0
        var probeConfidence: Double = 0.0
        
        if probeStart + probeLen < height - 50 {
            let template = Array(featB[probeStart..<(probeStart + probeLen)])
            var sumT = 0.0
            var sumSqT = 0.0
            let invT = 1.0 / Double(probeLen)
            for v in template {
                sumT += v
                sumSqT += v * v
            }
            let varT = max(0.0, sumSqT - (sumT * sumT) * invT)
            
            if varT > 0.0001 {
                let searchMin = Int(Double(height) * 0.15)
                let searchMax = min(height - probeLen, Int(Double(height) * 0.85))
                
                var bestOffset = probeStart
                var maxR = -1.0
                
                for offset in stride(from: searchMin, through: searchMax, by: 2) {
                    var sumS = 0.0
                    var sumSqS = 0.0
                    var dot = 0.0
                    for i in 0..<probeLen {
                        let s = featA[offset + i]
                        let t = template[i]
                        sumS += s
                        sumSqS += s * s
                        dot += s * t
                    }
                    let varS = max(0.0, sumSqS - (sumS * sumS) * invT)
                    guard varS > 0.0001 else { continue }
                    let denom = sqrt(varS * varT)
                    if denom > 0.0001 {
                        let r = (dot - (sumS * sumT) * invT) / denom
                        if r > maxR {
                            maxR = r
                            bestOffset = offset
                        }
                    }
                }
                
                probeConfidence = max(0.0, min(1.0, maxR))
                if probeConfidence > 0.35 {
                    dominantDisplacement = probeStart - bestOffset
                }
            }
        }
        
        // Step 2: Detect Stationary Bottom Anchor (input bar, tab bar, home indicator)
        var detectedBottom: Int = 0
        let maxBottomScan = min(Int(Double(height) * 0.25), 320)
        for i in 0..<maxBottomScan {
            let yA = height - 1 - i
            let yB = height - 1 - i
            guard yA >= 0, yB >= 0 else { break }
            let diffLum = abs(profileTop.luminance[yA] - profileBottom.luminance[yB])
            let diffEdge = abs(profileTop.horizontalEdgeEnergy[yA] - profileBottom.horizontalEdgeEnergy[yB])
            if diffLum < 0.035 && diffEdge < 0.035 {
                detectedBottom = i
            } else if i > 50 {
                break
            }
        }
        let bottomAnchor = detectedBottom > 35 ? CGFloat(detectedBottom) : 0
        
        // Step 3: Detect Stationary Top Anchor (Nav bar vs. Half-Screen Media like Xiaohongshu video)
        var detectedTop: Int = 0
        let maxTopScan = min(Int(Double(height) * 0.65), height - 200)
        var consecutiveNonStaticCount = 0
        
        for y in 0..<maxTopScan {
            let diffLum = abs(profileTop.luminance[y] - profileBottom.luminance[y])
            let diffEdge = abs(profileTop.horizontalEdgeEnergy[y] - profileBottom.horizontalEdgeEnergy[y])
            let isRowStatic = diffLum < 0.035 && diffEdge < 0.035
            
            if isRowStatic {
                detectedTop = y
                consecutiveNonStaticCount = 0
            } else {
                consecutiveNonStaticCount += 1
                if y < 320 && consecutiveNonStaticCount > 20 {
                    break
                } else if y >= 320 && consecutiveNonStaticCount > 30 {
                    break
                }
            }
        }
        
        // Step 4: Refine split boundary using motion coherence when dominant displacement is known
        var finalTopAnchor = CGFloat(detectedTop > 40 ? detectedTop : 0)
        if dominantDisplacement > 30 && probeConfidence > 0.40 {
            let searchUpwardLimit = max(0, Int(Double(height) * 0.10))
            var motionSplitY = probeStart
            for y in stride(from: probeStart, through: searchUpwardLimit, by: -4) {
                let yInA = y - dominantDisplacement
                guard yInA >= 0, yInA < height else {
                    motionSplitY = y
                    break
                }
                let diffMotion = abs(featB[y] - featA[yInA])
                if diffMotion > 0.08 {
                    motionSplitY = y
                    break
                }
            }
            
            if motionSplitY > 200 && CGFloat(motionSplitY) > finalTopAnchor {
                finalTopAnchor = CGFloat(motionSplitY)
            }
        }
        
        let isSplitMedia = finalTopAnchor > (CGFloat(height) * 0.18)
        
        return ScrollZoneDetectionResult(
            topAnchorHeight: finalTopAnchor,
            bottomAnchorHeight: bottomAnchor,
            isSplitScreenMedia: isSplitMedia,
            scrollVelocityEstimate: CGFloat(dominantDisplacement),
            confidence: max(0.5, probeConfidence)
        )
    }
    
    /// Detects repeating static top navigation bars and bottom bars (e.g. WeChat title bar, input box)
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
    
    /// Calculates optimal vertical overlap between topSlice and bottomSlice with explicit crops
    /// Returns offset in points, correlation confidence [0.0 ... 1.0], and optimal seam offset
    public static func findOverlap(
        topSlice: CGImage,
        bottomSlice: CGImage,
        topSliceTopCrop: CGFloat = 0,
        topSliceBottomCrop: CGFloat = 0,
        bottomSliceTopCrop: CGFloat = 0,
        bottomSliceBottomCrop: CGFloat = 0,
        templateHeightPt: CGFloat = 120,
        minOverlapRatio: CGFloat = 0.08,
        maxOverlapRatio: CGFloat = 0.88
    ) -> OverlapMatchResult {
        let width = topSlice.width
        let topHeight = topSlice.height
        let bottomHeight = bottomSlice.height
        
        guard width > 0, topHeight > 0, bottomHeight > 0 else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        // Convert vertical projections to 1D luminance and horizontal edge gradient energy profiles
        let topProfile = calculateVerticalProfile(cgImage: topSlice)
        let bottomProfile = calculateVerticalProfile(cgImage: bottomSlice)
        let topFeatures = topProfile.combinedFeature
        let bottomFeatures = bottomProfile.combinedFeature
        
        let validTopStart = Int(topSliceTopCrop)
        let validTopEnd = topHeight - Int(topSliceBottomCrop)
        guard validTopEnd > validTopStart + 100 else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        // Safety inset to prevent false-positive matching against identical static top status bars
        let statusSafetyInset = Int(CGFloat(topHeight) * 0.06)
        let templateSafetyInset = max(Int(bottomSliceTopCrop), Int(CGFloat(bottomHeight) * 0.06))
        let templateStart = templateSafetyInset
        let effectiveCropInBottom = templateStart - Int(bottomSliceTopCrop)
        
        let safeTopStart = max(validTopStart + effectiveCropInBottom, max(statusSafetyInset, Int(bottomSliceTopCrop) + effectiveCropInBottom))
        let templateLen = min(Int(templateHeightPt), bottomHeight - Int(bottomSliceBottomCrop) - templateStart)
        guard templateLen > 20 else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        let searchSpan = validTopEnd - safeTopStart - templateLen
        guard searchSpan > 10 else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        let minOffset = safeTopStart + Int(CGFloat(searchSpan) * minOverlapRatio)
        let maxOffset = min(validTopEnd - templateLen, safeTopStart + Int(CGFloat(searchSpan) * maxOverlapRatio))
        
        guard minOffset <= maxOffset else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        var bestOffset = minOffset
        var maxCorrelation: Double = -1.0
        let invTemplateLen = 1.0 / Double(templateLen)
        
        // Fast O(N) Prefix Sum Tables for S (topFeatures) and S^2
        var sumS = [Double](repeating: 0.0, count: topFeatures.count + 1)
        var sumSqS = [Double](repeating: 0.0, count: topFeatures.count + 1)
        for i in 0..<topFeatures.count {
            let v = topFeatures[i]
            sumS[i + 1] = sumS[i] + v
            sumSqS[i + 1] = sumSqS[i] + v * v
        }
        
        // Template statistical baseline
        var sumT = 0.0
        var sumSqT = 0.0
        for i in 0..<templateLen {
            let v = bottomFeatures[templateStart + i]
            sumT += v
            sumSqT += v * v
        }
        let varT = max(0.0, sumSqT - (sumT * sumT) * invTemplateLen)
        guard varT > 0.0001 else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        // Step 1: Hardware SIMD coarse search with stride 2 for real-time speed
        topFeatures.withUnsafeBufferPointer { topPtr in
            bottomFeatures.withUnsafeBufferPointer { botPtr in
                guard let topBase = topPtr.baseAddress,
                      let botBase = botPtr.baseAddress else { return }
                
                let tBase = botBase + templateStart
                
                for offset in stride(from: minOffset, through: maxOffset, by: 2) {
                    guard offset + templateLen <= validTopEnd else { break }
                    
                    let sSum = sumS[offset + templateLen] - sumS[offset]
                    let sSqSum = sumSqS[offset + templateLen] - sumSqS[offset]
                    let varS = max(0.0, sSqSum - (sSum * sSum) * invTemplateLen)
                    guard varS > 0.0001 else { continue }
                    
                    let sBase = topBase + offset
                    var dot = 0.0
                    
                    #if canImport(Accelerate)
                    vDSP_dotprD(sBase, 1, tBase, 1, &dot, vDSP_Length(templateLen))
                    #else
                    for i in 0..<templateLen {
                        dot += sBase[i] * tBase[i]
                    }
                    #endif
                    
                    let numerator = dot - (sSum * sumT) * invTemplateLen
                    let denominator = sqrt(varS * varT)
                    if denominator > 0.0001 {
                        let r = numerator / denominator
                        if r > maxCorrelation {
                            maxCorrelation = r
                            bestOffset = offset
                        }
                    }
                }
                
                // Step 2: 1-pixel fine search in [-2, +2] neighborhood of coarse peak
                // Eliminates single-pixel rounding drift for text rendering sharpness
                let fineStart = max(minOffset, bestOffset - 2)
                let fineEnd = min(maxOffset, bestOffset + 2)
                for fineOffset in fineStart...fineEnd {
                    guard fineOffset != bestOffset, fineOffset + templateLen <= validTopEnd else { continue }
                    let sSum = sumS[fineOffset + templateLen] - sumS[fineOffset]
                    let sSqSum = sumSqS[fineOffset + templateLen] - sumSqS[fineOffset]
                    let varS = max(0.0, sSqSum - (sSum * sSum) * invTemplateLen)
                    guard varS > 0.0001 else { continue }
                    
                    let sBase = topBase + fineOffset
                    var dot = 0.0
                    #if canImport(Accelerate)
                    vDSP_dotprD(sBase, 1, tBase, 1, &dot, vDSP_Length(templateLen))
                    #else
                    for i in 0..<templateLen {
                        dot += sBase[i] * tBase[i]
                    }
                    #endif
                    
                    let numerator = dot - (sSum * sumT) * invTemplateLen
                    let denominator = sqrt(varS * varT)
                    if denominator > 0.0001 {
                        let r = numerator / denominator
                        if r > maxCorrelation {
                            maxCorrelation = r
                            bestOffset = fineOffset
                        }
                    }
                }
            }
        }
        
        let normalizedConfidence = max(0.0, min(1.0, maxCorrelation))
        
        // Safety guard: if correlation is below noise threshold (0.20), these are non-continuous or dissimilar images.
        // Returning offset = 0 safely stacks them sequentially without clipping or mangling content.
        if normalizedConfidence < 0.20 {
            return OverlapMatchResult(
                offset: 0,
                confidence: normalizedConfidence,
                optimalSeamY: 0
            )
        }
        
        let topMatchY = bestOffset - effectiveCropInBottom
        let overlapHeight = max(0, validTopEnd - topMatchY)
        
        // Search for minimal energy seam across the valid overlap region
        let seamStart = max(topMatchY + 6, bestOffset + 2)
        let seamEnd = max(seamStart + 4, validTopEnd - 6)
        let optimalSeam = findMinimalEnergySeam(
            luminance: topProfile.luminance,
            horizontalEnergy: topProfile.horizontalEdgeEnergy,
            startRow: seamStart,
            endRow: seamEnd
        )
        
        let optimalSeamInBottom = (optimalSeam - bestOffset) + effectiveCropInBottom
        
        return OverlapMatchResult(
            offset: CGFloat(overlapHeight),
            confidence: normalizedConfidence,
            optimalSeamY: CGFloat(max(0, optimalSeamInBottom))
        )
    }
    
    /// Backward-compatible overload for existing call sites
    public static func findOverlap(
        topSlice: CGImage,
        bottomSlice: CGImage,
        topCropInset: CGFloat = 0,
        bottomCropInset: CGFloat = 0,
        templateHeightPt: CGFloat = 120,
        minOverlapRatio: CGFloat = 0.08,
        maxOverlapRatio: CGFloat = 0.88
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
            maxOverlapRatio: maxOverlapRatio
        )
    }
    
    // MARK: - 1D Vertical Luminance & Horizontal Edge Energy Profiling
    
    public static func calculateVerticalProfile(cgImage: CGImage) -> ImageProfile1D {
        let sampleWidth = 64
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
        
        let invScale = 1.0 / (Double(sampleWidth) * 255.0)
        let invGradScale = 1.0 / (Double(max(1, sampleWidth - 1)) * 255.0)
        
        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            var sumLum = Double(rawData[rowOffset])
            var sumGrad: Double = 0.0
            var prevVal = sumLum
            
            for x in 1..<sampleWidth {
                let val = Double(rawData[rowOffset + x])
                sumLum += val
                sumGrad += abs(val - prevVal)
                prevVal = val
            }
            
            let lum = sumLum * invScale
            let edge = sumGrad * invGradScale
            luminance[y] = lum
            edgeEnergy[y] = edge
            combinedFeature[y] = lum * 0.35 + edge * 0.65
        }
        return ImageProfile1D(luminance: luminance, horizontalEdgeEnergy: edgeEnergy, combinedFeature: combinedFeature)
    }
    
    public static func calculateVerticalLuminanceProfile(cgImage: CGImage) -> [Double] {
        return calculateVerticalProfile(cgImage: cgImage).luminance
    }
    
    // MARK: - Minimum Energy Seam Line Search (Gradient-Aware Blank Space Detection)
    
    private static func findMinimalEnergySeam(
        luminance: [Double],
        horizontalEnergy: [Double],
        startRow: Int,
        endRow: Int
    ) -> Int {
        guard startRow < endRow - 4,
              luminance.count > endRow,
              horizontalEnergy.count > endRow else {
            return (startRow + endRow) / 2
        }
        
        var minEnergy = Double.greatestFiniteMagnitude
        let midRow = (startRow + endRow) / 2
        var bestRow = midRow
        let windowLen = max(1.0, Double(endRow - startRow))
        
        for y in (startRow + 2)..<(endRow - 2) {
            // Horizontal edge energy: dense on text lines, near 0 in blank spacing between text lines
            let horizE = horizontalEnergy[y]
            // Vertical luminance gradient
            let vertE = abs(luminance[y + 1] - luminance[y - 1])
            // Center distance penalty: ensures wide blank margins choose their balanced center
            let centerDistPenalty = (abs(Double(y - midRow)) / windowLen) * 0.05
            
            let totalE = horizE * 0.70 + vertE * 0.25 + centerDistPenalty
            if totalE < minEnergy {
                minEnergy = totalE
                bestRow = y
            }
        }
        return bestRow
    }
}
