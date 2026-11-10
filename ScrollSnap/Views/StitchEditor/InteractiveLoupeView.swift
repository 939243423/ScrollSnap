import SwiftUI

public struct InteractiveLoupeView<Content: View>: View {
    public let touchPosition: CGPoint
    public let displayPosition: CGPoint?
    public let magnification: CGFloat
    public let diameter: CGFloat
    public let onDismiss: (() -> Void)?
    @ViewBuilder public let content: Content
    
    public init(
        touchPosition: CGPoint,
        displayPosition: CGPoint? = nil,
        magnification: CGFloat = 2.2,
        diameter: CGFloat = 118.0,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.touchPosition = touchPosition
        self.displayPosition = displayPosition
        self.magnification = magnification
        self.diameter = diameter
        self.onDismiss = onDismiss
        self.content = content()
    }
    
    public var body: some View {
        let bubblePos = displayPosition ?? touchPosition
        let targetY: CGFloat = displayPosition != nil
            ? bubblePos.y
            : (bubblePos.y < (diameter * 0.85) ? (bubblePos.y + diameter * 0.75) : (bubblePos.y - diameter * 0.75))
        
        ZStack {
            // Magnified underlying content
            content
                .scaleEffect(magnification, anchor: .topLeading)
                .offset(
                    x: -touchPosition.x * magnification + diameter / 2,
                    y: -touchPosition.y * magnification + diameter / 2
                )
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
            
            // Precision Crosshairs & Reticle
            ZStack {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: 1, height: diameter * 0.45)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: diameter * 0.45, height: 1)
                Circle()
                    .stroke(Color.accentColor.opacity(0.85), lineWidth: 1.2)
                    .frame(width: 18, height: 18)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 3, height: 3)
            }
            
            // Magnification Badge
            VStack {
                HStack {
                    Spacer()
                    Text(String(format: "%.1fx", magnification))
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
                        .offset(x: -8, y: 8)
                }
                Spacer()
            }
            .frame(width: diameter, height: diameter)
            
            // Liquid Titanium Specular Ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.9), location: 0.0),
                            .init(color: Color.white.opacity(0.25), location: 0.4),
                            .init(color: Color.black.opacity(0.65), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3.5
                )
            
            // Inner Edge Shadow
            Circle()
                .strokeBorder(Color.black.opacity(0.3), lineWidth: 1)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 8)
        .position(x: bubblePos.x, y: targetY)
        .onTapGesture {
            onDismiss?()
        }
    }
}
