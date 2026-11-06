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
        
        // Step 1: Detect dominant scroll displacement in lower-middle body
        // Multi-point probe candidates (55%, 68%, 45%, 75%) guarantee locking onto active scrolling content
        // even on sparse chat records or pages with large blank gaps
        let candidateRatios: [Double] = [0.55, 0.68, 0.45, 0.75]
        let probeLen = min(140, Int(Double(height) * 0.12))
        var dominantDisplacement: Int = 0
        var probeConfidence: Double = 0.0
        var activeProbeStart: Int = Int(Double(height) * 0.55)
        
        let invT = 1.0 / Double(probeLen)
        let searchMin = Int(Double(height) * 0.12)
        let searchMax = min(height - probeLen, Int(Double(height) * 0.88))
        
        for ratio in candidateRatios {
            let pStart = Int(Double(height) * ratio)
            guard pStart + probeLen < height - 50 else { continue }
            
            let template = Array(featB[pStart..<(pStart + probeLen)])
            var sumT = 0.0
            var sumSqT = 0.0
            for v in template {
                sumT += v
                sumSqT += v * v
            }
            let varT = max(0.0, sumSqT - (sumT * sumT) * invT)
            guard varT > 0.0001 else { continue }
            
            var bestOffset = pStart
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
            
            let candConf = max(0.0, min(1.0, maxR))
            if candConf > probeConfidence {
                probeConfidence = candConf
                dominantDisplacement = pStart - bestOffset
                activeProbeStart = pStart
                if candConf > 0.65 {
                    break
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
        if dominantDisplacement > 30 && probeConfidence > 0.35 {
            let searchUpwardLimit = max(0, Int(Double(height) * 0.08))
            var motionSplitY = activeProbeStart
            for y in stride(from: activeProbeStart, through: searchUpwardLimit, by: -4) {
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
            
            if motionSplitY > 160 && CGFloat(motionSplitY) > finalTopAnchor {
                finalTopAnchor = CGFloat(motionSplitY)
            }
        }
        
        let isSplitMedia = finalTopAnchor > (CGFloat(height) * 0.18)
        
        // Step 5: Divider line snapping for split-screen media (Xiaohongshu video notes, Bilibili)
        // Snaps the cut right below the physical divider edge so neither slice clips the divider line
        if isSplitMedia {
            let snapStart = max(40, Int(finalTopAnchor) - 16)
            let snapEnd = min(height - 100, Int(finalTopAnchor) + 16)
            var maxDividerE = 0.0
            var snapRow = Int(finalTopAnchor)
            for y in snapStart...snapEnd {
                let e = profileTop.horizontalEdgeEnergy[y]
                if e > maxDividerE {
                    maxDividerE = e
                    snapRow = y
                }
            }
            if maxDividerE > 0.08 {
                finalTopAnchor = CGFloat(snapRow + 1)
            }
        }
        
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
    
    // MARK: - Template Band Cross-Correlation Helper
    
    private static func matchTemplateBand(
        topBase: UnsafePointer<Double>,
        botBase: UnsafePointer<Double>,
        sumS: [Double],
        sumSqS: [Double],
        validTopEnd: Int,
        templateStart: Int,
        templateLen: Int,
        minOffset: Int,
        maxOffset: Int
    ) -> (bestOffset: Int, maxCorrelation: Double) {
        guard templateLen > 20, minOffset <= maxOffset, minOffset >= 0 else {
            return (minOffset, -1.0)
        }
        let invTemplateLen = 1.0 / Double(templateLen)
        let tBase = botBase + templateStart
        
        var sumT = 0.0
        var sumSqT = 0.0
        for i in 0..<templateLen {
            let v = tBase[i]
            sumT += v
            sumSqT += v * v
        }
        let varT = max(0.0, sumSqT - (sumT * sumT) * invTemplateLen)
        guard varT > 0.0001 else {
            return (minOffset, -1.0)
        }
        
        var bestOffset = minOffset
        var maxCorrelation: Double = -1.0
        
        // Step 1: Coarse search with stride 2
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
            
            let num = dot - (sSum * sumT) * invTemplateLen
            let denom = sqrt(varS * varT)
            if denom > 0.0001 {
                let r = num / denom
                if r > maxCorrelation {
                    maxCorrelation = r
                    bestOffset = offset
                }
            }
        }
        
        // Step 2: 1-pixel fine search in [-2, +2] neighborhood of peak
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
            
            let num = dot - (sSum * sumT) * invTemplateLen
            let denom = sqrt(varS * varT)
            if denom > 0.0001 {
                let r = num / denom
                if r > maxCorrelation {
                    maxCorrelation = r
                    bestOffset = fineOffset
                }
            }
        }
        
        return (bestOffset, maxCorrelation)
    }
    
    /// Calculates optimal vertical overlap with multi-band consensus voting and sub-pixel peak refinement
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
        
        // Fast O(N) Prefix Sum Tables for S (topFeatures) and S^2
        var sumS = [Double](repeating: 0.0, count: topFeatures.count + 1)
        var sumSqS = [Double](repeating: 0.0, count: topFeatures.count + 1)
        for i in 0..<topFeatures.count {
            let v = topFeatures[i]
            sumS[i + 1] = sumS[i] + v
            sumSqS[i + 1] = sumSqS[i] + v * v
        }
        
        // Multi-Band Spatial Consensus:
        // Evaluates 3 distinct vertical bands in bottomSlice to outvote sticky date headers and floating widgets
        var candidateBands: [(impliedDy: Int, correlation: Double, bestOffset: Int)] = []
        
        topFeatures.withUnsafeBufferPointer { topPtr in
            bottomFeatures.withUnsafeBufferPointer { botPtr in
                guard let topBase = topPtr.baseAddress,
                      let botBase = botPtr.baseAddress else { return }
                
                // Band 1: Primary template at top of scroll zone
                let match1 = matchTemplateBand(
                    topBase: topBase,
                    botBase: botBase,
                    sumS: sumS,
                    sumSqS: sumSqS,
                    validTopEnd: validTopEnd,
                    templateStart: templateStart,
                    templateLen: templateLen,
                    minOffset: minOffset,
                    maxOffset: maxOffset
                )
                if match1.maxCorrelation > 0.20 {
                    candidateBands.append((
                        impliedDy: match1.bestOffset - templateStart,
                        correlation: match1.maxCorrelation,
                        bestOffset: match1.bestOffset
                    ))
                }
                
                let activeBottomSpan = (bottomHeight - Int(bottomSliceBottomCrop)) - templateStart
                
                // Band 2: Middle band
                if activeBottomSpan >= 140 {
                    let band2Start = templateStart + Int(Double(activeBottomSpan) * 0.32)
                    let band2Delta = band2Start - templateStart
                    let minOff2 = max(validTopStart, minOffset + band2Delta)
                    let maxOff2 = min(validTopEnd - templateLen, maxOffset + band2Delta)
                    if band2Start + templateLen <= bottomHeight - Int(bottomSliceBottomCrop) && minOff2 <= maxOff2 {
                        let match2 = matchTemplateBand(
                            topBase: topBase,
                            botBase: botBase,
                            sumS: sumS,
                            sumSqS: sumSqS,
                            validTopEnd: validTopEnd,
                            templateStart: band2Start,
                            templateLen: templateLen,
                            minOffset: minOff2,
                            maxOffset: maxOff2
                        )
                        if match2.maxCorrelation > 0.20 {
                            candidateBands.append((
                                impliedDy: match2.bestOffset - band2Start,
                                correlation: match2.maxCorrelation,
                                bestOffset: match2.bestOffset
                            ))
                        }
                    }
                }
                
                // Band 3: Lower band
                if activeBottomSpan >= 260 {
                    let band3Start = templateStart + Int(Double(activeBottomSpan) * 0.60)
                    let band3Delta = band3Start - templateStart
                    let minOff3 = max(validTopStart, minOffset + band3Delta)
                    let maxOff3 = min(validTopEnd - templateLen, maxOffset + band3Delta)
                    if band3Start + templateLen <= bottomHeight - Int(bottomSliceBottomCrop) && minOff3 <= maxOff3 {
                        let match3 = matchTemplateBand(
                            topBase: topBase,
                            botBase: botBase,
                            sumS: sumS,
                            sumSqS: sumSqS,
                            validTopEnd: validTopEnd,
                            templateStart: band3Start,
                            templateLen: templateLen,
                            minOffset: minOff3,
                            maxOffset: maxOff3
                        )
                        if match3.maxCorrelation > 0.20 {
                            candidateBands.append((
                                impliedDy: match3.bestOffset - band3Start,
                                correlation: match3.maxCorrelation,
                                bestOffset: match3.bestOffset
                            ))
                        }
                    }
                }
            }
        }
        
        // Multi-Band Consensus Selection
        guard !candidateBands.isEmpty else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        var consensusDy: Int = candidateBands[0].impliedDy
        var consensusConf: Double = candidateBands[0].correlation
        var foundPairwiseAgreement = false
        
        if candidateBands.count >= 2 {
            for i in 0..<candidateBands.count {
                for j in (i + 1)..<candidateBands.count {
                    if abs(candidateBands[i].impliedDy - candidateBands[j].impliedDy) <= 2 {
                        consensusDy = candidateBands[i].impliedDy
                        consensusConf = min(1.0, max(candidateBands[i].correlation, candidateBands[j].correlation) + 0.05)
                        foundPairwiseAgreement = true
                        
                        for k in 0..<candidateBands.count {
                            if k != i && k != j && abs(candidateBands[k].impliedDy - consensusDy) <= 2 {
                                consensusConf = min(1.0, consensusConf + 0.03)
                            }
                        }
                        break
                    }
                }
                if foundPairwiseAgreement { break }
            }
        }
        
        if !foundPairwiseAgreement {
            if let bestBand = candidateBands.max(by: { $0.correlation < $1.correlation }) {
                consensusDy = bestBand.impliedDy
                consensusConf = bestBand.correlation
            }
        }
        
        let bestOffset = templateStart + consensusDy
        guard bestOffset >= validTopStart && bestOffset + templateLen <= validTopEnd else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        let normalizedConfidence = max(0.0, min(1.0, consensusConf))
        
        // Safety guard: if correlation is below noise threshold (0.20), these are non-continuous or dissimilar images.
        if normalizedConfidence < 0.20 {
            return OverlapMatchResult(
                offset: 0,
                confidence: normalizedConfidence,
                optimalSeamY: 0
            )
        }
        
        let topMatchY = bestOffset - effectiveCropInBottom
        let overlapHeight = max(0, validTopEnd - topMatchY)
        
        // Search for minimal energy seam with 5-tap moving window valley centering
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
        
        // Exclude outer 2% on left and 5% on right (eliminating scroll bar indicator & bezel flicker)
        let safeLeft = max(1, Int(Double(sampleWidth) * 0.02))
        let safeRight = min(sampleWidth - 1, Int(Double(sampleWidth) * 0.95))
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
    
    // MARK: - Minimum Energy Seam Line Search (5-Tap Moving Window Valley Centering)
    
    private static func findMinimalEnergySeam(
        luminance: [Double],
        horizontalEnergy: [Double],
        startRow: Int,
        endRow: Int
    ) -> Int {
        guard startRow < endRow - 6,
              luminance.count > endRow,
              horizontalEnergy.count > endRow else {
            return (startRow + endRow) / 2
        }
        
        let midRow = (startRow + endRow) / 2
        let windowLen = max(1.0, Double(endRow - startRow))
        
        var minSmoothedEnergy = Double.greatestFiniteMagnitude
        var bestRow = midRow
        
        for y in (startRow + 3)..<(endRow - 3) {
            var sumNeighborhoodE = 0.0
            for k in -2...2 {
                let row = y + k
                let hE = horizontalEnergy[row]
                let vE = abs(luminance[row + 1] - luminance[row - 1])
                sumNeighborhoodE += (hE * 0.70 + vE * 0.25)
            }
            let avgE = sumNeighborhoodE * 0.20
            
            // Center distance penalty: ensures wide blank margins choose their balanced center
            let centerDistPenalty = (abs(Double(y - midRow)) / windowLen) * 0.04
            let totalE = avgE + centerDistPenalty
            
            if totalE < minSmoothedEnergy {
                minSmoothedEnergy = totalE
                bestRow = y
            }
        }
        return bestRow
    }
}
