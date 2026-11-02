import SwiftUI

public struct CanvasMinimapView: View {
    public let totalHeight: CGFloat
    public let visibleViewportHeight: CGFloat
    @Binding public var currentScrollOffset: CGFloat
    public let onScrubToNormalizedY: (CGFloat) -> Void
    
    @State private var isDragging: Bool = false
    @State private var dragY: CGFloat = 0
    
    public init(
        totalHeight: CGFloat,
        visibleViewportHeight: CGFloat,
        currentScrollOffset: Binding<CGFloat>,
        onScrubToNormalizedY: @escaping (CGFloat) -> Void
    ) {
        self.totalHeight = max(1, totalHeight)
        self.visibleViewportHeight = visibleViewportHeight
        self._currentScrollOffset = currentScrollOffset
        self.onScrubToNormalizedY = onScrubToNormalizedY
    }
    
    private let barHeight: CGFloat = 160.0
    private let barWidth: CGFloat = 28.0
    
    public var body: some View {
        GeometryReader { _ in
            let viewportRatio = min(1.0, max(0.12, visibleViewportHeight / totalHeight))
            let indicatorHeight = max(20.0, barHeight * viewportRatio)
            let maxTravel = barHeight - indicatorHeight
            let normalizedScroll = min(1.0, max(0.0, currentScrollOffset / max(1, totalHeight - visibleViewportHeight)))
            let indicatorOffset = isDragging ? dragY : normalizedScroll * maxTravel
            
            ZStack(alignment: .top) {
                // Background Glass Capsule Track
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                // Track Mini Tick Lines
                VStack(spacing: 6) {
                    ForEach(0..<10) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 8, height: 1)
                    }
                }
                .padding(.top, 12)
                
                // Draggable Glowing Viewport Window
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.85), Color.accentColor.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.2)
                    )
                    .frame(width: barWidth - 4, height: indicatorHeight)
                    .padding(.horizontal, 2)
                    .offset(y: indicatorOffset)
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 6, x: 0, y: 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let clampedY = min(maxTravel, max(0, value.location.y - indicatorHeight / 2))
                                dragY = clampedY
                                let scrubNormalized = maxTravel > 0 ? (clampedY / maxTravel) : 0
                                onScrubToNormalizedY(scrubNormalized)
                                HapticFeedbackManager.shared.triggerSelection()
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    isDragging = false
                                }
                                HapticFeedbackManager.shared.triggerSnap()
                            }
                    )
            }
            .frame(width: barWidth, height: barHeight)
        }
        .frame(width: barWidth, height: barHeight)
    }
}
