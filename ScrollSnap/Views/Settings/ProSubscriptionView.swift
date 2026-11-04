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
                        
                        Text("纯粹效率 · 1元永久买断")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        
                        Text("每天免费提供 2 次完整长截图。支付 ¥1.00 即可永久解锁全部效率特权，承诺无任何月费与订阅。")
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
                            title: "微米级机械棘轮微调与接缝能量谱",
                            detail: "滑动物理齿轮旋钮，NCC 互相关波形触觉磁吸最佳接缝"
                        )
                        perkRow(
                            icon: "paintbrush.pointed.fill",
                            tint: .cyan,
                            title: "极光毛玻璃“隐私刮刮乐”涂抹",
                            detail: "告别粗暴黑块，指尖自由刮涂苹果级高斯毛玻璃与像素马赛克"
                        )
                        perkRow(
                            icon: "shield.lefthalf.filled",
                            tint: .yellow,
                            title: "灵动监控岛与微信防糊哨兵",
                            detail: "画幅超万像素智能预警，一键 9 宫格切片拆分防微信压缩"
                        )
                        perkRow(
                            icon: "cube.transparent",
                            tint: .purple,
                            title: "3D 摄影棚悬浮展示海报直出",
                            detail: "钛金属机身 3D 空间倾角旋转，四款棚拍光影一键出社交大片"
                        )
                        perkRow(
                            icon: "text.viewfinder",
                            tint: .indigo,
                            title: "端侧 Vision 视觉引擎与 OCR 离线提取",
                            detail: "Neural Engine 毫秒级离线识别头像与手机号，时序提取全文"
                        )
                        perkRow(
                            icon: "iphone.radiowaves.left.and.right",
                            tint: .blue,
                            title: "15 Pro 操作按钮与轻点背面秒拼",
                            detail: "连按截屏后双击手机背面，0.3 秒无感拼好直接存入剪贴板"
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
                                Text("你已是永久会员，享有全部效率特权")
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
            .navigationTitle("效率特权")
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
