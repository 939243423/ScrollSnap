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
                            Text("全新功能与特性")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundStyle(.primary)
                            
                            HStack(spacing: 6) {
                                Text("滚动画布 ScrollSnap")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                
                                Text("v\(whatsNewManager.currentVersion)")
                                    .font(.caption2.weight(.bold).monospacedDigit())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.top, 24)
                    
                    // Feature Rows List
                    VStack(spacing: 22) {
                        ForEach(whatsNewManager.features) { feature in
                            HStack(alignment: .top, spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(feature.iconColor.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: feature.iconName)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(feature.iconColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(feature.title)
                                        .font(.system(.body, design: .rounded).weight(.bold))
                                        .foregroundStyle(.primary)
                                    
                                    Text(feature.description)
                                        .font(.system(.footnote))
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
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield")
                        .font(.caption2)
                    Text("100% 纯端侧离线运算 · 零网络追踪")
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
