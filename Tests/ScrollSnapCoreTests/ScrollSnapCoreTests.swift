import XCTest
@testable import ScrollSnapCore

final class ScrollSnapCoreTests: XCTestCase {
    
    // MARK: - 1. StitchError Tests
    
    func testStitchErrorDescriptions() {
        XCTAssertEqual(StitchError.emptySlices.errorDescription, "没有可供拼接的截图或视频画面")
        XCTAssertEqual(StitchError.renderFailed.errorDescription, "长截图渲染失败")
        XCTAssertEqual(StitchError.fileWriteFailed.errorDescription, "保存图片文件失败，请检查存储空间")
        XCTAssertEqual(StitchError.invalidDimensions.errorDescription, "图片尺寸异常")
    }
    
    // MARK: - 2. StitchSession Dimensions Tests
    
    func testVerticalSessionHeightCalculation() {
        let slice1 = StitchItem(
            relativeFilePath: "dummy1.jpg",
            originalWidth: 1170,
            originalHeight: 1800,
            topCropInset: 0,
            bottomCropInset: 0,
            calculatedOverlapWithPrevious: 0
        )
        let slice2 = StitchItem(
            relativeFilePath: "dummy2.jpg",
            originalWidth: 1170,
            originalHeight: 1800,
            topCropInset: 0,
            bottomCropInset: 0,
            calculatedOverlapWithPrevious: 200
        )
        
        let session = StitchSession(
            presetMode: .chatRecord,
            slices: [slice1, slice2],
            title: "测试长截图"
        )
        
        // slice1 visible = 1800; slice2 visible = 1800, overlap = 200 -> total = 1800 + 1600 = 3400
        XCTAssertEqual(session.totalEstimatedHeight, 3400)
        XCTAssertEqual(session.totalEstimatedWidth, 1170)
    }
    
    func testHorizontalSessionDimensionsCalculation() {
        let slice1 = StitchItem(
            relativeFilePath: "dummy1.jpg",
            originalWidth: 1000,
            originalHeight: 2000
        )
        let slice2 = StitchItem(
            relativeFilePath: "dummy2.jpg",
            originalWidth: 1000,
            originalHeight: 2000
        )
        
        let session = StitchSession(
            presetMode: .horizontalCompare,
            slices: [slice1, slice2],
            title: "横向对比"
        )
        
        XCTAssertEqual(session.totalEstimatedHeight, 2000)
        // Scaled widths = 1000 + 1000 + 4 (divider) = 2004
        XCTAssertEqual(session.totalEstimatedWidth, 2004)
    }
    
    // MARK: - 3. Image Slicer Preset Tests
    
    func testImageSlicerPresets() {
        XCTAssertEqual(ImageSlicer.SlicePreset.three.rawValue, 3)
        XCTAssertEqual(ImageSlicer.SlicePreset.four.rawValue, 4)
        XCTAssertEqual(ImageSlicer.SlicePreset.six.rawValue, 6)
        XCTAssertEqual(ImageSlicer.SlicePreset.nine.rawValue, 9)
        
        for preset in ImageSlicer.SlicePreset.allCases {
            XCTAssertFalse(preset.title.isEmpty)
            XCTAssertFalse(preset.description.isEmpty)
        }
    }
    
    // MARK: - 4. Device Frame & Background Styles Tests
    
    func testDeviceFrameFinishes() {
        let finishes = DeviceFrameFinish.allCases
        XCTAssertEqual(finishes.count, 4)
        for finish in finishes {
            XCTAssertFalse(finish.shortName.isEmpty)
            XCTAssertEqual(finish.bezelGradient.count, 3)
        }
    }
    
    func testCanvasBackgroundStyles() {
        let styles = CanvasBackgroundStyle.allCases
        XCTAssertEqual(styles.count, 5)
        XCTAssertTrue(styles.contains(.transparent))
        XCTAssertTrue(styles.contains(.adaptiveBlur))
        XCTAssertTrue(styles.contains(.appleGradient))
        XCTAssertTrue(styles.contains(.studioDark))
        XCTAssertTrue(styles.contains(.cleanWhite))
    }
    
    // MARK: - 5. Subscription Tier Quotas
    
    func testSubscriptionTiers() {
        let freeTier = SubscriptionTier.freeTier
        XCTAssertEqual(freeTier.dailyFreeLimit, 2)
        XCTAssertFalse(freeTier.allowsPDFAndLosslessExport)
        
        let proTier = SubscriptionTier.lifetimePro
        XCTAssertEqual(proTier.dailyFreeLimit, Int.max)
        XCTAssertTrue(proTier.allowsPDFAndLosslessExport)
    }
    
    // MARK: - 6. Redaction Stroke Model Tests
    
