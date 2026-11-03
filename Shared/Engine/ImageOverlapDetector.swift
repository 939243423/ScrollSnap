import Foundation
import CoreGraphics

public struct OverlapMatchResult {
    public let offset: CGFloat
    public let confidence: Double
    public let optimalSeamY: CGFloat
}

public struct StaticChromeDetectionResult {
    public let topBarHeight: CGFloat
    public let bottomBarHeight: CGFloat
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
    
    /// Calculates optimal vertical overlap between topSlice and bottomSlice
    /// Returns offset in points and correlation confidence [0.0 ... 1.0]
    public static func findOverlap(
        topSlice: CGImage,
        bottomSlice: CGImage,
        topCropInset: CGFloat = 0,
        bottomCropInset: CGFloat = 0,
        templateHeightPt: CGFloat = 120,
        minOverlapRatio: CGFloat = 0.10,
        maxOverlapRatio: CGFloat = 0.90
    ) -> OverlapMatchResult {
        let width = topSlice.width
        let topHeight = topSlice.height
        let bottomHeight = bottomSlice.height
        
        guard width > 0, topHeight > 0, bottomHeight > 0 else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        // Convert vertical projections to 1D luminance arrays
        let topLuminance = calculateVerticalLuminanceProfile(cgImage: topSlice)
        let bottomLuminance = calculateVerticalLuminanceProfile(cgImage: bottomSlice)
        
        let validTopStart = Int(topCropInset)
        let validTopEnd = topHeight - Int(bottomCropInset)
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
        let templateLen = min(Int(templateHeightPt), bottomHeight - Int(topCropInset))
        guard templateLen > 20 else {
            return OverlapMatchResult(offset: 0, confidence: 0, optimalSeamY: 0)
        }
        
        // Extract template from bottomSlice immediately below its top crop inset
        let templateStart = Int(topCropInset)
        let template = Array(bottomLuminance[templateStart..<(templateStart + templateLen)])
        let meanT = template.reduce(0.0, +) / Double(templateLen)
        var varT: Double = 0.0
        for val in template {
            let diff = val - meanT
            varT += diff * diff
        }
        
        // Slide template along search window of topSlice
        for offset in stride(from: minOffset, through: maxOffset, by: 2) {
            guard offset + templateLen <= validTopEnd else { break }
            let sub = Array(topLuminance[offset..<(offset + templateLen)])
            let meanS = sub.reduce(0.0, +) / Double(templateLen)
            
            var numerator: Double = 0.0
            var varS: Double = 0.0
            for i in 0..<templateLen {
                let diffS = sub[i] - meanS
                let diffT = template[i] - meanT
                numerator += diffS * diffT
                varS += diffS * diffS
            }
            
            let denominator = sqrt(varS * varT)
            if denominator > 0.0001 {
                let r = numerator / denominator
                if r > maxCorrelation {
                    maxCorrelation = r
                    bestOffset = offset
                }
            }
        }
        
        let overlapHeight = validTopEnd - bestOffset
        let optimalSeam = findMinimalEnergySeam(
            luminanceProfile: topLuminance,
            startRow: bestOffset,
            endRow: min(validTopEnd, bestOffset + overlapHeight)
        )
        
        let normalizedConfidence = max(0.0, min(1.0, maxCorrelation))
        return OverlapMatchResult(
            offset: CGFloat(overlapHeight),
            confidence: normalizedConfidence,
            optimalSeamY: CGFloat(optimalSeam - bestOffset)
        )
    }
    
    // MARK: - 1D Vertical Luminance Profiling (Hardware Accelerated Grayscale Downsampling)
    
    private static func calculateVerticalLuminanceProfile(cgImage: CGImage) -> [Double] {
        let sampleWidth = 64
        let height = cgImage.height
        var profile = [Double](repeating: 0.0, count: height)
        
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
            return profile
        }
        
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: height))
        
        let invScale = 1.0 / Double(sampleWidth * 255.0)
        for y in 0..<height {
            var sumLuminance: Double = 0.0
            let rowOffset = y * bytesPerRow
            for x in 0..<sampleWidth {
                sumLuminance += Double(rawData[rowOffset + x])
            }
            profile[y] = sumLuminance * invScale
        }
        return profile
    }
    
    // MARK: - Minimum Energy Seam Line Search
    
    private static func findMinimalEnergySeam(luminanceProfile: [Double], startRow: Int, endRow: Int) -> Int {
        guard startRow < endRow - 4, luminanceProfile.count > endRow else {
            return (startRow + endRow) / 2
        }
        
        var minGradient = Double.greatestFiniteMagnitude
        var bestRow = (startRow + endRow) / 2
        
        for y in (startRow + 2)..<(endRow - 2) {
            let grad = abs(luminanceProfile[y + 1] - luminanceProfile[y - 1])
            if grad < minGradient {
                minGradient = grad
                bestRow = y
            }
        }
        return bestRow
    }
}
