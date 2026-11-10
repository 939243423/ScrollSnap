import SwiftUI

public struct LiquidBrushRedactionView: View {
    @Binding public var shapeMode: RedactionShapeMode
    @Binding public var styleChoice: RedactionStyleChoice
    @Binding public var brushWidth: CGFloat
    @Binding public var interactionMode: CanvasInteractionMode
    @Binding public var strokes: [RedactionStroke]
    @Binding public var annotations: [AnnotationItem]
    public var onAutoSanitize: (() -> Void)?
    public var isSanitizing: Bool
    @State private var isShowingClearAlert: Bool = false
    
    public init(
        shapeMode: Binding<RedactionShapeMode>,
        styleChoice: Binding<RedactionStyleChoice>,
        brushWidth: Binding<CGFloat>,
        interactionMode: Binding<CanvasInteractionMode>,
        strokes: Binding<[RedactionStroke]>,
        annotations: Binding<[AnnotationItem]>,
        onAutoSanitize: (() -> Void)? = nil,
        isSanitizing: Bool = false
    ) {
        self._shapeMode = shapeMode
        self._styleChoice = styleChoice
        self._brushWidth = brushWidth
        self._interactionMode = interactionMode
        self._strokes = strokes
        self._annotations = annotations
        self.onAutoSanitize = onAutoSanitize
        self.isSanitizing = isSanitizing
    }
    
    private var totalRedactionsCount: Int {
        let mosaicAnnotations = annotations.filter { $0.kind == .mosaic }.count
        return strokes.count + mosaicAnnotations
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            // Row 1: Mode Switcher (Draw vs Browse) & Actions
            HStack(spacing: 8) {
                // Draw vs Browse Segmented Pill
                HStack(spacing: 2) {
                    Button {
                        interactionMode = .draw
                        HapticFeedbackManager.shared.triggerSelection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.tip.crop.circle")
                            Text("遮挡")
                        }
                        .font(.system(size: 11, weight: interactionMode == .draw ? .bold : .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            interactionMode == .draw
                            ? Color.accentColor
                            : Color.clear
                        )
                        .foregroundStyle(interactionMode == .draw ? Color.white : Color.secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        interactionMode = .browse
                        HapticFeedbackManager.shared.triggerSelection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.draw")
                            Text("移动")
                        }
                        .font(.system(size: 11, weight: interactionMode == .browse ? .bold : .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            interactionMode == .browse
                            ? Color.accentColor
                            : Color.clear
                        )
                        .foregroundStyle(interactionMode == .browse ? Color.white : Color.secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(3)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
                
                Spacer()
                
                // One-tap Auto Privacy Detection
                if let onAutoSanitize = onAutoSanitize {
                    Button {
                        onAutoSanitize()
                    } label: {
                        HStack(spacing: 4) {
                            if isSanitizing {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "shield.checkerboard")
                            }
                            Text("自动打码")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.14))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .disabled(isSanitizing)
                    .buttonStyle(ScrollSnapButtonStyle.bouncy)
                }
                
                // Undo Button
                Button {
                    handleUndo()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(totalRedactionsCount == 0 ? Color.secondary.opacity(0.3) : Color.primary)
                }
                .disabled(totalRedactionsCount == 0)
                .buttonStyle(ScrollSnapButtonStyle.bouncy)
                
                // Clear All Button
                Button {
                    isShowingClearAlert = true
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(totalRedactionsCount == 0 ? Color.secondary.opacity(0.3) : Color.red.opacity(0.85))
                }
                .disabled(totalRedactionsCount == 0)
                .buttonStyle(ScrollSnapButtonStyle.bouncy)
                .alert("清除所有遮挡？", isPresented: $isShowingClearAlert) {
                    Button("清除", role: .destructive) {
                        handleClearAll()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("此操作将移除当前长图中的所有马赛克、模糊与涂黑遮挡。")
                }
            }
            .padding(.horizontal, 4)
            
            Divider().opacity(0.4)
            
            // Row 2: Shape Mode (Box vs Brush) & Style Choice (Mosaic vs Blur vs Blackout)
            HStack(spacing: 12) {
                // Shape Mode
                HStack(spacing: 4) {
                    ForEach(RedactionShapeMode.allCases) { mode in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                shapeMode = mode
                                interactionMode = .draw
                            }
                            HapticFeedbackManager.shared.triggerSelection()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: mode.iconName)
                                Text(mode.rawValue)
                            }
                            .font(.system(size: 12, weight: shapeMode == mode ? .bold : .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(shapeMode == mode ? Color.accentColor : Color.primary.opacity(0.08))
                            .foregroundStyle(shapeMode == mode ? Color.white : Color.primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Style Selector (Mosaic, Blur, Blackout)
                HStack(spacing: 6) {
                    ForEach(RedactionStyleChoice.allCases) { style in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                styleChoice = style
                            }
                            HapticFeedbackManager.shared.triggerSelection()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: style.iconName)
                                    .font(.system(size: 10))
                                Text(style.rawValue)
                                    .font(.system(size: 11, weight: styleChoice == style ? .bold : .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(styleChoice == style ? Color.primary.opacity(0.18) : Color.clear)
                            .foregroundStyle(styleChoice == style ? Color.accentColor : Color.secondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // Row 3: Brush/Box Thickness Selector & Count
            HStack(spacing: 12) {
                Text("粗细")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                ForEach([16.0, 28.0, 44.0], id: \.self) { size in
                    Button {
                        brushWidth = size
                        HapticFeedbackManager.shared.triggerSelection()
                    } label: {
                        Circle()
                            .fill(brushWidth == size ? Color.accentColor : Color.gray.opacity(0.35))
                            .frame(width: size * 0.45, height: size * 0.45)
                            .padding(4)
                            .background(
                                Circle()
                                    .strokeBorder(brushWidth == size ? Color.accentColor : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                if totalRedactionsCount > 0 {
                    Text("已遮挡 \(totalRedactionsCount) 处")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .liquidGlassCard(cornerRadius: 18)
    }
    
    private func handleUndo() {
        if shapeMode == .brush && !strokes.isEmpty {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                _ = strokes.removeLast()
            }
            HapticFeedbackManager.shared.triggerSelection()
        } else if let lastMosaicIdx = annotations.lastIndex(where: { $0.kind == .mosaic }) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                _ = annotations.remove(at: lastMosaicIdx)
            }
            HapticFeedbackManager.shared.triggerSelection()
        } else if !strokes.isEmpty {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                _ = strokes.removeLast()
            }
            HapticFeedbackManager.shared.triggerSelection()
        }
    }
    
    private func handleClearAll() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            strokes.removeAll()
            annotations.removeAll(where: { $0.kind == .mosaic })
        }
        HapticFeedbackManager.shared.triggerWarning()
    }
}