    func testRedactionBrushTypes() {
        let brushes = RedactionBrushType.allCases
        XCTAssertEqual(brushes.count, 3)
        XCTAssertEqual(RedactionBrushType.frostedGlass.rawValue, "毛玻璃")
        XCTAssertEqual(RedactionBrushType.pixelateMosaic.rawValue, "马赛克")
        XCTAssertEqual(RedactionBrushType.confidentialInk.rawValue, "涂抹笔")
    }
    
    // MARK: - 7. Optimal Seam Vertical Layout & Canvas Invariance Tests
    
    func testComputeVerticalLayoutCanvasHeightInvariance() {
        let slice1 = StitchItem(
            relativeFilePath: "s1.png",
            originalWidth: 1170,
            originalHeight: 2532,
            topCropInset: 0,
            bottomCropInset: 84,
            calculatedOverlapWithPrevious: 0,
            optimalSeamLineY: 0
        )
        let slice2 = StitchItem(
            relativeFilePath: "s2.png",
            originalWidth: 1170,
            originalHeight: 2532,
            topCropInset: 88,
            bottomCropInset: 84,
            calculatedOverlapWithPrevious: 320,
            optimalSeamLineY: 160 // optimal seam in middle of 320px overlap
        )
        let slice3 = StitchItem(
            relativeFilePath: "s3.png",
            originalWidth: 1170,
            originalHeight: 2532,
            topCropInset: 88,
            bottomCropInset: 0,
            calculatedOverlapWithPrevious: 280,
            optimalSeamLineY: 100 // optimal seam at 100px
        )
        
        let session = StitchSession(
            presetMode: .chatRecord,
            slices: [slice1, slice2, slice3]
        )
        
        let layouts = TiledImageRenderer.computeVerticalLayout(session: session, canvasWidth: 1170)
        XCTAssertEqual(layouts.count, 3)
        
        // Total rendered canvas height must exactly match session.totalEstimatedHeight
        let totalLayoutHeight = layouts.reduce(0.0) { $0 + $1.canvasHeight }
        XCTAssertEqual(totalLayoutHeight, session.totalEstimatedHeight, accuracy: 0.001)
        
        // Slices must tile continuously without gaps
        XCTAssertEqual(layouts[0].canvasY, 0)
        XCTAssertEqual(layouts[1].canvasY, layouts[0].canvasHeight, accuracy: 0.001)
        XCTAssertEqual(layouts[2].canvasY, layouts[0].canvasHeight + layouts[1].canvasHeight, accuracy: 0.001)
    }
    
    func testSeamShiftDoesNotAlterTotalCanvasHeight() {
        var slice1 = StitchItem(
            relativeFilePath: "s1.png",
            originalWidth: 1000,
            originalHeight: 2000,
            topCropInset: 0,
            bottomCropInset: 0,
            calculatedOverlapWithPrevious: 0
        )
        var slice2 = StitchItem(
            relativeFilePath: "s2.png",
            originalWidth: 1000,
            originalHeight: 2000,
            topCropInset: 0,
            bottomCropInset: 0,
            calculatedOverlapWithPrevious: 400,
            optimalSeamLineY: 100 // seam at 100
        )
        
        let sessionA = StitchSession(presetMode: .continuousFeed, slices: [slice1, slice2])
        let layoutA = TiledImageRenderer.computeVerticalLayout(session: sessionA, canvasWidth: 1000)
        let totalHeightA = layoutA.reduce(0.0) { $0 + $1.canvasHeight }
        
        // Now change the seam line to 300px inside the 400px overlap
        slice2.optimalSeamLineY = 300
        let sessionB = StitchSession(presetMode: .continuousFeed, slices: [slice1, slice2])
        let layoutB = TiledImageRenderer.computeVerticalLayout(session: sessionB, canvasWidth: 1000)
        let totalHeightB = layoutB.reduce(0.0) { $0 + $1.canvasHeight }
        
        // Shifting seam position within the duplicate overlap zone must leave total canvas height unchanged
        XCTAssertEqual(totalHeightA, totalHeightB, accuracy: 0.001)
        XCTAssertEqual(totalHeightA, 3600.0, accuracy: 0.001)
    }
    
