import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Observable controller managing bidirectional synchronization between the canvas UIScrollView and the quick-scrub scrollbar
public final class CanvasScrollController: ObservableObject {
    public weak var scrollView: UIScrollView?
    
    @Published public var normalizedOffset: CGFloat = 0.0
    @Published public var isScrollable: Bool = false
    @Published public var totalContentHeight: CGFloat = 0
    @Published public var viewportHeight: CGFloat = 0
    
    private var offsetObservation: NSKeyValueObservation?
    private var sizeObservation: NSKeyValueObservation?
    public var isUserScrubbing: Bool = false
    
    public init() {}
    
    deinit {
        offsetObservation?.invalidate()
        sizeObservation?.invalidate()
    }
    
    public func attach(to scrollView: UIScrollView) {
        guard self.scrollView !== scrollView else { return }
        self.scrollView = scrollView
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        
        offsetObservation?.invalidate()
        offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scroll, _ in
            guard let self = self, !self.isUserScrubbing else { return }
            let maxOffset = max(1.0, scroll.contentSize.height - scroll.bounds.height)
            let currentY = max(0.0, scroll.contentOffset.y)
            let ratio = max(0.0, min(1.0, currentY / maxOffset))
            
            DispatchQueue.main.async {
                self.normalizedOffset = ratio
                self.totalContentHeight = scroll.contentSize.height
                self.viewportHeight = scroll.bounds.height
                self.isScrollable = scroll.contentSize.height > scroll.bounds.height + 20
            }
        }
        
        sizeObservation?.invalidate()
        sizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] scroll, _ in
            guard let self = self else { return }
            let maxOffset = max(1.0, scroll.contentSize.height - scroll.bounds.height)
            let currentY = max(0.0, scroll.contentOffset.y)
            let ratio = max(0.0, min(1.0, currentY / maxOffset))
            
            DispatchQueue.main.async {
                self.normalizedOffset = ratio
                self.totalContentHeight = scroll.contentSize.height
                self.viewportHeight = scroll.bounds.height
                self.isScrollable = scroll.contentSize.height > scroll.bounds.height + 20
            }
        }
        
        // Initial setup
        let maxOffset = max(1.0, scrollView.contentSize.height - scrollView.bounds.height)
        let ratio = max(0.0, min(1.0, max(0.0, scrollView.contentOffset.y) / maxOffset))
        self.normalizedOffset = ratio
        self.totalContentHeight = scrollView.contentSize.height
        self.viewportHeight = scrollView.bounds.height
        self.isScrollable = scrollView.contentSize.height > scrollView.bounds.height + 20
    }
    
    public func scrollTo(normalized: CGFloat) {
        guard let scrollView = scrollView else { return }
        let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        guard maxOffset > 0 else { return }
        let targetY = max(0, min(maxOffset, normalized * maxOffset))
        
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: targetY), animated: false)
        self.normalizedOffset = max(0, min(1.0, normalized))
    }
    
    public func scrollTo(pointY: CGFloat, animated: Bool = true) {
        guard let scrollView = scrollView else { return }
        let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        guard maxOffset > 0 else { return }
        let targetY = max(0, min(maxOffset, pointY - scrollView.bounds.height * 0.35))
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: targetY), animated: animated)
        let ratio = max(0.0, min(1.0, targetY / maxOffset))
        self.normalizedOffset = ratio
    }
}

/// Custom interactive scrollbar that takes over edge scrolling with real-time bidirectional tracking
public struct CanvasMinimapView: View {
    @ObservedObject public var controller: CanvasScrollController
    
    @State private var isDragging: Bool = false
    @State private var localDragY: CGFloat? = nil
    
    private let barHeight: CGFloat = 200.0
    private let hitTargetWidth: CGFloat = 44.0
    
    public init(controller: CanvasScrollController) {
        self.controller = controller
    }
    
    public var body: some View {
        if controller.isScrollable {
            let totalHeight = max(1, controller.totalContentHeight)
            let visibleViewportHeight = max(1, controller.viewportHeight)
            let viewportRatio = min(1.0, max(0.14, visibleViewportHeight / totalHeight))
            let indicatorHeight = max(28.0, barHeight * viewportRatio)
            let maxTravel = max(1.0, barHeight - indicatorHeight)
            
            let thumbY: CGFloat = {
                if let localY = localDragY, isDragging {
                    return localY
                }
                return max(0, min(maxTravel, controller.normalizedOffset * maxTravel))
            }()
            
            ZStack(alignment: .top) {
                // Background Track (Glass Capsule)
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
                                lineWidth: 0.8
                            )
                    )
                    .frame(width: isDragging ? 10 : 6, height: barHeight)
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isDragging)
                
                // Draggable Viewport Thumb Indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.95), Color.accentColor.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.65), lineWidth: 1.0)
                        )
                        .shadow(color: Color.accentColor.opacity(isDragging ? 0.5 : 0.25), radius: isDragging ? 8 : 4, x: 0, y: 2)
                    
                    // Subtle tactile grip mark
                    Capsule()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 8, height: 2.5)
                }
                .frame(width: isDragging ? 22 : 16, height: indicatorHeight)
                .offset(y: thumbY)
                .animation(.spring(response: 0.2, dampingFraction: 0.85), value: isDragging)
            }
            .frame(width: hitTargetWidth, height: barHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            controller.isUserScrubbing = true
                            HapticFeedbackManager.shared.triggerSelection()
                        }
                        
                        let clampedY = max(0, min(maxTravel, value.location.y - indicatorHeight / 2))
                        localDragY = clampedY
                        let scrubNormalized = clampedY / maxTravel
                        controller.scrollTo(normalized: scrubNormalized)
                        HapticFeedbackManager.shared.triggerSelection()
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            isDragging = false
                            localDragY = nil
                        }
                        controller.isUserScrubbing = false
                        HapticFeedbackManager.shared.triggerSnap()
                    }
            )
        }
    }
}
