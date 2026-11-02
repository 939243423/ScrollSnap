import SwiftUI

/// 通用 3D 拟物立体展台组件 (HIG 3D Cover Flow Stage)
/// 具备 3D 矩阵偏转、侧边书脊曲面高光、地表镜面倒影与触觉反馈
public struct Stage3DCoverFlowView<Item: Identifiable, Content: View>: View {
    public let items: [Item]
    @Binding public var selectedIndex: Int
    @ViewBuilder public let content: (Item, Bool) -> Content

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
            let cardHeight: CGFloat = cardWidth * 1.55 // Long screenshot aspect ratio
            
            HStack(spacing: -cardWidth * 0.42) {
                ForEach(items.indices, id: \.self) { idx in
                    let item = items[idx]
                    let isSelected = (idx == selectedIndex)
                    let offsetRatio = CGFloat(idx - selectedIndex)
                    
                    VStack(spacing: 0) {
                        // 1. 核心 3D 卡片主体
                        content(item, isSelected)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            // 侧边装订线/边缘曲面高光
                            .overlay(alignment: .leading) {
                                LinearGradient(
                                    colors: [Color.white.opacity(0.28), Color.clear, Color.black.opacity(0.18)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 12)
                            }
                            // 3D 偏转视差：左侧向内偏转，右侧向外偏转
                            .rotation3DEffect(
                                .degrees(Double(offsetRatio) * -38.0),
                                axis: (x: 0, y: 1, z: 0),
                                anchor: .center,
                                perspective: 0.55
                            )
                            .scaleEffect(isSelected ? 1.0 : 0.82)
                            .zIndex(isSelected ? 100 : Double(50 - abs(idx - selectedIndex)))
                            .shadow(
                                color: .black.opacity(isSelected ? 0.28 : 0.12),
                                radius: isSelected ? 18 : 8,
                                x: 0,
                                y: isSelected ? 10 : 4
                            )
                        
                        // 2. 拟真地表镜面倒影
                        if isSelected {
                            content(item, true)
                                .frame(width: cardWidth, height: cardHeight)
                                .scaleEffect(y: -0.45)
                                .blur(radius: 1.5)
                                .mask(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.22), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .offset(y: 6)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            selectedIndex = idx
                        }
                        HapticFeedbackManager.shared.triggerSelection()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
