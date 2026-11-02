import SwiftUI

public enum DeviceFrameFinish: String, CaseIterable, Identifiable {
    case desertTitanium = "沙漠钛金属"
    case naturalTitanium = "原色钛金属"
    case spaceBlack = "深空黑钛"
    case silverWhite = "银白钛金属"
    
    public var id: String { rawValue }
    
    public var bezelGradient: [Color] {
        switch self {
        case .desertTitanium:
            return [
                Color(red: 0.78, green: 0.68, blue: 0.58),
                Color(red: 0.56, green: 0.46, blue: 0.38),
                Color(red: 0.84, green: 0.74, blue: 0.65)
            ]
        case .naturalTitanium:
            return [
                Color(red: 0.58, green: 0.56, blue: 0.52),
                Color(red: 0.40, green: 0.38, blue: 0.35),
                Color(red: 0.65, green: 0.63, blue: 0.60)
            ]
        case .spaceBlack:
            return [
                Color(red: 0.18, green: 0.18, blue: 0.19),
                Color(red: 0.08, green: 0.08, blue: 0.09),
                Color(red: 0.22, green: 0.22, blue: 0.24)
            ]
        case .silverWhite:
            return [
                Color(red: 0.90, green: 0.90, blue: 0.92),
                Color(red: 0.72, green: 0.72, blue: 0.75),
                Color(red: 0.95, green: 0.95, blue: 0.98)
            ]
        }
    }
}

public enum CanvasBackgroundStyle: String, CaseIterable, Identifiable {
    case transparent = "透明无底"
    case adaptiveBlur = "自适应磨砂玻璃"
    case appleGradient = "晨曦蓝紫"
    case studioDark = "极夜深灰"
    case cleanWhite = "极简冷白"
    
    public var id: String { rawValue }
}

public struct DeviceFrameMockupView<Content: View>: View {
    public var finish: DeviceFrameFinish
    public var backgroundStyle: CanvasBackgroundStyle
    public var canvasPadding: CGFloat
    @ViewBuilder public var content: Content
    
    public init(
        finish: DeviceFrameFinish = .naturalTitanium,
        backgroundStyle: CanvasBackgroundStyle = .adaptiveBlur,
        canvasPadding: CGFloat = 24.0,
        @ViewBuilder content: () -> Content
    ) {
        self.finish = finish
        self.backgroundStyle = backgroundStyle
        self.canvasPadding = canvasPadding
        self.content = content()
    }
    
    public var body: some View {
        ZStack {
            // Background Canvas Layer
            backgroundCanvas
            
            // Device Body
            VStack(spacing: 0) {
                // Top Dynamic Island simulated area
                ZStack {
                    Color.black
                    Capsule()
                        .fill(Color(white: 0.12))
                        .frame(width: 88, height: 24)
                }
                .frame(height: 38)
                
                // Screenshot content
                content
                
                // Bottom Home Indicator Bar
                ZStack {
                    Color.black
                    Capsule()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 110, height: 4)
                        .padding(.vertical, 8)
                }
                .frame(height: 20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
            // Inner Screen Border
            .overlay(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .strokeBorder(Color.black, lineWidth: 5)
            )
            // Liquid Titanium Bezel Outer Frame
            .overlay(
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: finish.bezelGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4.5
                    )
            )
            // Specular Highlight
            .overlay(
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.45), location: 0.0),
                                .init(color: Color.white.opacity(0.05), location: 0.25),
                                .init(color: Color.clear, location: 0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 12)
            .padding(canvasPadding)
        }
    }
    
    @ViewBuilder
    private var backgroundCanvas: some View {
        switch backgroundStyle {
        case .transparent:
            Color.clear
        case .adaptiveBlur:
            ZStack {
                Color(uiColor: .systemBackground)
                VisualEffectView(blurStyle: .systemMaterial)
            }
        case .appleGradient:
            LinearGradient(
                colors: [Color(red: 0.38, green: 0.42, blue: 0.94), Color(red: 0.65, green: 0.38, blue: 0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .studioDark:
            Color(red: 0.11, green: 0.11, blue: 0.13)
        case .cleanWhite:
            Color(red: 0.96, green: 0.96, blue: 0.98)
        }
    }
}

#if canImport(UIKit)
public struct VisualEffectView: UIViewRepresentable {
    public var blurStyle: UIBlurEffect.Style
    
    public func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    public func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}
#endif
