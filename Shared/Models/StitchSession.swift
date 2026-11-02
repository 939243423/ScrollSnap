import Foundation
import CoreGraphics

public enum StitchPresetMode: String, Codable, CaseIterable, Identifiable {
    case smartAuto       // 自动识别吸顶导航栏与吸底固定栏
    case chatRecord      // 微信/聊天模式 (保留首图顶栏与尾图底栏，切除中间图的重叠顶栏与输入框)
    case webArticle      // 网页长文模式 (过滤吸顶网址栏与吸底工具栏)
    case continuousFeed  // 信息流/无固定栏模式 (纯连续重叠滚动)
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .smartAuto:
            return "智能识别"
        case .chatRecord:
            return "聊天对话"
        case .webArticle:
            return "网页文章"
        case .continuousFeed:
            return "信息瀑布流"
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
    
    public var totalEstimatedHeight: CGFloat {
        guard let first = slices.first else { return 0 }
        var height = first.visibleHeight
        for slice in slices.dropFirst() {
            height += (slice.visibleHeight - slice.effectiveOverlap)
        }
        return max(1, height)
    }
    
    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        source: StitchCaptureSource = .photoLibrary,
        presetMode: StitchPresetMode = .chatRecord,
        slices: [StitchItem] = [],
        title: String = "Stitched Screenshot",
        deviceScreenWidth: CGFloat = 393,
        deviceScreenScale: CGFloat = 3.0,
        hasAppliedDeviceFrame: Bool = false
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
    }
}
