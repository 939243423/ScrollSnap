import SwiftUI

public struct LiquidBrushRedactionView: View {
    @Binding public var strokes: [RedactionStroke]
    @Binding public var activeBrush: RedactionBrushType
    @Binding public var brushWidth: CGFloat
    
    @State private var currentPoints: [CGPoint] = []
    
    public init(
        strokes: Binding<[RedactionStroke]>,
        activeBrush: Binding<RedactionBrushType>,
        brushWidth: Binding<CGFloat>
    ) {
        self._strokes = strokes
        self._activeBrush = activeBrush
        self._brushWidth = brushWidth
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Brush Bar Controls
            HStack(spacing: 8) {
                // Brush Type Switcher
                ForEach(RedactionBrushType.allCases) { brush in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                            activeBrush = brush
                        }
                        HapticFeedbackManager.shared.triggerSelection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: brush.iconName)
                            Text(brush.rawValue)
                        }
                        .font(.caption2.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(activeBrush == brush ? Color.accentColor : Color.white.opacity(0.08))
                        )
                        .foregroundStyle(activeBrush == brush ? Color.white : Color.primary)
                    }
                    .buttonStyle(ScrollSnapButtonStyle.bouncy)
                }
                
                Spacer()
                
                // Undo Button with Spring Bounce
                Button {
                    if !strokes.isEmpty {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                            strokes.removeLast()
                        }
                        HapticFeedbackManager.shared.triggerSelection()
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(strokes.isEmpty ? Color.gray.opacity(0.3) : Color.white)
                }
                .disabled(strokes.isEmpty)
                .buttonStyle(ScrollSnapButtonStyle.bouncy)
                
                // Clear All Button with Warning Haptic
                Button {
                    if !strokes.isEmpty {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            strokes.removeAll()
                        }
                        HapticFeedbackManager.shared.triggerWarning()
                    }
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(strokes.isEmpty ? Color.gray.opacity(0.3) : Color.red.opacity(0.85))
                }
                .disabled(strokes.isEmpty)
                .buttonStyle(ScrollSnapButtonStyle.bouncy)
            }
            .padding(.horizontal, 4)
            
            // Brush Width Quick Selector
            HStack(spacing: 12) {
                Text("笔刷粗细")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                ForEach([16.0, 28.0, 44.0], id: \.self) { size in
                    Button {
                        brushWidth = size
                        HapticFeedbackManager.shared.triggerSelection()
                    } label: {
                        Circle()
                            .fill(brushWidth == size ? Color.white : Color.gray.opacity(0.4))
                            .frame(width: size * 0.45, height: size * 0.45)
                            .padding(6)
                            .background(
                                Circle()
                                    .strokeBorder(brushWidth == size ? Color.accentColor : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Text("\(strokes.count) 处涂抹遮蔽")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 18)
    }
}
