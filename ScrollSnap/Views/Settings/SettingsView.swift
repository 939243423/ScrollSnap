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
    @State private var temporaryCacheBytes: Int64 = 0
    @State private var recentSavesBytes: Int64 = 0
    @State private var isShowingClearRecentAlert = false
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
                            LiquidGlassIconPod(
                                systemName: "star.circle.fill",
                                tint: .accentColor,
                                size: 36,
                                cornerRadius: ScrollSnapTheme.Radius.sm
                            )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(storeKit.isProUser ? "已激活永久会员" : "ScrollSnap 会员")
                                    .font(ScrollSnapTheme.FontToken.itemTitle)
                                    .foregroundStyle(.primary)
                                Text(storeKit.isProUser ? "无限制长截图拼接、打码与切图" : "每日免费 2 次 · ¥1.00 永久买断")
                                    .font(ScrollSnapTheme.FontToken.captionHint)
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
                                    .foregroundStyle(Color.accentColor)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                // Version & Highlights Section
                Section("版本信息") {
                    Button {
                        isShowingWhatsNew = true
                    } label: {
                        HStack {
                            Label {
                                Text("新功能介绍")
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
                    if storeKit.isProUser {
                        Toggle(isOn: Binding(
                            get: { !isWatermarkEnabled },
                            set: { newValue in
                                isWatermarkEnabled = !newValue
                                ExportWatermarkManager.shared.isWatermarkEnabled = !newValue
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("去除导出水印")
                                    .font(.body)
                                Text("导出的长截图干净无底部签名")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button {
                            isShowingProPaywall = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("去除导出水印")
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Text("PRO")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.orange.opacity(0.18))
                                            .foregroundStyle(.orange)
                                            .clipShape(Capsule())
                                    }
                                    Text("当前为免费版，长图底部附带极简签名 · 升级可去除")
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
                    
                    Toggle(isOn: $isSoundEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("按键与操作音效")
                                .font(.body)
                            Text("转动微调滚轮与保存图片时播放声音")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: isSoundEnabled) { _, newValue in
                        SoundEffectManager.shared.isSoundEnabled = newValue
                    }
                }
                
                // Cache & Storage Section
                Section("存储与缓存") {
                    HStack {
                        Text("临时制作缓存")
                        Spacer()
                        Text(formatBytes(temporaryCacheBytes))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("最近保存记录")
                        Spacer()
                        Text(formatBytes(recentSavesBytes))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("清理临时缓存", role: .destructive) {
                        clearTemporaryCache()
                    }
                    
                    if recentSavesBytes > 0 {
                        Button("清空最近保存历史", role: .destructive) {
                            isShowingClearRecentAlert = true
                        }
                    }
                }
                
                #if DEBUG
                // Developer Debug Tools
                Section("开发测试与调试 (Debug)") {
                    HStack {
                        Text("当前会员状态")
                        Spacer()
                        Text(storeKit.isProUser ? "PRO 会员 (已激活)" : "免费版 (未激活)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(storeKit.isProUser ? .green : .secondary)
                    }
                    
                    Button(storeKit.isProUser ? "模拟切换为免费版 (未购买)" : "一键模拟购买 PRO 会员 (本地解锁)") {
                        storeKit.toggleDebugProStatus()
                        HapticFeedbackManager.shared.triggerSuccess()
                    }
                    
                    HStack {
                        Text("今日免费拼图配额")
                        Spacer()
                        Text("\(QuotaManager.shared.remainingDailyFreeStitches) / \(QuotaManager.defaultDailyLimit) 次")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("重置免费拼图额度为满额") {
                        QuotaManager.shared.resetQuotaForTesting()
                        HapticFeedbackManager.shared.triggerSuccess()
                    }
                }
                #endif
                
                // Privacy & Architecture
                Section("隐私与安全") {
                    HStack {
                        Text("离线处理")
                        Spacer()
                        Text("100% 本地运算")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("数据收集")
                        Spacer()
                        Text("无任何上传")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Legal Section
                Section("条款与政策") {
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
            .alert("清空最近保存历史", isPresented: $isShowingClearRecentAlert) {
                Button("清空", role: .destructive) {
                    clearRecentSaves()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("清空后将从首页移除最近保存的长图快捷预览，不会影响系统相册中已保存的照片。")
            }
            .sheet(isPresented: $isShowingShareAppSheet) {
                #if canImport(UIKit)
                if let shareURL = URL(string: "https://apps.apple.com/app/id\(StoreReviewManager.appStoreAppId)") {
                    ShareSheetView(activityItems: ["推荐一款好用的长截图应用 ScrollSnap：", shareURL])
                }
                #endif
            }
            .onAppear {
                calculateCacheSize()
            }
        }
    }
    
    private func calculateCacheSize() {
        let breakdown = AppCacheManager.shared.calculateCacheBreakdown()
        self.temporaryCacheBytes = breakdown.temporaryCacheBytes
        self.recentSavesBytes = breakdown.recentSavesBytes
    }
    
    private func clearTemporaryCache() {
        AppCacheManager.shared.clearTemporaryCache()
        calculateCacheSize()
        HapticFeedbackManager.shared.triggerSuccess()
    }
    
    private func clearRecentSaves() {
        AppCacheManager.shared.clearRecentSaves()
        calculateCacheSize()
        HapticFeedbackManager.shared.triggerSuccess()
        NotificationCenter.default.post(name: NSNotification.Name("RefreshCompletedStitches"), object: nil)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        if bytes == 0 { return "0 MB" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
