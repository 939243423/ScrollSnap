import Foundation
import AppIntents
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

public struct CopyRecentStitchIntent: AppIntent {
    public static var title: LocalizedStringResource = "复制最新长截图"
    public static var description = IntentDescription("直接复制最新拼接的长截图至系统剪贴板")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        #if canImport(UIKit)
        if let dir = AppGroupConstants.completedStitchesDirectory,
           let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]),
           let latest = items.sorted(by: { ($0.path) > ($1.path) }).first,
           let image = UIImage(contentsOfFile: latest.path) {
            await MainActor.run {
                UIPasteboard.general.image = image
            }
        }
        #endif
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "RecentStitchWidget")
        #endif
        return .result()
    }
}

public struct DiscardActiveSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "放弃当前截屏"
    public static var description = IntentDescription("清空正在录制或暂存的切片草稿")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        SharedStore.shared.resetActiveBroadcastSession()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "RecentStitchWidget")
        #endif
        return .result()
    }
}
