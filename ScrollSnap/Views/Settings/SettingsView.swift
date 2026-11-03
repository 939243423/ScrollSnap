import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = StoreKitManager.shared
    @StateObject private var storeReview = StoreReviewManager.shared
    @StateObject private var whatsNew = WhatsNewManager.shared
    
    @State private var isShowingProPaywall = false
    @State private var isShowingWhatsNew = false
    @State private var isShowingShareAppSheet = false
    @State private var cacheSizeBytes: Int = 0
    @State private var isWatermarkEnabled: Bool = ExportWatermarkManager.shared.isWatermarkEnabled
    @State private var isSoundEnabled: Bool = SoundEffectManager.shared.isSoundEnabled
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Subscription Section
                Section {
                    Button {
                        isShowingProPaywall = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "crown.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.accentColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(storeKit.isProUser ? "已激活 ¥1 永久特权" : "纯粹效率 · 1元永久买断")
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(storeKit.isProUser ? "享有无限制拼图、隐私脱敏保护与9宫格切片" : "每日免费 2 次 · ¥1.00 永久买断")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                // Rating & Community Growth (App Store Ranking Driver)
                Section("支持与互动") {
                    Button {
                        storeReview.openAppStoreReviewPage()
                    } label: {
                        HStack {
                            Label {
                                Text("在 App Store 给予五星好评")
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.orange)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Button {
                        storeReview.sendFeedbackEmail()
                    } label: {
                        HStack {
                            Label {
                                Text("建议与问题反馈")
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "envelope.fill")
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            Text(StoreReviewManager.developerEmail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        isShowingShareAppSheet = true
                    } label: {
                        HStack {
                            Label {
                                Text("推荐 ScrollSnap 给朋友")
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.green)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                // Version & Highlights Section
                Section("版本更新与特性") {
                    Button {
                        isShowingWhatsNew = true
                    } label: {
                        HStack {
                            Label {
                                Text("新功能介绍与升级日志")
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "newspaper.fill")
                                    .foregroundStyle(.purple)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    HStack {
                        Label {
                            Text("当前版本")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        Text("\(whatsNew.currentVersion) (\(whatsNew.currentBuild))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Export & Haptic Preferences
                Section("导出与交互偏好") {
                    Toggle(isOn: $isWatermarkEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("极简品牌水印")
                                    .font(.body)
                                if !storeKit.isProUser {
                                    Text("PRO")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.orange.opacity(0.18))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                            }
                            Text("长图底部附带极简无扰签名，帮助传播发现")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: isWatermarkEnabled) { _, newValue in
                        if !storeKit.isProUser && !newValue {
                            // Non-Pro users cannot disable watermark
                            isWatermarkEnabled = true
                            isShowingProPaywall = true
                        } else {
                            ExportWatermarkManager.shared.isWatermarkEnabled = newValue
                        }
                    }
                    
                    Toggle(isOn: $isSoundEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("机械棘轮与相机音效")
                                .font(.body)
                            Text("转动微调旋钮与保存拼合时播放清脆声效")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: isSoundEnabled) { _, newValue in
                        SoundEffectManager.shared.isSoundEnabled = newValue
                    }
                }
                
                // Cache & Storage Section
                Section("缓存与存储") {
                    HStack {
                        Text("长截图临时缓存")
                        Spacer()
                        Text(formatBytes(cacheSizeBytes))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("清理全部切片缓存", role: .destructive) {
                        clearCache()
                    }
                }
                
                // Privacy & Architecture
                Section("隐私与架构安全") {
                    HStack {
                        Text("端侧离线计算")
                        Spacer()
                        Text("100% 本地运算")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("隐私上报")
                        Spacer()
                        Text("零数据收集")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("算法内核")
                        Spacer()
                        Text("CoreGraphics NCC + Metal")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Legal Section
                Section("法律协议与合规") {
                    Link(destination: URL(string: "https://939243423.github.io/protocol__ScrollSnap/privacy.html")!) {
                        HStack {
                            Text("隐私政策 (Privacy Policy)")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://939243423.github.io/protocol__ScrollSnap/terms.html")!) {
                        HStack {
                            Text("用户服务协议与 EULA (Terms)")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://939243423.github.io/protocol__ScrollSnap/")!) {
                        HStack {
                            Text("合规与政策中心")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingProPaywall) {
                ProSubscriptionView()
            }
            .sheet(isPresented: $isShowingWhatsNew) {
                WhatsNewSheetView()
            }
            .sheet(isPresented: $isShowingShareAppSheet) {
                #if canImport(UIKit)
                if let shareURL = URL(string: "https://apps.apple.com/app/id\(StoreReviewManager.appStoreAppId)") {
                    ShareSheetView(activityItems: ["推荐一款纯端侧高颜值的长截图神器：ScrollSnap 滚动画布", shareURL])
                }
                #endif
            }
            .onAppear {
                calculateCacheSize()
            }
        }
    }
    
    private func calculateCacheSize() {
        guard let container = AppGroupConstants.containerURL else { return }
        var total = 0
        if let enumerator = FileManager.default.enumerator(at: container, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resource = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let size = resource.fileSize {
                    total += size
                }
            }
        }
        self.cacheSizeBytes = total
    }
    
    private func clearCache() {
        SharedStore.shared.resetActiveBroadcastSession()
        calculateCacheSize()
        HapticFeedbackManager.shared.triggerSuccess()
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
