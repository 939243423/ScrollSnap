import SwiftUI

public struct DeviceFrameMockupView<Content: View>: View {
    @ViewBuilder public let content: () -> Content
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Dynamic Island Pill Notch
            HStack {
                Spacer()
                Capsule()
                    .fill(Color.black)
                    .frame(width: 90, height: 26)
                    .overlay(
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(white: 0.15))
                                .frame(width: 10, height: 10)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                    )
                Spacer()
            }
            .padding(.top, 14)
            .padding(.bottom, 8)
            .background(Color.black)
            
            // Scaled Content View
            content()
            
            // Bottom Home Bar Area
            HStack {
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 120, height: 4)
                Spacer()
            }
            .padding(.vertical, 10)
            .background(Color.black)
        }
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(
            // Titanium Bezel Outline
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(white: 0.55),
                            Color(white: 0.25),
                            Color(white: 0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 6
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
    }
}
