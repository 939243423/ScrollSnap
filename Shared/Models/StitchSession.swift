import Foundation
import CoreGraphics

public enum StitchError: LocalizedError {
    case emptySlices
    case renderFailed
    case fileWriteFailed
    case invalidDimensions
    
    public var errorDescription: String? {
        switch self {
        case .emptySlices:
            return "没有可供拼接的截图或视频画面"
        case .renderFailed:
            return "长截图渲染失败"
        case .fileWriteFailed:
            return "保存图片文件失败，请检查存储空间"
        case .invalidDimensions:
            return "图片尺寸异常"
        }
    }
}

public enum AppLayoutScenario: String, Codable, CaseIterable {
    case chatApp       // 微信 / 聊天会话 (固定顶栏 + 底部输入框 + 左右气泡)
    case splitMedia    // 小红书 / 视频图文 (上半部固定视频/大图 + 下半部滚动评论)
    case cardFeed      // 微博 / 社交与商品信息流 (卡片式布局 + 周期性分割线)
    case webArticle    // Safari / 网页长文 (吸顶网址栏 + 底部工具栏 + 密集段落文本)
    case generalScroll // 普通长滚动 / 无明显固定栏
    
    public var title: String {
        switch self {
        case .chatApp: return "微信聊天"
        case .splitMedia: return "分屏视频/图文"
        case .cardFeed: return "社交信息流"
        case .webArticle: return "网页文章"
        case .generalScroll: return "长图滚动"
        }
    }
}

public enum StitchPresetMode: String, Codable, CaseIterable, Identifiable {
    case smartAuto       // 自动识别吸顶导航栏与吸底固定栏
    case chatRecord      // 微信/聊天模式 (保留首图顶栏与尾图底栏，切除中间图的重叠顶栏与输入框)
    case webArticle      // 网页长文模式 (过滤吸顶网址栏与吸底工具栏)
    case continuousFeed  // 信息流/无固定栏模式 (纯连续重叠滚动)
    case movieSubtitles  // 电影台词拼图 (首图全画幅，后续图仅提取字幕栏叠加)
    case horizontalCompare // 横向对比拼图 (多张图左右排版并列展示)
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .smartAuto:
            return "自动识别"
        case .chatRecord:
            return "微信聊天"
        case .webArticle:
            return "网页文章"
        case .continuousFeed:
            return "长图滚动"
        case .movieSubtitles:
            return "电影台词"
        case .horizontalCompare:
            return "横向对比"
        }
    }
    
    public var correspondingScenario: AppLayoutScenario {
        switch self {
        case .smartAuto: return .generalScroll
        case .chatRecord: return .chatApp
        case .webArticle: return .webArticle
        case .continuousFeed: return .cardFeed
        case .movieSubtitles: return .generalScroll
        case .horizontalCompare: return .generalScroll
        }
    }
    
    public var defaultTopCropInset: CGFloat {
        switch self {
        case .smartAuto, .chatRecord:
            return 88.0 * 3.0 // 264px @3x
        case .webArticle:
            return 96.0 * 3.0 // 288px @3x
        case .continuousFeed, .movieSubtitles, .horizontalCompare:
            return 0.0
        }
    }
    
    public var defaultBottomCropInset: CGFloat {
        switch self {
        case .smartAuto, .chatRecord:
            return 80.0 * 3.0 // 240px @3x
        case .webArticle:
            return 54.0 * 3.0 // 162px @3x
        case .continuousFeed, .movieSubtitles, .horizontalCompare:
            return 0.0
        }
    }
}

public enum StitchCaptureSource: String, Codable {
    case photoLibrary
    case replayKitBroadcast
    case webViewFullPage
}

public struct StitchSession: Codable, Identifiable {
    public var id: UUID
    public var createdAt: Date
    public var source: StitchCaptureSource
    public var presetMode: StitchPresetMode
    public var slices: [StitchItem]
    public var title: String
    public var deviceScreenWidth: CGFloat
    public var deviceScreenScale: CGFloat
    public var hasAppliedDeviceFrame: Bool
    public var sourceAssetIdentifiers: [String]
    
    public var totalEstimatedHeight: CGFloat {
        if presetMode == .horizontalCompare {
            return slices.map { $0.originalHeight }.max() ?? 800
        }
        if presetMode == .movieSubtitles {
            guard let first = slices.first else { return 0 }
            var height = first.originalHeight
            for slice in slices.dropFirst() {
                height += slice.originalHeight * 0.18
            }
            return max(1, height)
        }
        guard let first = slices.first else { return 0 }
        var height = first.visibleHeight
        for slice in slices.dropFirst() {
            height += (slice.visibleHeight - slice.effectiveOverlap)
        }
        return max(1, height)
    }
    
    public var totalEstimatedWidth: CGFloat {
        if presetMode == .horizontalCompare {
            let targetH = totalEstimatedHeight
            var w: CGFloat = 0
            for slice in slices {
                let scale = targetH / max(1, slice.originalHeight)
                w += slice.originalWidth * scale
            }
            return max(1, w + CGFloat(max(0, slices.count - 1)) * 4.0)
        }
        return slices.first?.originalWidth ?? 393
    }
    
    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        source: StitchCaptureSource = .photoLibrary,
        presetMode: StitchPresetMode = .chatRecord,
        slices: [StitchItem] = [],
        title: String = "长截图",
        deviceScreenWidth: CGFloat = 393,
        deviceScreenScale: CGFloat = 3.0,
        hasAppliedDeviceFrame: Bool = false,
        sourceAssetIdentifiers: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.presetMode = presetMode
        self.slices = slices
        self.title = title
        self.deviceScreenWidth = deviceScreenWidth
        self.deviceScreenScale = deviceScreenScale
        self.hasAppliedDeviceFrame = hasAppliedDeviceFrame
        self.sourceAssetIdentifiers = sourceAssetIdentifiers
    }
}
