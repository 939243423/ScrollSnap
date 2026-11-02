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
        // Concurrency safety: Zero synchronous singleton calls in init()
    }
    
    /// Aligns an array of slice file paths into an assembled StitchSession
    public func stitchSlices(
        fileRelativePaths: [String],
        source: StitchCaptureSource = .photoLibrary,
        presetMode: StitchPresetMode = .chatRecord
    ) async throws -> StitchSession {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                guard !fileRelativePaths.isEmpty else {
                    continuation.resume(throwing: StitchError.emptySlices)
                    return
                }
                
                var cgImages: [CGImage] = []
                for path in fileRelativePaths {
                    guard let fileURL = SharedStore.shared.resolveFileURL(relativePath: path),
                          let sourceData = try? Data(contentsOf: fileURL),
                          let uiImage = UIImage(data: sourceData),
                          let cgImage = uiImage.cgImage else {
                        continue
                    }
                    cgImages.append(cgImage)
                }
                
                guard !cgImages.isEmpty else {
                    continuation.resume(throwing: StitchError.emptySlices)
                    return
                }
                
                // Detect static navigation bar and bottom bar height from first two slices
                var detectedTopBar: CGFloat = 0
                var detectedBottomBar: CGFloat = 0
                if cgImages.count >= 2 {
                    let chrome = ImageOverlapDetector.detectStaticChromeRegions(
                        topImage: cgImages[0],
                        bottomImage: cgImages[1]
                    )
                    detectedTopBar = chrome.topBarHeight
                    detectedBottomBar = chrome.bottomBarHeight
                }
                
                var items: [StitchItem] = []
                let totalCount = cgImages.count
                
                for (index, cgImage) in cgImages.enumerated() {
                    let width = CGFloat(cgImage.width)
                    let height = CGFloat(cgImage.height)
                    let path = fileRelativePaths[index]
                    
                    var topCrop: CGFloat = 0
                    var bottomCrop: CGFloat = 0
                    
                    switch presetMode {
                    case .chatRecord, .smartAuto:
                        // First slice keeps top nav; last slice keeps bottom input bar
                        if index == 0 {
                            topCrop = 0
                            bottomCrop = totalCount > 1 ? detectedBottomBar : 0
                        } else if index == totalCount - 1 {
                            topCrop = detectedTopBar
                            bottomCrop = 0
                        } else {
                            topCrop = detectedTopBar
                            bottomCrop = detectedBottomBar
                        }
                    case .webArticle:
                        if index > 0 { topCrop = detectedTopBar }
                        if index < totalCount - 1 { bottomCrop = detectedBottomBar }
                    case .continuousFeed:
                        topCrop = 0
                        bottomCrop = 0
                    case .movieSubtitles:
                        // Movie subtitles: slice 0 retains 100% full frame; slices 1..N retain bottom 18% subtitle bar
                        if index == 0 {
                            topCrop = 0
                            bottomCrop = 0
                        } else {
                            topCrop = height * 0.82
                            bottomCrop = 0
                        }
                    case .horizontalCompare:
                        topCrop = 0
                        bottomCrop = 0
                    }
                    
                    var overlapOffset: CGFloat = 0
                    var seamLineY: CGFloat = 0
                    
                    if index > 0 {
                        if presetMode == .movieSubtitles || presetMode == .horizontalCompare {
                            overlapOffset = 0
                            seamLineY = 0
                        } else {
                            let prevImage = cgImages[index - 1]
                            let prevItem = items[index - 1]
                            let match = ImageOverlapDetector.findOverlap(
                                topSlice: prevImage,
                                bottomSlice: cgImage,
                                topCropInset: topCrop,
                                bottomCropInset: prevItem.bottomCropInset
                            )
                            overlapOffset = match.offset
                            seamLineY = match.optimalSeamY
                        }
                    }
                    
                    let item = StitchItem(
                        id: UUID(),
                        relativeFilePath: path,
                        originalWidth: width,
                        originalHeight: height,
                        topCropInset: topCrop,
                        bottomCropInset: bottomCrop,
                        calculatedOverlapWithPrevious: overlapOffset,
                        manualOffsetAdjustment: 0,
                        optimalSeamLineY: seamLineY,
                        redactions: [],
                        timestamp: Date()
                    )
                    items.append(item)
                }
                
                let session = StitchSession(
                    id: UUID(),
                    createdAt: Date(),
                    source: source,
                    presetMode: presetMode,
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
