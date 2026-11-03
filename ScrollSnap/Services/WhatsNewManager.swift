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
            title: "双目无缝对比帘幕",
            description: "推拉高精度激光游标，左侧原片与右侧拼合无缝比对，毫厘之间洞悉亚像素对齐质量。",
            iconColor: .indigo
        ),
        WhatsNewFeature(
            iconName: "dial.medium.fill",
            title: "微米级机械棘轮微调",
            description: "转动触觉阻尼滚轮实现 0.5px 精细微调，伴随清脆齿轮震颤与自动翡翠绿磁吸锁定。",
            iconColor: .orange
        ),
        WhatsNewFeature(
            iconName: "cube.transparent",
            title: "3D 摄影棚海报直出",
            description: "配备沙漠钛等四款苹果旗舰边框，自由倾斜空间角度与地面接触阴影，一键输出 4K 大片。",
            iconColor: .purple
        ),
        WhatsNewFeature(
            iconName: "shield.checkerboard",
            title: "端侧脱敏与极光毛玻璃",
            description: "Neural Engine 毫秒级离线识别头像与手机号码，支持如同刮刮乐般的手绘毛玻璃涂抹保护。",
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
