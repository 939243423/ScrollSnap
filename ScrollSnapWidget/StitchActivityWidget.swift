import WidgetKit
import SwiftUI
import ActivityKit

public struct StitchActivityWidget: Widget {
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: StitchActivityAttributes.self) { context in
            // Lock Screen Live Activity banner
            LockScreenActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Leading
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.viewfinder")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.accentColor)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.captureTitle)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(context.state.statusText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 8)
                }
                
                // Expanded Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("\(context.state.frameCount)")
                                .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                            Text("屏")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(context.state.capturedHeightPx) px")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.trailing, 8)
                }
                
                // Expanded Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        Button(intent: DiscardActiveSessionIntent()) {
                            Label("放弃", systemImage: "xmark.circle.fill")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Text("录屏结束后打开 App 自动拼合")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "camera.viewfinder")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                    .font(.caption)
            } compactTrailing: {
                Text("\(context.state.frameCount)屏")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
            } minimal: {
                Image(systemName: "photo.stack")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenActivityView: View {
    let context: ActivityViewContext<StitchActivityAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "camera.viewfinder")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.captureTitle)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                Text(context.state.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(context.state.frameCount)")
                        .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                    Text("切片")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("\(context.state.capturedHeightPx) px")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
    }
}
