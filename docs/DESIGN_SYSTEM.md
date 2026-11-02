# 设计系统与交互规范 (Design System & HIG)

本文档定义 `ScrollSnap` 的视觉语言、8pt 网格比例、材质语义与动效交互标准。

---

## 1. 8pt 网格系统与比例尺度

界面元素所有外边距、内边距、间距与圆角统一按 8pt 递进：

| 尺度 Token | 像素值 | 应用场景 |
|---|---|---|
| `space-xxs` | 4pt | 标签内部微内边距、极细指示器标点 |
| `space-xs` | 8pt | 按钮紧凑垂直边距、紧凑网格间距 |
| `space-sm` | 12pt | 次级文字间距、列表项内部紧凑内衬 |
| `space-md` | 16pt | 卡片标准内边距、界面栏段内边隙 |
| `space-lg` | 20pt | 标准容器外边距、大卡片标准圆角 |
| `space-xl` | 24pt | 浮层模态窗顶边距、Hero 容器外圆角 |
| `space-xxl` | 32pt | 区块之间主分隔带、底部主按钮安全避让区 |

---

## 2. 莫兰迪低饱和度与系统语义色彩

拒绝高饱和度刺眼渐变，采用低饱和自然色调与深浅模式自动适配：

```swift
public struct SnapTheme {
    // 基础画板底色
    public static let canvasBackground = Color(uiColor: .systemGroupedBackground)
    public static let cardSurface = Color(uiColor: .secondarySystemGroupedBackground)
    public static let tertiarySurface = Color(uiColor: .tertiarySystemGroupedBackground)
    
    // 莫兰迪语义强调色
    public static let slateAccent = Color(red: 0.29, green: 0.33, blue: 0.41) // 沉稳板岩蓝
    public static let sageGreen = Color(red: 0.35, green: 0.52, blue: 0.44)   // 鼠尾草绿 (成功/已完成)
    public static let terracotta = Color(red: 0.76, green: 0.35, blue: 0.31)  // 陶土红 (警示/截断)
    public static let ochreWarm = Color(red: 0.78, green: 0.58, blue: 0.28)   // 暖赭石 (微调接缝/提示)
}
```

---

## 3. 拟物高质感卡片与材质规范

所有操作卡片与悬浮工具栏均搭载 `.ultraThinMaterial` 与 1pt 半透明微高光内倒角：

```swift
public extension View {
    func snapCardStyle(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
```

---

## 4. 触觉反馈规范 (Haptics)

为防止手势滑动或切片拖拽时 Taptic Engine 过载，引入 70ms 硬件防抖门限：

```swift
public final class SnapHaptic {
    private static var lastImpactTimestamp: TimeInterval = 0
    private static let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    public static func selectionChanged() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastImpactTimestamp > 0.07 else { return }
        lastImpactTimestamp = now
        feedbackGenerator.impactOccurred()
    }

    public static func taskSucceeded() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
```
