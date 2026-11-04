import SwiftUI

/// Apple-grade "What's New" release highlights modal sheet.
/// Conforms strictly to Apple Design Award aesthetics:
/// uncluttered typography, crisp vector SF Symbols, and liquid glass action button.
public struct WhatsNewSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var whatsNewManager = WhatsNewManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    // Header Block
                    VStack(spacing: 12) {
                        Image("AppIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                        
                        VStack(spacing: 4) {
                            Text("新功能介绍")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundStyle(.primary)
                            
                            HStack(spacing: 6) {
                                Text("ScrollSnap")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                
                                ScrollSnapBadge("v\(whatsNewManager.currentVersion)", tint: .accentColor, font: ScrollSnapTheme.FontToken.monoMetric)
                            }
                        }
                    }
                    .padding(.top, 24)
                    
                    // Feature Rows List
                    VStack(spacing: 22) {
                        ForEach(whatsNewManager.features) { feature in
                            HStack(alignment: .top, spacing: 16) {
                                LiquidGlassIconPod(
                                    systemName: feature.iconName,
                                    tint: feature.iconColor,
                                    size: 44,
                                    cornerRadius: ScrollSnapTheme.Radius.sm + 2
                                )
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(feature.title)
                                        .font(ScrollSnapTheme.FontToken.cardTitle)
                                        .foregroundStyle(.primary)
                                    
                                    Text(feature.description)
                                        .font(ScrollSnapTheme.FontToken.bodyText)
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(2)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
            }
            
            // Persistent Bottom Action Dock
            VStack(spacing: 10) {
                Button {
                    HapticFeedbackManager.shared.triggerSnap()
                    whatsNewManager.markCurrentVersionAsSeen()
                    dismiss()
                } label: {
                    Text("继续使用")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScrollSnapButtonStyle.heroPrimary(gradient: ScrollSnapTheme.Colors.primaryGradient))
                
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield")
                        .font(.caption2)
                    Text("本地离线处理 · 不上传数据")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(Color(uiColor: .systemBackground))
        }
    }
}
