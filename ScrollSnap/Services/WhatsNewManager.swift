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
            iconName: "square.split.2x1",
            title: "拼图前后对比",
            description: "滑动屏幕中线，直观对比原截图与去重拼接后的长图效果。",
            iconColor: .indigo
        ),
        WhatsNewFeature(
            iconName: "dial.medium.fill",
            title: "接缝微调与放大镜",
            description: "转动滚轮或直接拖拽接缝微调对齐，支持 2.2x 放大镜精准查看像素咬合。",
            iconColor: .orange
        ),
        WhatsNewFeature(
            iconName: "cube.transparent",
            title: "3D 样机海报",
            description: "支持多种金属机身外壳与背景渐变，一键导出带壳长截图展示海报。",
            iconColor: .purple
        ),
        WhatsNewFeature(
            iconName: "shield.checkerboard",
            title: "隐私涂抹保护",
            description: "本地自动识别头像与手机号码，支持手绘毛玻璃或马赛克遮挡敏感内容。",
            iconColor: .blue
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