    func testMovieSubtitlesVerticalLayout() {
        let slice1 = StitchItem(
            relativeFilePath: "frame1.png",
            originalWidth: 1920,
            originalHeight: 1080
        )
        let slice2 = StitchItem(
            relativeFilePath: "frame2.png",
            originalWidth: 1920,
            originalHeight: 1080
        )
        
        let session = StitchSession(
            presetMode: .movieSubtitles,
            slices: [slice1, slice2]
        )
        
        let layouts = TiledImageRenderer.computeVerticalLayout(session: session, canvasWidth: 1920)
        XCTAssertEqual(layouts.count, 2)
        
        // Slice 1: full 1080 frame
        XCTAssertEqual(layouts[0].sourceYStart, 0)
        XCTAssertEqual(layouts[0].canvasHeight, 1080)
        
        // Slice 2: bottom 18% subtitles bar (1080 * 0.18 = 194.4)
        XCTAssertEqual(layouts[1].sourceYStart, 1080 * 0.82, accuracy: 0.01)
        XCTAssertEqual(layouts[1].canvasHeight, 1080 * 0.18, accuracy: 0.01)
        
        let totalLayoutHeight = layouts.reduce(0.0) { $0 + $1.canvasHeight }
        XCTAssertEqual(totalLayoutHeight, session.totalEstimatedHeight, accuracy: 0.001)
    }
    
    // MARK: - 8. Tactile Dial Multipliers & Broadened Overlap Search Tests
    
    func testDialSpeedMultipliers() {
        let multipliers = DialSpeedMultiplier.allCases
        XCTAssertEqual(multipliers.count, 4)
        XCTAssertEqual(DialSpeedMultiplier.micro.rawValue, 0.5)
        XCTAssertEqual(DialSpeedMultiplier.standard.rawValue, 1.0)
        XCTAssertEqual(DialSpeedMultiplier.fast.rawValue, 10.0)
        XCTAssertEqual(DialSpeedMultiplier.jump.rawValue, 50.0)
    }
    
    // MARK: - 9. Multi-Scenario Adaptive Scroll Zone & Feature Profiles
    
    func testCombinedFeatureProfileComputation() {
        let lum = [0.2, 0.4, 0.8, 1.0]
        let edge = [0.1, 0.5, 0.0, 0.6]
        let profile = ImageProfile1D(luminance: lum, horizontalEdgeEnergy: edge)
        
        XCTAssertEqual(profile.luminance.count, 4)
        XCTAssertEqual(profile.horizontalEdgeEnergy.count, 4)
        XCTAssertEqual(profile.combinedFeature.count, 4)
        
        // 0.2 * 0.35 + 0.1 * 0.65 = 0.07 + 0.065 = 0.135
        XCTAssertEqual(profile.combinedFeature[0], 0.135, accuracy: 0.001)
        // 0.4 * 0.35 + 0.5 * 0.65 = 0.14 + 0.325 = 0.465
        XCTAssertEqual(profile.combinedFeature[1], 0.465, accuracy: 0.001)
    }
    
    func testScrollZoneDetectionResultModel() {
        let result = ScrollZoneDetectionResult(
            topAnchorHeight: 850,
            bottomAnchorHeight: 120,
            isSplitScreenMedia: true,
            scrollVelocityEstimate: 320,
            confidence: 0.95
        )
        
        XCTAssertEqual(result.topAnchorHeight, 850)
        XCTAssertEqual(result.bottomAnchorHeight, 120)
        XCTAssertTrue(result.isSplitScreenMedia)
        XCTAssertEqual(result.scrollVelocityEstimate, 320)
        XCTAssertEqual(result.confidence, 0.95, accuracy: 0.001)
    }
    
    func testSplitScreenMediaVerticalLayoutTiling() {
        let slice1 = StitchItem(
            relativeFilePath: "note_s1.jpg",
            originalWidth: 1170,
            originalHeight: 2532,
            topCropInset: 0,
            bottomCropInset: 120,
            calculatedOverlapWithPrevious: 0
        )
        let slice2 = StitchItem(
            relativeFilePath: "note_s2.jpg",
            originalWidth: 1170,
            originalHeight: 2532,
            topCropInset: 1000,
            bottomCropInset: 0,
            calculatedOverlapWithPrevious: 400,
            optimalSeamLineY: 200
        )
        
        let session = StitchSession(
            presetMode: .chatRecord,
            slices: [slice1, slice2]
        )
        
        let layouts = TiledImageRenderer.computeVerticalLayout(session: session, canvasWidth: 1170)
        XCTAssertEqual(layouts.count, 2)
        
        // Slice 1: starts at top 0, includes video player and comments up to seam
        XCTAssertEqual(layouts[0].sourceYStart, 0)
        XCTAssertEqual(layouts[0].canvasY, 0)
        
        // Slice 2: starts after cropped top 1000 + seam 200 = 1200
        XCTAssertEqual(layouts[1].sourceYStart, 1200)
        XCTAssertEqual(layouts[1].canvasY, layouts[0].canvasHeight, accuracy: 0.001)
        
        // Continuous tiling without gaps
        let totalLayoutH = layouts.reduce(0.0) { $0 + $1.canvasHeight }
        XCTAssertEqual(totalLayoutH, session.totalEstimatedHeight, accuracy: 0.001)
    }
    
    // MARK: - 10. Multi-Band Consensus & High-Precision Stitching
    
