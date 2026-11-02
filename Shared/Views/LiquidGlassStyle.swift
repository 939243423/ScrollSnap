import SwiftUI

// MARK: - Apple Official Native Liquid Glass System
// 直接调用苹果原生提供的一级玻璃效果 (glassBackgroundEffect 与原生 Material 材质系统)
// 彻底去除多余的人工手写 135° 伪漫射硬编码，全权交由 iOS/visionOS 系统级 GPU 与合成器实时渲染

public struct LiquidGlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var isInteractive: Bool
    
    public init(cornerRadius: CGFloat = 20, isInteractive: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
    }
    
    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        content
            #if os(visionOS)
            .glassBackgroundEffect(in: shape)
            #else
            .background(.ultraThinMaterial, in: shape)
            #endif
            .clipShape(shape)
    }
}

public struct LiquidGlassPillModifier: ViewModifier {
    public var accentTint: Color?
    
    public init(accentTint: Color? = nil) {
        self.accentTint = accentTint
    }
    
    public func body(content: Content) -> some View {
        let shape = Capsule()
        
        content
            #if os(visionOS)
            .glassBackgroundEffect(in: shape)
            #else
            .background((accentTint ?? .primary).opacity(0.1), in: shape)
            .background(.ultraThinMaterial, in: shape)
            #endif
            .clipShape(shape)
    }
}

public extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 20, strokeOpacity: Double = 0.0, isInteractive: Bool = false) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, isInteractive: isInteractive))
    }
    
    func liquidGlassPill(accentTint: Color? = nil) -> some View {
        modifier(LiquidGlassPillModifier(accentTint: accentTint))
    }
}

public struct LiquidGlassIconPod: View {
    public let systemName: String
    public let tint: Color
    public var size: CGFloat
    public var cornerRadius: CGFloat
    
    public init(
        systemName: String,
        tint: Color = .accentColor,
        size: CGFloat = 38,
        cornerRadius: CGFloat = 11
    ) {
        self.systemName = systemName
        self.tint = tint
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        ZStack {
            #if os(visionOS)
            Color.clear
                .glassBackgroundEffect(in: shape)
            #else
            tint.opacity(0.12)
                .background(.ultraThinMaterial, in: shape)
            #endif
            
            Image(systemName: systemName)
                .font(.system(size: size * 0.46, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .clipShape(shape)
    }
}
