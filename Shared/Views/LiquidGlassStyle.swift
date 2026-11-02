import SwiftUI

public struct LiquidGlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var strokeOpacity: Double
    public var isInteractive: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(cornerRadius: CGFloat = 20, strokeOpacity: Double = 0.28, isInteractive: Bool = false) {
        self.cornerRadius = cornerRadius
        self.strokeOpacity = strokeOpacity
        self.isInteractive = isInteractive
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: colorScheme == .dark
                                    ? [Color.white.opacity(0.08), Color.white.opacity(0.02), Color.clear]
                                    : [Color.white.opacity(0.45), Color.white.opacity(0.15), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(strokeOpacity), location: 0.0),
                                .init(color: Color.white.opacity(strokeOpacity * 0.4), location: 0.45),
                                .init(color: Color.white.opacity(0.05), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.08),
                radius: 16,
                x: 0,
                y: 8
            )
    }
}

public struct LiquidGlassPillModifier: ViewModifier {
    public var accentTint: Color?
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(accentTint: Color? = nil) {
        self.accentTint = accentTint
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(
                                (accentTint ?? Color.white).opacity(colorScheme == .dark ? 0.12 : 0.25)
                            )
                    )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06),
                radius: 10,
                x: 0,
                y: 4
            )
    }
}

public extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 20, strokeOpacity: Double = 0.28, isInteractive: Bool = false) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity, isInteractive: isInteractive))
    }
    
    func liquidGlassPill(accentTint: Color? = nil) -> some View {
        modifier(LiquidGlassPillModifier(accentTint: accentTint))
    }
}
