import Foundation
import SwiftUI

public struct WhatsNewFeature: Identifiable {
    public let id = UUID()
    public let iconName: String
    public let title: String
    public let description: String
    public let iconColor: Color
    
    public init(iconName: String, title: String, description: String, iconColor: Color) {
        self.iconName = iconName
        self.title = title
        self.description = description
        self.iconColor = iconColor
    }
}

/// Version update highlights manager.
/// Surfaces key features once per release cycle in Apple's signature "What's New" design pattern.
@MainActor
public final class WhatsNewManager: ObservableObject {
    public static let shared = WhatsNewManager()
    
    private let keyLastSeenVersion = "ScrollSnap_WhatsNew_LastSeenVersion"
    
    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    public var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // Key highlights for current major/minor release
    public let features: [WhatsNewFeature] = [
        WhatsNewFeature(
            iconName: "photo.stack",
            title: "微信发图防折叠",
            description: "多张连续聊天或文章截图一键合并为高清长图，彻底解决微信多图自动折叠成卡片的烦恼，好友直接顺畅阅读。",
            iconColor: .accentColor
        ),
        WhatsNewFeature(
            iconName: "rectangle.split.2x1",
            title: "智能动态固定区识别",
            description: "智能识别小红书带视频半屏、微信聊天导航栏与输入框，自动保留首图顶栏与尾图底栏，无损拼接流动内容。",
            iconColor: .accentColor
        ),
        WhatsNewFeature(
            iconName: "arrow.up.and.down",
            title: "微调接缝与放大镜",
            description: "点按接缝标签或滑块微调对齐，配合放大镜实时查看接缝细节，消除任何视觉接缝裂痕。",
            iconColor: .accentColor
        ),
        WhatsNewFeature(
            iconName: "eye.slash",
            title: "一键打码与隐私保护",
            description: "本地自动识别手机号与头像，提供模糊、马赛克与涂黑保护隐私，全程无需联网。",
            iconColor: .accentColor
        )
    ]
    
    private init() {}
    
    /// Determines whether the What's New modal should be presented.
    public func shouldShowWhatsNew() -> Bool {
        let lastSeen = UserDefaults.standard.string(forKey: keyLastSeenVersion)
        return lastSeen != currentVersion
    }
    
    /// Marks the current version as seen so user won't be interrupted again.
    public func markCurrentVersionAsSeen() {
        UserDefaults.standard.set(currentVersion, forKey: keyLastSeenVersion)
    }
}
