import SwiftUI

// MARK: - ScrollSnap Unified Design System & Global Style Tokens
// 严格遵循 Apple HIG 规范与抗 AI 视觉纯净标准 (Zero AI tells, Zero gratuitous sparkles)
// 全局统一圆角网格、间距阶梯、语义字体层次与原生液态玻璃材质

public enum ScrollSnapTheme {
    
    // MARK: - Radius Tokens (统一圆角阶梯)
    public enum Radius {
        /// 6pt - 极细微标签、辅助角标
        public static let xs: CGFloat = 6
        /// 10pt - 按钮次级控件、徽章、输入框
        public static let sm: CGFloat = 10
        /// 14pt - 核心主操作按钮、二级卡片
        public static let md: CGFloat = 14
        /// 18pt - 标准内容卡片、Sheet 弹窗容器
        public static let lg: CGFloat = 18
        /// 22pt - 首页核心感知 Hero 卡片、沉浸式展台
        public static let xl: CGFloat = 22
        /// 999pt - 胶囊药丸 (Capsule) 与完全圆形
        public static let full: CGFloat = 999
    }
    
    // MARK: - Spacing Tokens (统一间距阶梯)
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 6
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 24
        public static let section: CGFloat = 32
    }
    
    // MARK: - Typography Tokens (语义排版层次)
    public enum FontToken {
        /// 页面主标题 (例如 "长截图工坊")
        public static let heroTitle: Font = .system(.title2, design: .rounded).weight(.bold)
        
        /// 分组与模态标题 (例如 "即开即拼 · 智能感知")
        public static let sectionTitle: Font = .system(.headline, design: .rounded).weight(.bold)
        
        /// 卡片主文案与主按钮
        public static let cardTitle: Font = .system(.subheadline, design: .rounded).weight(.bold)
        
        /// 次级项目文案与操作文字
        public static let itemTitle: Font = .system(.subheadline, design: .rounded).weight(.semibold)
        
        /// 正文阅读
        public static let bodyText: Font = .system(.footnote, design: .default)
        
        /// 辅助说明与次要提示 (例如 "自适应光流追帧，0.08s 捕捉不匀速快滑")
        public static let captionHint: Font = .system(.caption2, design: .default)
        
        /// 胶囊状态徽章 (例如 "4s 视频", "刚刚截取")
        public static let badgeTag: Font = .system(size: 10, weight: .bold, design: .rounded)
        
        /// 等宽技术指标与数字 (例如 "14.8k", "0.3s", "44.0 pt")
        public static let monoMetric: Font = .system(size: 9, weight: .bold, design: .monospaced)
    }
    
    // MARK: - Color & Gradient Tokens (主题色与渐变层次)
    public enum Colors {
        /// 主品牌连贯渐变 (靛蓝 -> 电光蓝)
        public static let primaryGradient = LinearGradient(
            colors: [Color.indigo, Color.blue],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        /// 录屏与视频提取渐变 (深紫 -> 靛蓝)
        public static let videoGradient = LinearGradient(
            colors: [Color.purple, Color.indigo],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        /// 永久买断与特权高光渐变 (琥珀橙 -> 金色)
        public static let proGoldGradient = LinearGradient(
            colors: [Color.orange, Color.yellow],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// 网页整页直出渐变 (青色 -> 薄荷绿)
        public static let webTealGradient = LinearGradient(
            colors: [Color.teal, Color.cyan],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        /// 3D 摄影棚渐变 (玫红 -> 紫色)
        public static let studioGradient = LinearGradient(
            colors: [Color.pink, Color.purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// 统一的次级半透明浅底填充 (按钮与背景块)
        public static let subtleFill = Color.secondary.opacity(0.12)
        
        /// 统一的微透毛玻璃边缘高光描边
        public static let glassStroke = Color.white.opacity(0.18)
        
        /// 模态加载指示器的背景遮罩 (Scrim)
        public static let hudScrim = Color.black.opacity(0.32)
        
        /// 动态生成任意主题色的半透明底色
        public static func tintFill(for color: Color, opacity: Double = 0.12) -> Color {
            return color.opacity(opacity)
        }
    }
    
    // MARK: - Shadow Tokens (统一物理阴影)
    public enum Shadow {
        public static let subtle: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2
        )
        public static let medium: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            color: Color.black.opacity(0.15), radius: 14, x: 0, y: 6
        )
        public static let prominent: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            color: Color.black.opacity(0.25), radius: 20, x: 0, y: 8
        )
        public static let hud: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12
        )
    }
}

// MARK: - Reusable Button Styles (统一按钮动效与手感)

public struct PrimaryHeroButtonStyle: ButtonStyle {
    public var gradient: LinearGradient
    public var cornerRadius: CGFloat
    
    public init(
        gradient: LinearGradient = ScrollSnapTheme.Colors.primaryGradient,
        cornerRadius: CGFloat = ScrollSnapTheme.Radius.md
    ) {
        self.gradient = gradient
        self.cornerRadius = cornerRadius
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ScrollSnapTheme.FontToken.cardTitle)
            .foregroundStyle(.white)
            .padding(.horizontal, ScrollSnapTheme.Spacing.lg)
            .padding(.vertical, ScrollSnapTheme.Spacing.md)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: configuration.isPressed ? Color.clear : Color.black.opacity(0.18),
                radius: 10,
                x: 0,
                y: 4
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedbackManager.shared.triggerSelection()
                }
            }
    }
}

