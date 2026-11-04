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
}
