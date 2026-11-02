import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

public final class StitchEngine {
    public static let shared = StitchEngine()
    
    private let processingQueue = DispatchQueue(
        label: "com.scrollsnap.stitching.engine",
        qos: .userInitiated
    )
    
    private init() {
        // Strict concurrency rule: Zero synchronous singleton calls in init()
    }
    
    /// Aligns an array of slice file paths into an assembled StitchSession
    public func stitchSlices(
        fileRelativePaths: [String],
        source: StitchCaptureSource = .photoLibrary
    ) async throws -> StitchSession {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                guard !fileRelativePaths.isEmpty else {
                    continuation.resume(throwing: StitchError.emptySlices)
                    return
                }
                
                var items: [StitchItem] = []
                var previousCGImage: CGImage?
                
                for (index, path) in fileRelativePaths.enumerated() {
                    guard let fileURL = SharedStore.shared.resolveFileURL(relativePath: path),
                          let sourceData = try? Data(contentsOf: fileURL),
                          let uiImage = UIImage(data: sourceData),
                          let cgImage = uiImage.cgImage else {
                        continue
                    }
                    
                    let width = CGFloat(cgImage.width)
                    let height = CGFloat(cgImage.height)
                    
                    var overlapOffset: CGFloat = 0
                    var seamLineY: CGFloat = 0
                    
                    if let prev = previousCGImage, index > 0 {
                        let match = ImageOverlapDetector.findOverlap(
                            topSlice: prev,
                            bottomSlice: cgImage
                        )
                        overlapOffset = match.offset
                        seamLineY = match.optimalSeamY
                    }
                    
                    let item = StitchItem(
                        id: UUID(),
                        relativeFilePath: path,
                        originalWidth: width,
                        originalHeight: height,
                        calculatedOverlapWithPrevious: overlapOffset,
                        manualOffsetAdjustment: 0,
                        optimalSeamLineY: seamLineY,
                        redactions: [],
                        timestamp: Date()
                    )
                    items.append(item)
                    previousCGImage = cgImage
                }
                
                let session = StitchSession(
                    id: UUID(),
                    createdAt: Date(),
                    source: source,
                    slices: items,
                    title: "Stitched_\(Int(Date().timeIntervalSince1970))",
                    deviceScreenWidth: items.first?.originalWidth ?? 393,
                    deviceScreenScale: 3.0,
                    hasAppliedDeviceFrame: false
                )
                
                continuation.resume(returning: session)
            }
        }
    }
}