public struct SecondaryGlassButtonStyle: ButtonStyle {
    public var cornerRadius: CGFloat
    
    public init(cornerRadius: CGFloat = ScrollSnapTheme.Radius.sm + 1) {
        self.cornerRadius = cornerRadius
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ScrollSnapTheme.FontToken.itemTitle)
            .foregroundStyle(.primary)
            .padding(.horizontal, ScrollSnapTheme.Spacing.md)
            .padding(.vertical, ScrollSnapTheme.Spacing.sm + 1)
            .background(ScrollSnapTheme.Colors.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedbackManager.shared.triggerSelection()
                }
            }
    }
}

public struct DismissCircleButtonStyle: ButtonStyle {
    public var size: CGFloat
    
    public init(size: CGFloat = 24) {
        self.size = size
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .background(ScrollSnapTheme.Colors.subtleFill)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.86 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.50), value: configuration.isPressed)
    }
}

public struct BouncyPressStyle: ButtonStyle {
    public var scale: CGFloat
    public var opacity: CGFloat
    
    public init(scale: CGFloat = 0.94, opacity: CGFloat = 0.90) {
        self.scale = scale
        self.opacity = opacity
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? opacity : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.52), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedbackManager.shared.triggerSelection()
                }
            }
    }
}

public enum ScrollSnapButtonStyle {
    public static func heroPrimary(gradient: LinearGradient = ScrollSnapTheme.Colors.primaryGradient) -> PrimaryHeroButtonStyle {
        PrimaryHeroButtonStyle(gradient: gradient)
    }
    public static var glassSecondary: SecondaryGlassButtonStyle {
        SecondaryGlassButtonStyle()
    }
    public static var circleDismiss: DismissCircleButtonStyle {
        DismissCircleButtonStyle()
    }
    public static var bouncy: BouncyPressStyle {
        BouncyPressStyle()
    }
}

// MARK: - Reusable Capsule Badge Tag (统一胶囊角标)

public struct ScrollSnapBadge: View {
    public let text: String
    public let tint: Color
    public var font: Font
    
    public init(
        _ text: String,
        tint: Color = .accentColor,
        font: Font = ScrollSnapTheme.FontToken.badgeTag
    ) {
        self.text = text
        self.tint = tint
        self.font = font
    }
    
    public var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - View Modifiers (优雅声明式视图修饰器)

public struct ScrollSnapCardModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var strokeColor: Color?
    public var strokeWidth: CGFloat
    
    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            #if os(visionOS)
            .glassBackgroundEffect(in: shape)
            #else
            .background(.ultraThinMaterial, in: shape)
            #endif
            .overlay(
                shape.strokeBorder(
                    strokeColor ?? ScrollSnapTheme.Colors.glassStroke,
                    lineWidth: strokeWidth
                )
            )
            .clipShape(shape)
    }
}

public struct ScrollSnapLoadingHUDModifier: ViewModifier {
    public var isPresented: Bool
    public var message: String
    
    public func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack {
                        ScrollSnapTheme.Colors.hudScrim
                            .ignoresSafeArea()
                        
                        VStack(spacing: ScrollSnapTheme.Spacing.md) {
                            ProgressView()
                                .controlSize(.large)
                                .tint(.white)
                            Text(message)
                                .font(ScrollSnapTheme.FontToken.itemTitle)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, ScrollSnapTheme.Spacing.xxl + 4)
                        .padding(.vertical, ScrollSnapTheme.Spacing.xl + 2)
                        .modifier(
                            ScrollSnapCardModifier(
                                cornerRadius: ScrollSnapTheme.Radius.xl,
                                strokeColor: Color.white.opacity(0.22),
                                strokeWidth: 1.0
                            )
                        )
                        .shadow(
                            color: ScrollSnapTheme.Shadow.hud.color,
                            radius: ScrollSnapTheme.Shadow.hud.radius,
                            x: ScrollSnapTheme.Shadow.hud.x,
                            y: ScrollSnapTheme.Shadow.hud.y
                        )
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
                }
            }
    }
}

public extension View {
    /// 统一液态玻璃卡片修饰器
    func scrollSnapCard(
        radius: CGFloat = ScrollSnapTheme.Radius.lg,
        strokeColor: Color? = nil,
        strokeWidth: CGFloat = 0.8
    ) -> some View {
        modifier(ScrollSnapCardModifier(
            cornerRadius: radius,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth
        ))
    }
    
    /// 全局沉浸式毛玻璃加载指示 HUD
    func scrollSnapLoadingHUD(
        isPresented: Bool,
        message: String
    ) -> some View {
        modifier(ScrollSnapLoadingHUDModifier(
            isPresented: isPresented,
            message: message
        ))
    }
}
