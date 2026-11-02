import Foundation
import AppIntents
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Photos)
import Photos
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - 1. 快捷复制最新长截图

public struct CopyRecentStitchIntent: AppIntent {
    public static var title: LocalizedStringResource = "复制最新长截图"
    public static var description = IntentDescription("直接复制最新拼接的长截图至系统剪贴板")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        #if canImport(UIKit)
        if let dir = AppGroupConstants.completedStitchesDirectory,
           let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]),
           let latest = items.sorted(by: { ($0.path) > ($1.path) }).first,
           let image = UIImage(contentsOfFile: latest.path) {
            await MainActor.run {
                UIPasteboard.general.image = image
            }
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: "RecentStitchWidget")
            #endif
            return .result(value: "已将最新长截图复制到剪贴板！")
        }
        #endif
        
        return .result(value: "未找到历史长截图")
    }
}

// MARK: - 2. 智能拼合最近连续截屏 (支持操作按钮 Action Button & 轻点背面 Back Tap)

public struct QuickStitchRecentScreenshotsIntent: AppIntent {
    public static var title: LocalizedStringResource = "智能拼合最近截图并复制"
    public static var description = IntentDescription("自动扫描 5 分钟内的连续截屏，完成智能拼接并直接存入剪贴板")
    
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        #if canImport(Photos) && canImport(UIKit)
        // 1. 优先检查是否存在未完成的录屏广播切片
        let broadcastSlices = SharedStore.shared.listActiveBroadcastSlicePaths()
        if broadcastSlices.count >= 2 {
            let session = try await StitchEngine.shared.stitchSlices(
                fileRelativePaths: broadcastSlices,
                source: .replayKitBroadcast,
                presetMode: .chatRecord
            )
            
            if let dir = AppGroupConstants.completedStitchesDirectory {
                let outURL = dir.appendingPathComponent("Stitch_Broadcast_\(Int(Date().timeIntervalSince1970)).jpg")
                try TiledImageRenderer.renderStitchedImageToFile(session: session, outputURL: outURL)
                
                if let image = UIImage(contentsOfFile: outURL.path) {
                    await MainActor.run {
                        UIPasteboard.general.image = image
                    }
                }
                SharedStore.shared.resetActiveBroadcastSession()
                SharedStore.shared.notifyWidgetReloadDebounced()
                return .result(dialog: "已自动拼合 \(broadcastSlices.count) 屏录屏内容并复制到剪贴板！")
            }
        }
        
        // 2. 扫描相册中 5 分钟内的连续截屏
        let cutoff = Date().addingTimeInterval(-5 * 60)
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@ AND (mediaSubtypes & %d) != 0",
            PHAssetMediaType.image.rawValue,
            cutoff as NSDate,
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        guard assets.count >= 2 else {
            return .result(dialog: "未检测到 5 分钟内的多张连续截图，请先截屏后再试。")
        }
        
        var paths: [String] = []
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        
        for i in 0..<assets.count {
            let asset = assets.object(at: i)
            manager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                if let data = data,
                   let savedPath = SharedStore.shared.writeBroadcastSlice(data: data, index: i) {
                    paths.append(savedPath)
                }
            }
        }
        
        guard paths.count >= 2 else {
            return .result(dialog: "切片提取失败，请检查相册访问权限。")
        }
        
        let session = try await StitchEngine.shared.stitchSlices(
            fileRelativePaths: paths,
            source: .photoLibrary,
            presetMode: .chatRecord
        )
        
        if let dir = AppGroupConstants.completedStitchesDirectory {
            let outURL = dir.appendingPathComponent("Stitch_Quick_\(Int(Date().timeIntervalSince1970)).jpg")
            try TiledImageRenderer.renderStitchedImageToFile(session: session, outputURL: outURL)
            
            if let image = UIImage(contentsOfFile: outURL.path) {
                await MainActor.run {
                    UIPasteboard.general.image = image
                }
            }
            SharedStore.shared.notifyWidgetReloadDebounced()
            return .result(dialog: "已智能拼合 \(paths.count) 张截屏并存入剪贴板，可直接粘贴！")
        }
        #endif
        
        return .result(dialog: "长截图生成失败")
    }
}

// MARK: - 3. 放弃录屏或重置切片

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

// MARK: - 4. 系统 App Shortcuts 暴露中心 (供操作按钮/轻点背面自动发现)

public struct ScrollSnapShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickStitchRecentScreenshotsIntent(),
            phrases: [
                "用 \(.applicationName) 智能拼合长截图",
                "用 \(.applicationName) 拼合最近截图",
                "拼合最近长截图"
            ],
            shortTitle: "一键拼合长截图",
            systemImageName: "camera.viewfinder"
        )
        AppShortcut(
            intent: CopyRecentStitchIntent(),
            phrases: [
                "复制 \(.applicationName) 最新长截图",
                "复制最新长截图"
            ],
            shortTitle: "复制最新长截图",
            systemImageName: "doc.on.doc.fill"
        )
    }
}
