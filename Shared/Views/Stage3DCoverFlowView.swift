import SwiftUI

/// 卡片轮播视图组件
/// 支持手势拖拽与视差切换
public struct Stage3DCoverFlowView<Item: Identifiable, Content: View>: View {
    public let items: [Item]
    @Binding public var selectedIndex: Int
    @ViewBuilder public let content: (Item, Bool) -> Content
    
    @GestureState private var dragTranslation: CGFloat = 0

    public init(
        items: [Item],
        selectedIndex: Binding<Int>,
        @ViewBuilder content: @escaping (Item, Bool) -> Content
    ) {
        self.items = items
        self._selectedIndex = selectedIndex
        self.content = content
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let cardWidth: CGFloat = min(width * 0.64, 240)
            let cardHeight: CGFloat = cardWidth * 1.55
            
            HStack(spacing: -cardWidth * 0.42) {
                ForEach(items.indices, id: \.self) { idx in
                    let item = items[idx]
                    let isSelected = (idx == selectedIndex)
                    let offsetRatio = CGFloat(idx - selectedIndex) - (dragTranslation / cardWidth)
                    
                    VStack(spacing: 0) {
                        // 1. 核心 3D 卡片主体
                        content(item, isSelected)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(alignment: .leading) {
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.clear, Color.black.opacity(0.18)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 14)
                            }
                            // 3D 旋转视差
                            .rotation3DEffect(
                                .degrees(Double(offsetRatio) * -34.0),
                                axis: (x: 0, y: 1, z: 0),
                                anchor: .center,
                                perspective: 0.55
                            )
                            .scaleEffect(isSelected ? 1.0 : 0.82)
                            .zIndex(isSelected ? 100 : Double(50 - abs(idx - selectedIndex)))
                            .shadow(
                                color: .black.opacity(isSelected ? 0.32 : 0.12),
                                radius: isSelected ? 20 : 8,
                                x: 0,
                                y: isSelected ? 12 : 4
                            )
                        
                        // 2. 拟真地表镜面倒影
                        if isSelected {
                            content(item, true)
                                .frame(width: cardWidth, height: cardHeight)
                                .scaleEffect(y: -0.45)
                                .blur(radius: 1.5)
                                .mask(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.25), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .offset(y: 6)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            selectedIndex = idx
                        }
                        HapticFeedbackManager.shared.triggerSelection()
                    }
                }
            }
            .offset(x: dragTranslation)
            .gesture(
                DragGesture()
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 36
                        if value.translation.width < -threshold && selectedIndex < items.count - 1 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                selectedIndex += 1
                            }
                            HapticFeedbackManager.shared.triggerSelection()
                        } else if value.translation.width > threshold && selectedIndex > 0 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                selectedIndex -= 1
                            }
                            HapticFeedbackManager.shared.triggerSelection()
                        }
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
