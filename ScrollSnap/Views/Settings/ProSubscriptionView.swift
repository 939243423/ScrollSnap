import SwiftUI
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

public struct ProSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = StoreKitManager.shared
    @StateObject private var quotaManager = QuotaManager.shared
    @State private var isPurchasing = false
    @State private var purchaseErrorMessage: String?
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Mascot Badge
                    VStack(spacing: 12) {
                        #if canImport(UIKit)
                        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
                           let uiImage = UIImage(contentsOfFile: iconPath) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 84, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: ScrollSnapTheme.Colors.brandAccent.opacity(0.28), radius: 16, y: 8)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.12))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "checkmark.seal.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.accentColor)
                                    .font(.system(size: 38))
                            }
                        }
                        #endif
                        
                        Text("ScrollSnap Pro 永久买断")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        
                        Text("每天免费提供 2 次拼图额度。支付 ¥1.00 永久解锁全部功能，无任何订阅费。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                    
                    // Daily Free Quota Indicator Card
                    HStack(spacing: 14) {
                        LiquidGlassIconPod(
                            systemName: "clock.arrow.circlepath",
                            tint: .accentColor,
                            size: 40,
                            cornerRadius: ScrollSnapTheme.Radius.sm
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("今日免费额度")
                                .font(ScrollSnapTheme.FontToken.itemTitle)
                            Text(storeKit.isProUser ? "已解锁永久会员，无任何限制" : "剩余 \(quotaManager.remainingDailyFreeStitches) / \(QuotaManager.defaultDailyLimit) 次（每日 00:00 自动刷新）")
                                .font(ScrollSnapTheme.FontToken.captionHint)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(ScrollSnapTheme.Spacing.md + 2)
                    .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg)
                    
                    // Lifetime Perks List with Clean Unified Icons
                    VStack(spacing: 14) {
                        perkRow(
                            icon: "photo.on.rectangle.angled",
                            tint: .accentColor,
                            title: "无限长截图拼接",
                            detail: "每日不限拼图次数，支持超长无损长截图导出"
                        )
                        perkRow(
                            icon: "arrow.up.and.down",
                            tint: .accentColor,
                            title: "接缝微调与放大镜",
                            detail: "滑动微调接缝位置，配合放大镜精准对齐"
                        )
                        perkRow(
                            icon: "eye.slash",
                            tint: .accentColor,
                            title: "自由打码与画笔标注",
                            detail: "自由手绘模糊、马赛克、涂黑遮挡与箭头文字批注"
                        )
                        perkRow(
                            icon: "square.grid.3x3",
                            tint: .accentColor,
                            title: "九宫格社交切图",
                            detail: "长图一键切九宫格，微信朋友圈与小红书免压缩发图"
                        )
                    }
                    .padding(ScrollSnapTheme.Spacing.lg + 2)
                    .scrollSnapCard(radius: ScrollSnapTheme.Radius.xl)
                    
                    // Purchase Action Block
                    VStack(spacing: 12) {
                        if storeKit.isProUser {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.accentColor)
                                Text("已解锁全部功能")
                                    .font(.subheadline.bold())
                            }
                            .padding(.vertical, 8)
                        } else {
                            Button {
                                executeLifetimePurchase()
                            } label: {
                                HStack(spacing: 10) {
                                    if isPurchasing {
                                        ProgressView()
                                            .tint(.white)
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.body.bold())
                                    }
                                    
                                    Text("支付 ¥1.00 永久买断")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ScrollSnapButtonStyle.heroPrimary(gradient: ScrollSnapTheme.Colors.proGoldGradient))
                            .disabled(isPurchasing)
                        }
                        
                        // Restore Purchases
                        Button("恢复购买 (Restore Purchases)") {
                            Task {
                                await storeKit.restorePurchases()
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        
                        #if DEBUG
                        // Developer Quick Unlock for Testing
                        Button("开发测试：一键模拟解锁 PRO") {
                            storeKit.unlockLocally()
                            HapticFeedbackManager.shared.triggerSuccess()
                            dismiss()
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                        #endif
                        
                        // Legal Links (App Store Guideline 3.1.2 Compliance)
                        HStack(spacing: 14) {
                            Link("隐私政策", destination: URL(string: "https://939243423.github.io/protocol__ScrollSnap/privacy.html")!)
                            Text("·")
                            Link("服务条款与 EULA", destination: URL(string: "https://939243423.github.io/protocol__ScrollSnap/terms.html")!)
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("ScrollSnap Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func perkRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            LiquidGlassIconPod(
                systemName: icon,
                tint: tint,
                size: 34,
                cornerRadius: 10
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    
    private func executeLifetimePurchase() {
        isPurchasing = true
        Task {
            do {
                let success = try await storeKit.purchaseLifetimeUnlock()
                await MainActor.run {
                    self.isPurchasing = false
                    if success {
                        HapticFeedbackManager.shared.triggerSnap()
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isPurchasing = false
                    #if DEBUG
                    // 调试环境下内购未配置时自动兜底本地解锁，避免卡住
                    storeKit.unlockLocally()
                    HapticFeedbackManager.shared.triggerSnap()
                    dismiss()
                    #else
                    self.purchaseErrorMessage = "购买未完成，请重试"
                    #endif
                }
            }
        }
    }
}
