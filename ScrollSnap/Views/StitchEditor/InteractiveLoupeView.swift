import SwiftUI

public struct InteractiveLoupeView<Content: View>: View {
    public let touchPosition: CGPoint
    public let magnification: CGFloat
    public let diameter: CGFloat
    @ViewBuilder public let content: Content
    
    public init(
        touchPosition: CGPoint,
        magnification: CGFloat = 2.2,
        diameter: CGFloat = 110.0,
        @ViewBuilder content: () -> Content
    ) {
        self.touchPosition = touchPosition
        self.magnification = magnification
        self.diameter = diameter
        self.content = content()
    }
    
    public var body: some View {
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
            
            // Precision Crosshairs
            ZStack {
                Rectangle()
                    .fill(Color.orange.opacity(0.7))
                    .frame(width: 1, height: diameter * 0.4)
                Rectangle()
                    .fill(Color.orange.opacity(0.7))
                    .frame(width: diameter * 0.4, height: 1)
                Circle()
                    .stroke(Color.orange.opacity(0.7), lineWidth: 1)
                    .frame(width: 16, height: 16)
            }
            
            // Liquid Titanium Specular Ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.85), location: 0.0),
                            .init(color: Color.white.opacity(0.2), location: 0.4),
                            .init(color: Color.black.opacity(0.6), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3.5
                )
            
            // Inner Edge Shadow
            Circle()
                .strokeBorder(Color.black.opacity(0.25), lineWidth: 1)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 8)
        .position(
            x: touchPosition.x,
            y: touchPosition.y < (diameter * 0.85) ? (touchPosition.y + diameter * 0.75) : (touchPosition.y - diameter * 0.75)
        ) // Smart edge avoidance: flips below finger if touching near the top bezel
    }
}
