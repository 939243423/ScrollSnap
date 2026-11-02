import SwiftUI
import StoreKit

public struct ProSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = StoreKitManager.shared
    @State private var isPurchasing = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Crown Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "crown.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.accentColor)
                                .font(.system(size: 36))
                        }
                        
                        Text("升级至 ScrollSnap Pro")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        
                        Text("解锁无限超长拼接、原始 Retina 无损导出与 3D 钛金属带壳展台")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 16)
                    
                    // Features List
                    VStack(spacing: 14) {
                        featureRow(icon: "infinity", title: "无限切片拼接", detail: "免费版限 8 屏，Pro 版支持无上限长篇滚动截屏")
                        featureRow(icon: "sparkles", title: "无损 Retina 原始分辨率导出", detail: "保持 3x 原生像素导出，排版字体纤毫毕现")
                        featureRow(icon: "iphone.gen3", title: "3D 物理级钛金属带壳", detail: "为长截图套上拟真 iPhone 边框与精致阴影")
                        featureRow(icon: "checkerboard.shield", title: "非破坏性马赛克脱敏", detail: "支持像素马赛克与纯黑打码，保护头像与隐私")
                    }
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    
                    // Pricing Cards
                    VStack(spacing: 12) {
                        ForEach(storeKit.availableProducts) { product in
                            Button {
                                purchaseProduct(product)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.displayName)
                                            .font(.system(.body, design: .rounded).weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(product.description)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(product.displayPrice)
                                        .font(.system(.headline, design: .rounded).weight(.bold))
                                        .foregroundStyle(.tint)
                                }
                                .padding(16)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Restore Purchases
                    Button("恢复已购买项目") {
                        Task {
                            await storeKit.restorePurchases()
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("会员权益")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                await storeKit.fetchProducts()
            }
        }
    }
    
    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .font(.title3)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    
    private func purchaseProduct(_ product: Product) {
        isPurchasing = true
        Task {
            let success = (try? await storeKit.purchase(product: product)) ?? false
            isPurchasing = false
            if success {
                HapticFeedbackManager.shared.triggerSuccess()
                dismiss()
            }
        }
    }
}
