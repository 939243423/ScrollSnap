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
                                .shadow(color: Color.indigo.opacity(0.4), radius: 16, y: 8)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange.opacity(0.2), Color.indigo.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                Image(systemName: "crown.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.orange)
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
                            tint: .orange,
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
                    
                    // Lifetime Perks List with Glass Icon Pods
                    VStack(spacing: 14) {
                        perkRow(
                            icon: "dial.low",
                            tint: .green,
                            title: "接缝微调与放大镜",
                            detail: "滑动刻度滚轮精确微调接缝，配合 2.2x 放大镜精准对齐"
                        )
                        perkRow(
                            icon: "paintbrush.pointed.fill",
                            tint: .cyan,
                            title: "毛玻璃与隐私涂抹",
                            detail: "自由手绘毛玻璃与像素马赛克，自然遮挡敏感信息"
                        )
                        perkRow(
                            icon: "shield.lefthalf.filled",
                            tint: .yellow,
                            title: "超长图预警与九宫格切片",
                            detail: "画幅超长时自动预警，一键拆分为九宫格避免微信画质压缩"
                        )
                        perkRow(
                            icon: "cube.transparent",
                            tint: .purple,
                            title: "3D 样机海报制作",
                            detail: "为长截图套上金属机壳与立体光影，一键导出展示海报"
                        )
                        perkRow(
                            icon: "text.viewfinder",
                            tint: .indigo,
                            title: "文字识别与敏感信息保护",
                            detail: "本地自动识别头像、手机号并支持一键提取全文文本"
                        )
                        perkRow(
                            icon: "iphone.radiowaves.left.and.right",
                            tint: .blue,
                            title: "操作按钮与轻点背面快捷拼图",
                            detail: "连按截屏后轻敲手机背面，自动拼接并存入相册与剪贴板"
                        )
                    }
                    .padding(ScrollSnapTheme.Spacing.lg + 2)
                    .scrollSnapCard(radius: ScrollSnapTheme.Radius.xl)
                    
                    // Purchase Action Block
                    VStack(spacing: 12) {
                        if storeKit.isProUser {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
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
                    self.purchaseErrorMessage = error.localizedDescription
                }
            }
        }
    }
}
