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
                
                // Trim leading ReplayKit app-switch / Control Center transition frames before stitching
                if source == .replayKitBroadcast && (presetMode != .movieSubtitles && presetMode != .horizontalCompare) {
                    loadedSlices = Self.trimLeadingTransitionFrames(slices: loadedSlices)
                }
                
                // Intelligent Bidirectional Sequence Detection:
                // If user selected slices in reverse order (e.g. from newest to oldest in PhotosPicker),
                // evaluate forward vs reverse correlation across multiple adjacent slice pairs to reach consensus.
                if loadedSlices.count >= 2 && (presetMode != .movieSubtitles && presetMode != .horizontalCompare) {
                    let pairsToTest = min(loadedSlices.count - 1, 3)
                    var forwardScore: Double = 0.0
                    var reverseScore: Double = 0.0
                    var forwardVotes: Int = 0
                    var reverseVotes: Int = 0
                    
                    for p in 0..<pairsToTest {
                        let sliceA = loadedSlices[p].image
                        let sliceB = loadedSlices[p + 1].image
                        let fwd = ImageOverlapDetector.findOverlap(topSlice: sliceA, bottomSlice: sliceB)
                        let rev = ImageOverlapDetector.findOverlap(topSlice: sliceB, bottomSlice: sliceA)
                        
                        forwardScore += fwd.confidence
                        reverseScore += rev.confidence
                        
                        if fwd.confidence > rev.confidence + 0.15 && fwd.confidence >= 0.40 {
                            forwardVotes += 1
                        } else if rev.confidence > fwd.confidence + 0.15 && rev.confidence >= 0.40 {
                            reverseVotes += 1
                        }
                    }
                    
                    let shouldReverse: Bool
                    if reverseVotes > forwardVotes && reverseScore > forwardScore {
                        shouldReverse = true
                    } else if reverseScore > forwardScore + (Double(pairsToTest) * 0.22) && reverseScore > Double(pairsToTest) * 0.35 {
                        shouldReverse = true
                    } else {
                        shouldReverse = false
                    }
                    
                    if shouldReverse {
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
                var isCardFeedDetected: Bool = false
                var isWebArticleDetected: Bool = false
                var detectedScenario: AppLayoutScenario = .generalScroll
                
                if loadedSlices.count >= 2 {
                    let consensusZone = ImageOverlapDetector.detectConsensusScrollZone(
                        slices: loadedSlices.map(\.image)
                    )
                    detectedTopBar = consensusZone.topAnchorHeight
                    detectedBottomBar = consensusZone.bottomAnchorHeight
                    isSplitScreenMedia = consensusZone.isSplitScreenMedia
                    isChatAppDetected = consensusZone.isChatAppDetected
                    isCardFeedDetected = consensusZone.isCardFeedDetected
                    isWebArticleDetected = consensusZone.isWebArticleDetected
                    detectedScenario = consensusZone.scenario
                }
                
                let effectiveScenario: AppLayoutScenario
                if presetMode == .smartAuto {
                    effectiveScenario = detectedScenario
                } else {
                    effectiveScenario = presetMode.correspondingScenario
                }
                
                // Scenario-adaptive fallback safety insets (Dynamic Island 294px nav bar, WeChat 270px input bar)
                if effectiveScenario == .chatApp || presetMode == .chatRecord {
                    if let firstImage = loadedSlices.first?.image {
                        let h = CGFloat(firstImage.height)
                        let chatTopFallback = min(h * 0.13, 294.0)
                        let chatBottomFallback = min(h * 0.11, 270.0)
                        detectedTopBar = max(detectedTopBar, chatTopFallback)
                        detectedBottomBar = max(detectedBottomBar, chatBottomFallback)
                    }
                } else if effectiveScenario == .webArticle || presetMode == .webArticle {
                    if let firstImage = loadedSlices.first?.image {
                        let h = CGFloat(firstImage.height)
                        let webTopFallback = min(h * 0.10, 240.0)
                        let webBottomFallback = min(h * 0.08, 160.0)
                        detectedTopBar = max(detectedTopBar, webTopFallback)
                        detectedBottomBar = max(detectedBottomBar, webBottomFallback)
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
                                let prevPrevItem = items[index - 2]
                                let prevDisplacement = prevPrevItem.originalHeight - prevPrevItem.bottomCropInset - prevItem.topCropInset - prevItem.calculatedOverlapWithPrevious
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
                                expectedDisplacement: expectedDisplacement,
                                scenario: effectiveScenario
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
    
    // MARK: - Image Loading Utility
    
    private static func loadCGImage(fromRelativePath path: String) -> CGImage? {
        guard let fileURL = SharedStore.shared.resolveFileURL(relativePath: path) else { return nil }
        #if canImport(UIKit)
        guard let uiImage = UIImage(contentsOfFile: fileURL.path) else { return nil }
        if uiImage.imageOrientation == .up, let cg = uiImage.cgImage {
            return cg
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: uiImage.size, format: format)
        let normalized = renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: uiImage.size))
        }
        return normalized.cgImage
        #else
        return nil
        #endif
    }
    
    // MARK: - Interactive Recomputation & Slice Management
    
    /// Recomputes overlaps for all adjacent slices in a session after slices were added, removed, or reordered.
    /// Preserves existing crop insets if present.
    public static func recomputeSlices(in session: inout StitchSession) {
        let totalCount = session.slices.count
        guard totalCount >= 1 else { return }
        
        let scenario = session.presetMode.correspondingScenario
        
        for index in 0..<totalCount {
            if index == 0 {
                session.slices[0].calculatedOverlapWithPrevious = 0
                session.slices[0].manualOffsetAdjustment = 0
                session.slices[0].optimalSeamLineY = 0
                session.slices[0].matchConfidence = 1.0
                session.slices[0].topCropInset = 0
                continue
            }
            
            let prevSlice = session.slices[index - 1]
            var currentSlice = session.slices[index]
            
            recalculateSingleSeam(
                topSliceItem: prevSlice,
                bottomSliceItem: &currentSlice,
                scenario: scenario
            )
            
            session.slices[index] = currentSlice
        }
    }
    
    /// Recalculates overlap detection for a single seam between two adjacent slices.
    public static func recalculateSingleSeam(
        topSliceItem: StitchItem,
        bottomSliceItem: inout StitchItem,
        scenario: AppLayoutScenario = .generalScroll
    ) {
        guard let topImage = loadCGImage(fromRelativePath: topSliceItem.relativeFilePath),
              let botImage = loadCGImage(fromRelativePath: bottomSliceItem.relativeFilePath) else {
            return
        }
        
        let match = ImageOverlapDetector.findOverlap(
            topSlice: topImage,
            bottomSlice: botImage,
            topSliceTopCrop: topSliceItem.topCropInset,
            topSliceBottomCrop: topSliceItem.bottomCropInset,
            bottomSliceTopCrop: bottomSliceItem.topCropInset,
            bottomSliceBottomCrop: bottomSliceItem.bottomCropInset,
            scenario: scenario
        )
        
        bottomSliceItem.calculatedOverlapWithPrevious = match.offset
        bottomSliceItem.optimalSeamLineY = match.optimalSeamY
        bottomSliceItem.matchConfidence = match.confidence
        bottomSliceItem.manualOffsetAdjustment = 0
    }
    
    /// Forces a seam to directly connect with zero overlap (for non-overlapping consecutive captures)
    public static func directAppendSeam(bottomSliceItem: inout StitchItem) {
        bottomSliceItem.calculatedOverlapWithPrevious = 0
        bottomSliceItem.manualOffsetAdjustment = 0
        bottomSliceItem.optimalSeamLineY = 0
        bottomSliceItem.matchConfidence = 1.0
    }
    
    // MARK: - Keyframe Selection & Deduplication
    
    /// Drops up to 3 leading unrelated transition frames (e.g. Control Center / Home Screen captured right after ReplayKit countdown)
    /// when they exhibit zero overlap with the subsequent screen, before a coherent overlapping scroll run begins.
    public static func trimLeadingTransitionFrames(
        slices: [(path: String, image: CGImage)]
    ) -> [(path: String, image: CGImage)] {
        guard slices.count >= 4 else { return slices }
        
        let maxTrim = min(3, slices.count - 2)
        for startIdx in 0..<maxTrim {
            let fwd = ImageOverlapDetector.findOverlap(topSlice: slices[startIdx].image, bottomSlice: slices[startIdx + 1].image)
            let rev = ImageOverlapDetector.findOverlap(topSlice: slices[startIdx + 1].image, bottomSlice: slices[startIdx].image)
            let pairConfidence = max(fwd.confidence, rev.confidence)
            let pairOverlap = max(fwd.offset, rev.offset)
            
            if pairConfidence >= 0.40 && pairOverlap > 10 {
                return startIdx > 0 ? Array(slices.dropFirst(startIdx)) : slices
            }
            // If current leading pair is unrelated (< 0.30), continue checking if the next pair forms a valid overlap;
            // stop early if even pairConfidence is borderline (0.30..<0.40) so normal fast scrolls aren't trimmed.
            if pairConfidence >= 0.30 {
                return slices
            }
        }
        
        return slices
    }
    
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
            
            // Fast downscaled scroll displacement analysis: avoids expensive subpixel & seam passes during deduplication
            let zone = ImageOverlapDetector.detectAdaptiveScrollZone(
                topImage: currentCandidate.image,
                bottomImage: nextSlice.image
            )
            
            let activeHeight = max(1.0, h - topCrop - bottomCrop)
            let displacement = zone.scrollVelocityEstimate
            let displacementRatio = displacement / activeHeight
            
            // Only drop if it is an identical stationary frame (no scroll movement at all in active zone, e.g. pause during recording)
            if displacementRatio < 0.03 && displacement < 25 && zone.confidence > 0.75 {
                // If ending frame has subtle forward settling (4..24px), replace the last slice so the final view
                // extends to the true bottom without creating a duplicated slice
                if i == slices.count - 1 && displacement > 4 && !selected.isEmpty {
                    selected[selected.count - 1] = nextSlice
                }
                continue
            }
            
            selected.append(nextSlice)
            currentCandidate = nextSlice
        }
        
        return selected.count >= 2 ? selected : slices
    }
}
