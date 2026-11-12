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
    private var lastSavedProjection: [Double] = []
    private var pendingFinalData: Data? = nil
    private var lastProcessedTimestamp: TimeInterval = 0
    private let minimumFrameInterval: TimeInterval = 0.08 // Limit processing to 12.5 FPS for seamless scroll overlap
    
    #if canImport(UIKit)
    private lazy var ciContext: CIContext = {
        CIContext(options: [.useSoftwareRenderer: false])
    }()
    #endif
    
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
            lastSavedProjection = currentProjection
            saveKeyframe(pixelBuffer: pixelBuffer)
            return
        }
        
        let motionDelta = calculateEuclideanDelta(lastLuminanceProjection, currentProjection)
        
        // Anti-jitter: ignore true stationary pauses (< 0.012) and erratic jumps (> 0.85)
        // Lowered from 0.035 to 0.012 to capture slow/sparse chat scrolling (e.g. WeChat text with large background)
        if motionDelta >= 0.012 && motionDelta <= 0.85 {
            lastLuminanceProjection = currentProjection
            lastSavedProjection = currentProjection
            pendingFinalData = nil
            saveKeyframe(pixelBuffer: pixelBuffer)
        } else if motionDelta < 0.012 && !lastSavedProjection.isEmpty {
            // If subtle movement occurred since last saved keyframe, cache ending frame so bottom is never lost
            let deltaFromLastSave = calculateEuclideanDelta(lastSavedProjection, currentProjection)
            if deltaFromLastSave >= 0.008 {
                autoreleasepool {
                    #if canImport(UIKit)
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                        let uiImage = UIImage(cgImage: cgImage)
                        pendingFinalData = uiImage.jpegData(compressionQuality: 0.85)
                    }
                    #endif
                }
            }
        }
    }
    
    public func finalizeSession() {
        #if canImport(UIKit)
        if let pending = pendingFinalData {
            if let _ = SharedStore.shared.writeBroadcastSlice(data: pending, index: sliceCounter) {
                sliceCounter += 1
            }
        }
        #endif
        pendingFinalData = nil
        lastSavedProjection.removeAll()
        lastLuminanceProjection.removeAll()
        sliceCounter = 0
    }
    
    // MARK: - Downsampled Projection (Resident RAM < 180KB, Supports Both Planar NV12 & Packed BGRA)
    
    private func extractDownsampledProjection(pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> [Double] {
        let isPlanar = CVPixelBufferIsPlanar(pixelBuffer)
        let baseAddress: UnsafeMutableRawPointer?
        let bytesPerRow: Int
        
        if isPlanar {
            // ReplayKit on iOS typically outputs NV12 (Planar): Plane 0 is pure Luminance (Y)
            baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
            bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        } else {
            // Packed 32BGRA
            baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
            bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        }
        
        guard let baseAddress = baseAddress else { return [] }
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        let stepY = max(1, height / 128)
        let sampleCountY = height / stepY
        var projection = [Double](repeating: 0.0, count: sampleCountY)
        
        // Sample 16 columns spanning from 0.06W to 0.94W to capture left avatars (x ~ 0.08W),
        // right avatars (x ~ 0.92W), and sparse text bubbles across the chat screen.
        let colCount = 16
        let minX = max(0, Int(Double(width) * 0.06))
        let maxX = min(width - 1, Int(Double(width) * 0.94))
        let colStep = Double(maxX - minX) / Double(max(1, colCount - 1))
        var sampleCols = [Int](repeating: 0, count: colCount)
        for i in 0..<colCount {
            sampleCols[i] = minX + Int(round(Double(i) * colStep))
        }
        
        for (idx, y) in stride(from: 0, to: height, by: stepY).enumerated() {
            guard idx < sampleCountY else { break }
            var rowSum = 0.0
            let rowOffset = y * bytesPerRow
            
            if isPlanar {
                // Direct 8-bit Luminance (Y) read
                for x in sampleCols {
                    let yVal = Double(buffer[rowOffset + x])
                    rowSum += yVal
                }
                projection[idx] = rowSum / (Double(sampleCols.count) * 255.0)
            } else {
                // 32BGRA packed decode
                for x in sampleCols {
                    let pixelOffset = rowOffset + x * 4
                    let b = Double(buffer[pixelOffset])
                    let g = Double(buffer[pixelOffset + 1])
                    let r = Double(buffer[pixelOffset + 2])
                    rowSum += (0.299 * r + 0.587 * g + 0.114 * b)
                }
                projection[idx] = rowSum / (Double(sampleCols.count) * 255.0)
            }
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
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
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
