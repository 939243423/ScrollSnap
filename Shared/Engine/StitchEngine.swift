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
        presetMode: StitchPresetMode = .smartAuto,
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
                              let uiImage = UIImage(data: sourceData) else {
                            return
                        }
                        #if canImport(UIKit)
                        let fixedCGImage: CGImage?
                        if uiImage.imageOrientation == .up, let cg = uiImage.cgImage {
                            fixedCGImage = cg
                        } else {
                            let format = UIGraphicsImageRendererFormat.default()
                            format.scale = 1.0
                            let renderer = UIGraphicsImageRenderer(size: uiImage.size, format: format)
                            let normalized = renderer.image { _ in
                                uiImage.draw(in: CGRect(origin: .zero, size: uiImage.size))
                            }
                            fixedCGImage = normalized.cgImage
                        }
                        #else
                        let fixedCGImage = uiImage.cgImage
                        #endif
                        if let cg = fixedCGImage {
                            loadedSlices.append((path: path, image: cg))
                        }
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
                // Evaluates multiple adjacent slice pairs to achieve consensus on fixed and scrolling zones
                var detectedTopBar: CGFloat = 0
                var detectedBottomBar: CGFloat = 0
                var isSplitScreenMedia: Bool = false
                var isChatAppDetected: Bool = false
                
                if loadedSlices.count >= 2 {
                    let consensusZone = ImageOverlapDetector.detectConsensusScrollZone(
                        slices: loadedSlices.map(\.image)
                    )
                    detectedTopBar = consensusZone.topAnchorHeight
                    detectedBottomBar = consensusZone.bottomAnchorHeight
                    isSplitScreenMedia = consensusZone.isSplitScreenMedia
                    isChatAppDetected = consensusZone.isChatAppDetected
                }
                
                // If user selected chatRecord mode, or if chat app is detected, ensure safe minimum insets
                // (WeChat / iMessage: top status bar + nav bar ~280px on @3x, bottom input bar ~240px)
                if presetMode == .chatRecord || (presetMode == .smartAuto && isChatAppDetected) {
                    if let firstImage = loadedSlices.first?.image {
                        let h = CGFloat(firstImage.height)
                        let chatTopFallback = min(h * 0.12, 280)
                        let chatBottomFallback = min(h * 0.10, 240)
                        if detectedTopBar < 120 {
                            detectedTopBar = max(detectedTopBar, chatTopFallback)
                        }
                        if detectedBottomBar < 100 {
                            detectedBottomBar = max(detectedBottomBar, chatBottomFallback)
                        }
                    }
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
                    
                    let detectedRedactions: [RedactionRegion] = []
                    
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
        
        let consensusZone = ImageOverlapDetector.detectConsensusScrollZone(slices: slices.map(\.image))
        let topCrop = consensusZone.topAnchorHeight
        let bottomCrop = consensusZone.bottomAnchorHeight
        
        var selected: [(path: String, image: CGImage)] = []
        var currentCandidate = slices[0]
        selected.append(currentCandidate)
        
        for i in 1..<slices.count {
            let nextSlice = slices[i]
            let h = CGFloat(currentCandidate.image.height)
            
            let match = ImageOverlapDetector.findOverlap(
                topSlice: currentCandidate.image,
                bottomSlice: nextSlice.image,
                topSliceTopCrop: topCrop,
                topSliceBottomCrop: bottomCrop,
                bottomSliceTopCrop: topCrop,
                bottomSliceBottomCrop: bottomCrop
            )
            
            let activeHeight = max(1.0, h - topCrop - bottomCrop)
            let rawDisplacement = activeHeight - match.offset
            let displacement = max(0, rawDisplacement)
            let displacementRatio = displacement / activeHeight
            
            // Drop reverse upward bounce frames (negative displacement with confident match)
            if rawDisplacement < -10 && match.confidence > 0.45 {
                continue
            }
            
            // Only drop if it is an identical stationary frame (no scroll movement at all in active zone, e.g. pause during recording)
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