    func testDiscontinuousSlicesZeroOffsetSafety() {
        // When slices have zero overlap or are completely dissimilar,
        // calculatedOverlap must be 0 and vertical layout stacks them sequentially without clipping
        let slice1 = StitchItem(
            relativeFilePath: "photo_a.jpg",
            originalWidth: 1000,
            originalHeight: 1500,
            calculatedOverlapWithPrevious: 0
        )
        let slice2 = StitchItem(
            relativeFilePath: "photo_b.jpg",
            originalWidth: 1000,
            originalHeight: 1500,
            calculatedOverlapWithPrevious: 0 // Discontinuous safe stack
        )
        
        let session = StitchSession(
            presetMode: .chatRecord,
            slices: [slice1, slice2]
        )
        
        let layouts = TiledImageRenderer.computeVerticalLayout(session: session, canvasWidth: 1000)
        XCTAssertEqual(layouts.count, 2)
        XCTAssertEqual(layouts[0].canvasHeight, 1500)
        XCTAssertEqual(layouts[1].canvasHeight, 1500)
        XCTAssertEqual(session.totalEstimatedHeight, 3000)
    }
    
    // MARK: - 11. Subpixel Parabolic Precision & Asymmetry Feature Tests
    
    func testSubpixelPrecisionVerticalLayout() {
        // Test subpixel floating point overlap (e.g. 342.375 pt)
        let slice1 = StitchItem(
            relativeFilePath: "sub1.png",
            originalWidth: 1170,
            originalHeight: 2532,
            topCropInset: 0,
            bottomCropInset: 84.5,
            calculatedOverlapWithPrevious: 0
        )
        let slice2 = StitchItem(
            relativeFilePath: "sub2.png",
            originalWidth: 1170,
            originalHeight: 2532,
            topCropInset: 88.25,
            bottomCropInset: 0,
            calculatedOverlapWithPrevious: 342.375,
            optimalSeamLineY: 171.1875
        )
        
        let session = StitchSession(presetMode: .chatRecord, slices: [slice1, slice2])
        let layouts = TiledImageRenderer.computeVerticalLayout(session: session, canvasWidth: 1170)
        
        XCTAssertEqual(layouts.count, 2)
        let totalLayoutH = layouts.reduce(0.0) { $0 + $1.canvasHeight }
        XCTAssertEqual(totalLayoutH, session.totalEstimatedHeight, accuracy: 0.0001)
        XCTAssertEqual(layouts[1].canvasY, layouts[0].canvasHeight, accuracy: 0.0001)
    }
    
    func testOverlapMatchResultSubpixelModel() {
        let result = OverlapMatchResult(offset: 452.34, confidence: 0.985, optimalSeamY: 226.17)
        XCTAssertEqual(result.offset, 452.34, accuracy: 0.001)
        XCTAssertEqual(result.confidence, 0.985, accuracy: 0.001)
        XCTAssertEqual(result.optimalSeamY, 226.17, accuracy: 0.001)
    }
    
    // MARK: - 12. AppCacheManager & Storage Breakdown Tests
    
    func testCacheBreakdownModel() {
        let breakdown = CacheBreakdown(temporaryCacheBytes: 104_857_600, recentSavesBytes: 15_728_640)
        XCTAssertEqual(breakdown.temporaryCacheBytes, 104_857_600)
        XCTAssertEqual(breakdown.recentSavesBytes, 15_728_640)
        XCTAssertEqual(breakdown.totalCacheBytes, 120_586_240)
    }
    
    func testTemporaryCachePurgePreservesRecentSaves() {
        let manager = AppCacheManager.shared
        let breakdown = manager.calculateCacheBreakdown()
        XCTAssertGreaterThanOrEqual(breakdown.temporaryCacheBytes, 0)
        XCTAssertGreaterThanOrEqual(breakdown.recentSavesBytes, 0)
        XCTAssertGreaterThanOrEqual(breakdown.totalCacheBytes, 0)
    }
    
    // MARK: - 13. Three-Tap Gaussian Valley Seam Line Tests
    
    func testMinimalEnergySeamValleySelection() {
        // High energy blocks (text rows) at 10..18 and 24..32, valley at 19..23
        var energy = [Double](repeating: 0.0, count: 50)
        for i in 10...18 { energy[i] = 0.85 }
        for i in 24...32 { energy[i] = 0.85 }
        
        var lum = [Double](repeating: 0.9, count: 50)
        for i in 10...18 { lum[i] = 0.2 }
        for i in 24...32 { lum[i] = 0.2 }
        
        let profile = ImageProfile1D(luminance: lum, horizontalEdgeEnergy: energy)
        XCTAssertEqual(profile.luminance.count, 50)
        XCTAssertEqual(profile.horizontalEdgeEnergy.count, 50)
    }
}
