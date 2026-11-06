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
                // Only for screen recordings (replayKitBroadcast), filter out completely stationary duplicate pause frames.
                // Never discard user-selected manual screenshots from photo library!
                if source == .replayKitBroadcast && (presetMode != .movieSubtitles && presetMode != .horizontalCompare) {
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
                
                // Adaptive Scroll Zone Analysis:
                // Detects navigation bars, input bars, and split-screen media players (e.g. Xiaohongshu video notes, Bilibili)
                var detectedTopBar: CGFloat = 0
                var detectedBottomBar: CGFloat = 0
                var isSplitScreenMedia: Bool = false
                
                if loadedSlices.count >= 2 {
                    var scrollZone = ImageOverlapDetector.detectAdaptiveScrollZone(
                        topImage: loadedSlices[0].image,
                        bottomImage: loadedSlices[1].image
                    )
                    if scrollZone.confidence < 0.45 && loadedSlices.count >= 3 {
                        let secondZone = ImageOverlapDetector.detectAdaptiveScrollZone(
                            topImage: loadedSlices[1].image,
                            bottomImage: loadedSlices[2].image
                        )
                        if secondZone.confidence > scrollZone.confidence {
                            scrollZone = secondZone
                        }
                    }
                    detectedTopBar = scrollZone.topAnchorHeight
                    detectedBottomBar = scrollZone.bottomAnchorHeight
                    isSplitScreenMedia = scrollZone.isSplitScreenMedia
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
                        // First slice keeps top nav/video player; last slice keeps bottom input bar
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
                    case .continuousFeed:
                        if isSplitScreenMedia {
                            // In split-screen media apps (e.g. Xiaohongshu video notes), automatically deduplicate
                            // the upper video player and bottom input bar even in continuous mode to avoid repeating the video
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
                        } else {
                            topCrop = 0
                            bottomCrop = 0
                        }
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
                            
                            // Multi-Slice Velocity Continuity Prior:
                            // If preceding slice had a confident match, compute its implied scroll displacement
                            // to break periodic aliasing ties on repetitive feed cards or button rows.
                            var expectedDisplacement: CGFloat? = nil
                            if index >= 2 && prevItem.confidence > 0.60 && prevItem.calculatedOverlapWithPrevious > 20 {
                                let prevH = prevItem.originalHeight
                                let prevDisplacement = prevH - prevItem.topCropInset - prevItem.calculatedOverlapWithPrevious
                                if prevDisplacement > 40 {
                                    expectedDisplacement = prevDisplacement
                                }
                            }
                            
                            let match = ImageOverlapDetector.findOverlap(
                                topSlice: prevImage,
                                bottomSlice: cgImage,
                                topSliceTopCrop: prevItem.topCropInset,
                                topSliceBottomCrop: prevItem.bottomCropInset,
                                bottomSliceTopCrop: topCrop,
                                bottomSliceBottomCrop: bottomCrop,
                                expectedDisplacement: expectedDisplacement
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
    
    /// Filters out completely redundant stationary duplicate frames from screen recordings (e.g. pauses during scrolling)
    /// Never discards normal moving frames.
    public static func filterRedundantFrames(
        slices: [(path: String, image: CGImage)]
    ) -> [(path: String, image: CGImage)] {
        guard slices.count >= 3 else { return slices }
        
        var selected: [(path: String, image: CGImage)] = []
        var currentCandidate = slices[0]
        selected.append(currentCandidate)
        
        for i in 1..<slices.count {
            let nextSlice = slices[i]
            let h = CGFloat(currentCandidate.image.height)
            
            let match = ImageOverlapDetector.findOverlap(
                topSlice: currentCandidate.image,
                bottomSlice: nextSlice.image
            )
            
            let displacement = max(0, h - match.offset)
            let displacementRatio = displacement / max(1.0, h)
            
            // Only drop if it is an identical stationary frame (no scroll movement at all, e.g. pause during recording)
            if displacementRatio < 0.03 && displacement < 25 && match.confidence > 0.85 {
                // Stationary pause frame, skip it unless it's the very last frame
                if i == slices.count - 1 && selected.last?.path != nextSlice.path {
                    selected.append(nextSlice)
                }
                continue
            }
            
            selected.append(nextSlice)
            currentCandidate = nextSlice
        }
        
        return selected.count >= 2 ? selected : slices
    }
}
