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

public struct ImageProfile1D {
    public let luminance: [Double]
    public let horizontalEdgeEnergy: [Double]
    
    public init(luminance: [Double], horizontalEdgeEnergy: [Double]) {
        self.luminance = luminance
        self.horizontalEdgeEnergy = horizontalEdgeEnergy
    }
}

public final class ImageOverlapDetector {
    
    /// Detects repeating static top navigation bars and bottom bars (e.g. WeChat title bar, input box)
    public static func detectStaticChromeRegions(
        topImage: CGImage,
        bottomImage: CGImage
    ) -> StaticChromeDetectionResult {
        let width = min(topImage.width, bottomImage.width)
        let height = min(topImage.height, bottomImage.height)
        guard width > 0, height > 400 else {
            return StaticChromeDetectionResult(topBarHeight: 0, bottomBarHeight: 0)
        }
        
        let profileTopA = calculateVerticalLuminanceProfile(cgImage: topImage)
        let profileTopB = calculateVerticalLuminanceProfile(cgImage: bottomImage)
        
        // Scan top region (typically status bar + nav bar = 120 ~ 280 px on 3x retina)
        var detectedTop: Int = 0
        let maxTopScan = min(320, height / 4)
        for y in 0..<maxTopScan {
            if abs(profileTopA[y] - profileTopB[y]) < 0.025 {
                detectedTop = y
            } else if y > 80 {
                // Once variance appears after initial safe area, terminate top scan
                break
            }
        }
        
        // Scan bottom region (typically home indicator + tab/input bar = 100 ~ 260 px)
        var detectedBottom: Int = 0
        let maxBottomScan = min(280, height / 4)
        for i in 0..<maxBottomScan {
            let yA = topImage.height - 1 - i
            let yB = bottomImage.height - 1 - i
            guard yA >= 0, yB >= 0 else { break }
            if abs(profileTopA[yA] - profileTopB[yB]) < 0.025 {
                detectedBottom = i
            } else if i > 60 {
                break
            }
        }
        
        return StaticChromeDetectionResult(
            topBarHeight: CGFloat(detectedTop > 50 ? detectedTop : 0),
            bottomBarHeight: CGFloat(detectedBottom > 40 ? detectedBottom : 0)
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
        minOverlapRatio: CGFloat = 0.02,
        maxOverlapRatio: CGFloat = 0.98
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
        let topLuminance = topProfile.luminance
        let bottomLuminance = bottomProfile.luminance
        
        let validTopStart = Int(topSliceTopCrop)
        let validTopEnd = topHeight - Int(topSliceBottomCrop)
        guard validTopEnd > validTopStart + 100 else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        let minOffset = validTopStart + Int(CGFloat(validTopEnd - validTopStart) * minOverlapRatio)
        let maxOffset = min(validTopEnd - Int(templateHeightPt), validTopStart + Int(CGFloat(validTopEnd - validTopStart) * maxOverlapRatio))
        
        guard minOffset < maxOffset else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        var bestOffset = minOffset
        var maxCorrelation: Double = -1.0
        let templateLen = min(Int(templateHeightPt), bottomHeight - Int(bottomSliceBottomCrop) - Int(bottomSliceTopCrop))
        guard templateLen > 20 else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        let templateStart = Int(bottomSliceTopCrop)
        let invTemplateLen = 1.0 / Double(templateLen)
        
        // Fast O(N) Prefix Sum Tables for S (topLuminance) and S^2
        var sumS = [Double](repeating: 0.0, count: topLuminance.count + 1)
        var sumSqS = [Double](repeating: 0.0, count: topLuminance.count + 1)
        for i in 0..<topLuminance.count {
            let v = topLuminance[i]
            sumS[i + 1] = sumS[i] + v
            sumSqS[i + 1] = sumSqS[i] + v * v
        }
        
        // Template statistical baseline
        var sumT = 0.0
        var sumSqT = 0.0
        for i in 0..<templateLen {
            let v = bottomLuminance[templateStart + i]
            sumT += v
            sumSqT += v * v
        }
        let varT = max(0.0, sumSqT - (sumT * sumT) * invTemplateLen)
        guard varT > 0.0001 else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        // Step 1: Hardware SIMD coarse search with stride 2 for real-time speed
        topLuminance.withUnsafeBufferPointer { topPtr in
            bottomLuminance.withUnsafeBufferPointer { botPtr in
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
        
        let overlapHeight = validTopEnd - bestOffset
        let optimalSeam = findMinimalEnergySeam(
            luminance: topLuminance,
            horizontalEnergy: topProfile.horizontalEdgeEnergy,
            startRow: bestOffset,
            endRow: min(validTopEnd, bestOffset + overlapHeight)
        )
        
        return OverlapMatchResult(
            offset: CGFloat(overlapHeight),
            confidence: normalizedConfidence,
            optimalSeamY: CGFloat(optimalSeam - bestOffset)
        )
    }
    
    /// Backward-compatible overload for existing call sites
    public static func findOverlap(
        topSlice: CGImage,
        bottomSlice: CGImage,
        topCropInset: CGFloat = 0,
        bottomCropInset: CGFloat = 0,
        templateHeightPt: CGFloat = 120,
        minOverlapRatio: CGFloat = 0.02,
        maxOverlapRatio: CGFloat = 0.98
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
            return ImageProfile1D(luminance: luminance, horizontalEdgeEnergy: edgeEnergy)
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
            
            luminance[y] = sumLum * invScale
            edgeEnergy[y] = sumGrad * invGradScale
        }
        return ImageProfile1D(luminance: luminance, horizontalEdgeEnergy: edgeEnergy)
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
