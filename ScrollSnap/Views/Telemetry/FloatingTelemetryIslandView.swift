import SwiftUI

public struct FloatingTelemetryIslandView: View {
    public let canvasWidth: Int
    public let canvasHeight: Int
    public let memoryUsageMB: Double
    public let memoryLimitMB: Double
    
    @State private var isExpanded: Bool = false
    @State private var weChatSafeguardEnabled: Bool = true
    
    public init(
        canvasWidth: Int = 1170,
        canvasHeight: Int = 14890,
        memoryUsageMB: Double = 34.2,
        memoryLimitMB: Double = 50.0
    ) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.memoryUsageMB = memoryUsageMB
        self.memoryLimitMB = memoryLimitMB
    }
    
    private var isWeChatRisk: Bool {
        canvasHeight > 10000
    }
    
    private var memoryRatio: Double {
        min(max(memoryUsageMB / memoryLimitMB, 0.0), 1.0)
    }
    
    private var memoryColor: Color {
        if memoryRatio < 0.65 {
            return Color.green
        } else if memoryRatio < 0.85 {
            return Color.orange
        } else {
            return Color.red
        }
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Main Floating Capsule Pill
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    isExpanded.toggle()
                }
                HapticFeedbackManager.shared.triggerSelection()
            } label: {
                HStack(spacing: 8) {
                    // Resolution Tag
                    HStack(spacing: 4) {
                        Image(systemName: "aspectratio")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cyan)
                        Text("\(canvasWidth) × \(canvasHeight)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    
                    // Separator Dot
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 3, height: 3)
                    
                    // Memory Gauge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(memoryColor)
                            .frame(width: 6, height: 6)
                            .shadow(color: memoryColor.opacity(0.6), radius: 3)
                        Text(String(format: "%.1f MB", memoryUsageMB))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    
                    // WeChat Warning Pill if tall
                    if isWeChatRisk {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.yellow)
                            Text("微信防糊")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.yellow)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.yellow.opacity(0.18)))
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .liquidGlassPill()
            }
            .buttonStyle(.plain)
            
            // Expanded Telemetry Matrix Sheet
            if isExpanded {
                VStack(spacing: 12) {
                    // Memory Progress Bar
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("离线渲染内存安全水位")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f / %.0f MB (安全)", memoryUsageMB, memoryLimitMB))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(memoryColor)
                        }
                        
                        GeometryReader { barProxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.1))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [memoryColor.opacity(0.7), memoryColor],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: barProxy.size.width * memoryRatio)
                            }
                        }
                        .frame(height: 5)
                    }
                    
                    Divider().overlay(Color.white.opacity(0.1))
                    
                    // WeChat Compression Advice
                    if isWeChatRisk {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                                .foregroundStyle(Color.yellow)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("微信超长图压缩预警")
                                    .font(.caption.bold())
                                Text("画幅超过 10,000px，微信直接发送会自动二压导致文字模糊。建议启用智能分片或限制长边。")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.yellow.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.yellow.opacity(0.2), lineWidth: 0.8)
                                )
                        )
                    }
                    
                    // Technical Specs Grid
                    HStack(spacing: 16) {
                        specItem(title: "色彩空间", value: "Display P3")
                        specItem(title: "渲染瓦片", value: "\(Int(ceil(Double(canvasHeight) / 2048.0))) 块切片")
                        specItem(title: "无损保真", value: "100% 本地")
                    }
                }
                .padding(14)
                .liquidGlassCard(cornerRadius: 18)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                ))
            }
        }
    }
    
    private func specItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced).bold())
        }
        .frame(maxWidth: .infinity)
    }
}
