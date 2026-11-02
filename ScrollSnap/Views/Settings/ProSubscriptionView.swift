import SwiftUI
import StoreKit

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
                    // Hero Badge
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange.opacity(0.2), Color.indigo.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 76, height: 76)
                            Image(systemName: "bolt.badge.clock.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.orange)
                                .font(.system(size: 38))
                        }
                        
                        Text("纯粹效率 · 1元永久买断")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        
                        Text("每天免费提供 2 次完整长截图服务。支付 ¥1.00 即可永久解锁全功能与无限使用权，无按月续费订阅。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                    
                    // Daily Free Quota Indicator Card
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.body.bold())
                                .foregroundStyle(Color.accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("今日免费额度")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Text(storeKit.isProUser ? "已解锁永久会员，无任何限制" : "剩余 \(quotaManager.remainingDailyFreeStitches) / \(QuotaManager.defaultDailyLimit) 次（每日 00:00 自动刷新）")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(14)
                    .liquidGlassCard(cornerRadius: 18, strokeOpacity: 0.22)
                    
                    // Lifetime Perks List
                    VStack(spacing: 14) {
                        perkRow(icon: "infinity", title: "无限制无限拼接", detail: "不再受每日 2 次限制，支持万级像素极长滚动录屏")
                        perkRow(icon: "pencil.tip.crop.circle", title: "全套专业标注系统", detail: "红框、矢量箭头、①②③步骤圆圈、荧光笔与文字气泡")
                        perkRow(icon: "square.grid.3x3", title: "小红书九宫格智能断句切片", detail: "自动避开文字正文，等高拆分 3/6/9 宫格一键进相册")
                        perkRow(icon: "iphone.gen3", title: "3D 钛金属外壳与自适应磨砂画板", detail: "原色/黑钛/银白外壳，背景自适应截图高斯模糊")
                        perkRow(icon: "doc.richtext", title: "多页可翻页 PDF 与无损 PNG 导出", detail: "A4 标准分页，阅读与合同归档必备，自动抹除 EXIF 隐私")
                        perkRow(icon: "iphone.radiowaves.left.and.right", title: "操作按钮 & 轻点背面极速拼图", detail: "截屏后双击手机背面或长按 15 Pro 侧键，0.3秒免开 App 拼好")
                    }
                    .padding(18)
                    .liquidGlassCard(cornerRadius: 22, strokeOpacity: 0.28)
                    
                    // ¥1.00 Permanent Buy Button Card
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
                                        Image(systemName: "sparkles")
                                            .font(.body.bold())
                                    }
                                    
                                    Text("支付 ¥1.00 永久买断")
                                        .font(.system(.body, design: .rounded).weight(.bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 0.95, green: 0.42, blue: 0.25), Color(red: 0.92, green: 0.22, blue: 0.35)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Color.orange.opacity(0.35), radius: 12, x: 0, y: 6)
                            }
                            .disabled(isPurchasing)
                        }
                        
                        // Restore Purchases
                        Button("恢复购买") {
                            Task {
                                await storeKit.restorePurchases()
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
    
    private func perkRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 20))
                .frame(width: 24)
            
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
