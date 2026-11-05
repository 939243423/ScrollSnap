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
        presetMode: StitchPresetMode = .chatRecord,
        sourceAssetIdentifiers: [String] = []
    ) async throws -> StitchSession {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                guard !fileRelativePaths.isEmpty else {
                    continuation.resume(throwing: StitchError.emptySlices)
                    return
                }
                
                var loadedSlices: [(path: String, image: CGImage)] = []
                for path in fileRelativePaths {
                    autoreleasepool {
                        guard let fileURL = SharedStore.shared.resolveFileURL(relativePath: path),
                              let sourceData = try? Data(contentsOf: fileURL),
                              let uiImage = UIImage(data: sourceData),
                              let cgImage = uiImage.cgImage else {
                            return
                        }
                        loadedSlices.append((path: path, image: cgImage))
                    }
                }
                
                guard !loadedSlices.isEmpty else {
                    continuation.resume(throwing: StitchError.emptySlices)
                    return
                }
                
                // Intelligent Bidirectional Sequence Detection:
                // If user selected slices in reverse order (e.g. from newest to oldest in PhotosPicker),
                // compare forward correlation vs reverse correlation and auto-correct slice order.
                if loadedSlices.count >= 2 && (presetMode != .movieSubtitles && presetMode != .horizontalCompare) {
                    let forwardCheck = ImageOverlapDetector.findOverlap(
                        topSlice: loadedSlices[0].image,
                        bottomSlice: loadedSlices[1].image
                    )
                    let reverseCheck = ImageOverlapDetector.findOverlap(
                        topSlice: loadedSlices[1].image,
                        bottomSlice: loadedSlices[0].image
                    )
                    if reverseCheck.confidence > forwardCheck.confidence + 0.20 && reverseCheck.confidence > 0.35 {
                        loadedSlices.reverse()
                    }
                }
                
                // Adaptive Keyframe Selection & Deduplication Pass:
                // When stitching screen recordings or densely sampled slices (e.g. 10 FPS broadcast),
                // filter out redundant intermediate micro-scroll frames (<18% displacement / >82% overlap)
                // so consecutive keyframes land in the optimal 35% ~ 65% overlap sweet spot.
                if (source == .replayKitBroadcast || loadedSlices.count >= 4) && (presetMode != .movieSubtitles && presetMode != .horizontalCompare) {
                    loadedSlices = Self.filterRedundantFrames(slices: loadedSlices)
                }
                
                // Session Persistence Isolation:
                // Copies slices to a permanent sessions/<sessionId>/ directory so that resetting active_session
                // in the broadcast extension does not invalidate or blank the active editor canvas.
                let sessionId = UUID()
                let persistedPaths = SharedStore.shared.persistSessionSlices(
                    fromRelativePaths: loadedSlices.map(\.path),
                    sessionId: sessionId
                )
                
                // Detect static navigation bar and bottom bar height from first two slices
                var detectedTopBar: CGFloat = 0
                var detectedBottomBar: CGFloat = 0
                if loadedSlices.count >= 2 {
                    let chrome = ImageOverlapDetector.detectStaticChromeRegions(
                        topImage: loadedSlices[0].image,
                        bottomImage: loadedSlices[1].image
                    )
                    detectedTopBar = chrome.topBarHeight
                    detectedBottomBar = chrome.bottomBarHeight
                }
                
                var items: [StitchItem] = []
                let totalCount = loadedSlices.count
                
                for (index, slice) in loadedSlices.enumerated() {
                    let cgImage = slice.image
                    let persistentPath = index < persistedPaths.count ? persistedPaths[index] : slice.path
                    let width = CGFloat(cgImage.width)
                    let height = CGFloat(cgImage.height)
                    
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
                    var matchConfidence: Double = 1.0
                    
                    if index > 0 {
                        if presetMode == .movieSubtitles || presetMode == .horizontalCompare {
                            overlapOffset = 0
                            seamLineY = 0
                            matchConfidence = 1.0
                        } else {
                            let prevImage = loadedSlices[index - 1].image
                            let prevItem = items[index - 1]
                            let match = ImageOverlapDetector.findOverlap(
                                topSlice: prevImage,
                                bottomSlice: cgImage,
                                topSliceTopCrop: prevItem.topCropInset,
                                topSliceBottomCrop: prevItem.bottomCropInset,
                                bottomSliceTopCrop: topCrop,
                                bottomSliceBottomCrop: bottomCrop
                            )
                            overlapOffset = match.offset
                            seamLineY = match.optimalSeamY
                            matchConfidence = match.confidence
                        }
                    }
                    
                    var detectedRedactions: [RedactionRegion] = []
                    #if canImport(UIKit)
                    if index > 0 && index < totalCount - 1 && abs(overlapOffset) > 20 && (presetMode == .chatRecord || presetMode == .smartAuto || presetMode == .webArticle) {
                        let prevImage = loadedSlices[index - 1].image
                        let floatingBoxes = FloatingChromeRemover.shared.detectFloatingOverlays(
                            topCG: prevImage,
                            botCG: cgImage,
                            scrollOffset: overlapOffset
                        )
                        for box in floatingBoxes {
                            let relRect = CGRect(
                                x: box.minX / max(1, width),
                                y: box.minY / max(1, height),
                                width: box.width / max(1, width),
                                height: box.height / max(1, height)
                            )
                            detectedRedactions.append(RedactionRegion(id: UUID(), relativeRect: relRect, style: .frostedBlur))
                        }
                    }
                    #endif
                    
                    let item = StitchItem(
                        id: UUID(),
                        relativeFilePath: persistentPath,
                        originalWidth: width,
                        originalHeight: height,
                        topCropInset: topCrop,
                        bottomCropInset: bottomCrop,
                        calculatedOverlapWithPrevious: overlapOffset,
                        manualOffsetAdjustment: 0,
                        optimalSeamLineY: seamLineY,
                        matchConfidence: matchConfidence,
                        redactions: detectedRedactions,
                        timestamp: Date()
                    )
                    items.append(item)
                }
                
                let session = StitchSession(
                    id: sessionId,
                    createdAt: Date(),
                    source: source,
                    presetMode: presetMode,
                    slices: items,
                    title: "Stitched_\(Int(Date().timeIntervalSince1970))",
                    deviceScreenWidth: items.first?.originalWidth ?? 393,
                    deviceScreenScale: 3.0,
                    hasAppliedDeviceFrame: false,
                    sourceAssetIdentifiers: sourceAssetIdentifiers
                )
                
                continuation.resume(returning: session)
            }
        }
    }
    
    // MARK: - Keyframe Selection & Deduplication
    
    /// Filters out redundant intermediate micro-scroll frames from screen recordings
    /// Keeps consecutive keyframes in the 20% ~ 70% displacement sweet spot (30% ~ 80% overlap)
    public static func filterRedundantFrames(
        slices: [(path: String, image: CGImage)]
    ) -> [(path: String, image: CGImage)] {
        guard slices.count >= 3 else { return slices }
        
        var selected: [(path: String, image: CGImage)] = []
        var currentCandidate = slices[0]
        selected.append(currentCandidate)
        
        var i = 1
        while i < slices.count {
            let nextSlice = slices[i]
            let h = CGFloat(currentCandidate.image.height)
            
            // Check overlap between current candidate and next candidate
            let match = ImageOverlapDetector.findOverlap(
                topSlice: currentCandidate.image,
                bottomSlice: nextSlice.image
            )
            
            let displacement = max(0, h - match.offset)
            let displacementRatio = displacement / max(1.0, h)
            
            // If displacement < 18% (meaning > 82% overlap), it is an intermediate micro-frame
            // Only select when displacement reaches at least 20% OR if sudden large jump (> 75%)
            if displacementRatio >= 0.75 {
                // Sudden fast jump: preserve i - 1 as a bridge keyframe if available
                if i > 1 && slices[i - 1].path != currentCandidate.path {
                    selected.append(slices[i - 1])
                }
                selected.append(nextSlice)
                currentCandidate = nextSlice
            } else if displacementRatio >= 0.20 && match.confidence >= 0.35 {
                // Optimal keyframe: 20% ~ 70% displacement (30% ~ 80% overlap)
                selected.append(nextSlice)
                currentCandidate = nextSlice
            } else if i == slices.count - 1 && displacementRatio > 0.04 {
                // Final frame contains remaining new content at page bottom
                selected.append(nextSlice)
            }
            i += 1
        }
        
        // Ensure final frame is included if not present and has non-zero movement
        if let last = slices.last, selected.last?.path != last.path {
            let match = ImageOverlapDetector.findOverlap(
                topSlice: selected.last!.image,
                bottomSlice: last.image
            )
            let displacement = CGFloat(last.image.height) - match.offset
            if displacement > 30 {
                selected.append(last)
            }
        }
        
        return selected.count >= 2 ? selected : slices
    }
}
