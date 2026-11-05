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
            iconName: "photo.on.rectangle.angled",
            title: "自动拼接长图",
            description: "从相册选图或通过录屏直接截取，自动计算重叠并精准拼合为高清长图。",
            iconColor: .blue
        ),
        WhatsNewFeature(
            iconName: "arrow.up.and.down",
            title: "微调接缝",
            description: "点按接缝标签或滑块微调对齐，支持放大镜实时查看接缝细节。",
            iconColor: .orange
        ),
        WhatsNewFeature(
            iconName: "eye.slash",
            title: "一键打码遮挡",
            description: "本地自动识别手机号与头像，提供模糊、马赛克与涂黑保护隐私。",
            iconColor: .indigo
        ),
        WhatsNewFeature(
            iconName: "square.grid.3x3",
            title: "切图与批注",
            description: "自由将长图切分为 3/6/9 宫格存入相册，支持箭头矩形批注与提取长图文字。",
            iconColor: .teal
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
