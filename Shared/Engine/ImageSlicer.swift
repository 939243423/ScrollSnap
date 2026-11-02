import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
import Photos
#endif

public final class ImageSlicer: Sendable {
    public static let shared = ImageSlicer()
    
    private init() {}
    
    public enum SlicePreset: Int, CaseIterable, Identifiable {
        case three = 3
        case four = 4
        case six = 6
        case nine = 9
        
        public var id: Int { rawValue }
        
        public var title: String {
            switch self {
            case .three: return "3 联排切片"
            case .four: return "4 宫格切片"
            case .six: return "6 宫格切片"
            case .nine: return "9 宫格图文"
            }
        }
        
        public var description: String {
            switch self {
            case .three: return "适合微信公众号长图拆解"
            case .four: return "适合微博/小红书图文并茂"
            case .six: return "适合知乎长回答切片"
            case .nine: return "小红书爆款 9 宫格首选"
            }
        }
    }
    
    #if canImport(UIKit)
    /// Slices a long stitched image into intelligent text-safe segments.
    public func sliceImage(
        image: UIImage,
        count: Int,
        searchPadding: CGFloat = 36.0
    ) -> [UIImage] {
        guard let cgImage = image.cgImage, count > 1 else {
            return [image]
        }
        
        let totalWidth = CGFloat(cgImage.width)
        let totalHeight = CGFloat(cgImage.height)
        guard totalHeight > CGFloat(count * 50) else {
            return [image]
        }
        
        // Find optimal split lines
        var cutYs: [CGFloat] = [0]
        let naiveSegmentHeight = totalHeight / CGFloat(count)
        
        for i in 1..<count {
            let naiveY = naiveSegmentHeight * CGFloat(i)
            let safeY = findTextGapNear(cgImage: cgImage, targetY: naiveY, searchRadius: searchPadding)
            cutYs.append(safeY)
        }
        cutYs.append(totalHeight)
        
        var slices: [UIImage] = []
        for i in 0..<count {
            let startY = cutYs[i]
            let endY = cutYs[i + 1]
            let sliceHeight = max(1, endY - startY)
            
            let cropRect = CGRect(x: 0, y: startY, width: totalWidth, height: sliceHeight)
            if let croppedCG = cgImage.cropping(to: cropRect) {
                slices.append(UIImage(cgImage: croppedCG, scale: image.scale, orientation: image.imageOrientation))
            }
        }
        
        return slices
    }
    
    /// Finds a blank whitespace row near targetY to avoid cutting characters in half
    private func findTextGapNear(cgImage: CGImage, targetY: CGFloat, searchRadius: CGFloat) -> CGFloat {
        let minY = max(0, Int(targetY - searchRadius))
        let maxY = min(cgImage.height - 1, Int(targetY + searchRadius))
        guard maxY > minY else { return targetY }
        
        // Downsample width to 32 samples across the row for rapid energy scanning
        let sampleWidth = 32
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: sampleWidth,
            height: maxY - minY,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return targetY
        }
        
        let sampleRect = CGRect(x: 0, y: -minY, width: sampleWidth, height: cgImage.height)
        context.interpolationQuality = .low
        context.draw(cgImage, in: sampleRect)
        
        guard let pixelData = context.data else { return targetY }
        let buffer = pixelData.bindMemory(to: UInt8.self, capacity: sampleWidth * (maxY - minY))
        
        var bestRow = Int(targetY)
        var minRowVariance = Double.greatestFiniteMagnitude
        
        for localRow in 0..<(maxY - minY) {
            let offset = localRow * sampleWidth
            var sum = 0
            var sumSquares = 0
            for col in 0..<sampleWidth {
                let val = Int(buffer[offset + col])
                sum += val
                sumSquares += val * val
            }
            let mean = Double(sum) / Double(sampleWidth)
            let variance = (Double(sumSquares) / Double(sampleWidth)) - (mean * mean)
            
            if variance < minRowVariance {
                minRowVariance = variance
                bestRow = minY + localRow
            }
        }
        
        return CGFloat(bestRow)
    }
    
    /// Batch saves slices into the iOS photo library
    public func saveSlicesToAlbum(slices: [UIImage]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            for slice in slices {
                PHAssetChangeRequest.creationRequestForAsset(from: slice)
            }
        }
    }
    #endif
}
