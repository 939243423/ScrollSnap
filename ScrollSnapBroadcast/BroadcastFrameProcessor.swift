import Foundation
import CoreMedia
import CoreVideo
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

public final class BroadcastFrameProcessor {
    private var sliceCounter = 0
    private var lastLuminanceProjection: [Double] = []
    private var lastProcessedTimestamp: TimeInterval = 0
    private let minimumFrameInterval: TimeInterval = 0.10 // Limit processing to 10 FPS
    
    public init() {}
    
    public func process(pixelBuffer: CVPixelBuffer) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastProcessedTimestamp >= minimumFrameInterval else {
            return
        }
        lastProcessedTimestamp = now
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0 else { return }
        
        // Fast downsampled vertical 1D projection to estimate scrolling delta
        let currentProjection = extractDownsampledProjection(pixelBuffer: pixelBuffer, width: width, height: height)
        
        if lastLuminanceProjection.isEmpty {
            // First keyframe of session
            lastLuminanceProjection = currentProjection
            saveKeyframe(pixelBuffer: pixelBuffer)
            return
        }
        
        let motionDelta = calculateEuclideanDelta(lastLuminanceProjection, currentProjection)
        
        // Anti-jitter: ignore stationary frames (< 0.035) and erratic jumps (> 0.85)
        if motionDelta >= 0.035 && motionDelta <= 0.85 {
            lastLuminanceProjection = currentProjection
            saveKeyframe(pixelBuffer: pixelBuffer)
        }
    }
    
    public func finalizeSession() {
        lastLuminanceProjection.removeAll()
        sliceCounter = 0
    }
    
    // MARK: - Downsampled Projection (Resident RAM < 180KB)
    
    private func extractDownsampledProjection(pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> [Double] {
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return [] }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        let stepY = max(1, height / 128)
        let sampleCountY = height / stepY
        var projection = [Double](repeating: 0.0, count: sampleCountY)
        
        let sampleCols = [width / 4, width / 2, (3 * width) / 4]
        
        for (idx, y) in stride(from: 0, to: height, by: stepY).enumerated() {
            guard idx < sampleCountY else { break }
            var rowSum = 0.0
            let rowOffset = y * bytesPerRow
            for x in sampleCols {
                let pixelOffset = rowOffset + x * 4
                let b = Double(buffer[pixelOffset])
                let g = Double(buffer[pixelOffset + 1])
                let r = Double(buffer[pixelOffset + 2])
                rowSum += (0.299 * r + 0.587 * g + 0.114 * b)
            }
            projection[idx] = rowSum / Double(sampleCols.count * 255)
        }
        return projection
    }
    
    private func calculateEuclideanDelta(_ p1: [Double], _ p2: [Double]) -> Double {
        let count = min(p1.count, p2.count)
        guard count > 0 else { return 0 }
        var sumSquares = 0.0
        for i in 0..<count {
            let diff = p1[i] - p2[i]
            sumSquares += diff * diff
        }
        return sqrt(sumSquares / Double(count))
    }
    
    // MARK: - Immediate Disk Flush (50MB Jetsam Guard)
    
    private func saveKeyframe(pixelBuffer: CVPixelBuffer) {
        #if canImport(UIKit)
        autoreleasepool {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext(options: [.useSoftwareRenderer: false])
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            let uiImage = UIImage(cgImage: cgImage)
            
            // Compress with 0.85 quality to keep disk IO fast and minimal
            guard let jpegData = uiImage.jpegData(compressionQuality: 0.85) else { return }
            
            if let _ = SharedStore.shared.writeBroadcastSlice(data: jpegData, index: sliceCounter) {
                sliceCounter += 1
                CrossProcessNotifier.post(name: AppGroupConstants.notificationSessionUpdated)
            }
        }
        #endif
    }
}
