import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum SeamTunerSubTab: String, CaseIterable, Identifiable {
    case seamAlignment = "接缝对齐"
    case cropFixedBars = "切除顶栏底栏"
    
    public var id: String { rawValue }
    public var iconName: String {
        switch self {
        case .seamAlignment: return "arrow.up.and.down"
        case .cropFixedBars: return "slider.horizontal.3"
        }
    }
}

public struct TactileSeamDialView: View {
    @Binding public var offset: CGFloat
    @Binding public var topCrop: CGFloat
    @Binding public var bottomCrop: CGFloat
    @Binding public var isGhostingEnabled: Bool
    
    public let optimalOffset: CGFloat
    public let range: ClosedRange<CGFloat>
    public var sliceIndex: Int = 1
    public var totalSlices: Int = 2
    public var seamConfidence: Double = 1.0
    public var allConfidences: [Double] = []
    
    public var onSelectSlice: ((Int) -> Void)? = nil
    public let onSnapToOptimal: () -> Void
    public let onScrubbingChanged: ((Bool) -> Void)?
    public var onReDetectSeam: (() -> Void)? = nil
    public var onDirectAppend: (() -> Void)? = nil
    public var onManageSlices: (() -> Void)? = nil
    public var onApplyCropToAll: ((CGFloat, CGFloat) -> Void)? = nil
    
    @State private var activeSubTab: SeamTunerSubTab = .seamAlignment
    @State private var showAppliedToast: Bool = false
    
    public init(
        offset: Binding<CGFloat>,
        topCrop: Binding<CGFloat> = .constant(0),
        bottomCrop: Binding<CGFloat> = .constant(0),
        isGhostingEnabled: Binding<Bool> = .constant(false),
        optimalOffset: CGFloat = 0.0,
        range: ClosedRange<CGFloat> = -600...1200,
        sliceIndex: Int = 1,
        totalSlices: Int = 2,
        seamConfidence: Double = 1.0,
        allConfidences: [Double] = [],
        onSelectSlice: ((Int) -> Void)? = nil,
        onSnapToOptimal: @escaping () -> Void = {},
        onScrubbingChanged: ((Bool) -> Void)? = nil,
        onReDetectSeam: (() -> Void)? = nil,
        onDirectAppend: (() -> Void)? = nil,
        onManageSlices: (() -> Void)? = nil,
        onApplyCropToAll: ((CGFloat, CGFloat) -> Void)? = nil
    ) {
        self._offset = offset
        self._topCrop = topCrop
        self._bottomCrop = bottomCrop
        self._isGhostingEnabled = isGhostingEnabled
        self.optimalOffset = optimalOffset
        self.range = range
        self.sliceIndex = sliceIndex
        self.totalSlices = totalSlices
        self.seamConfidence = seamConfidence
        self.allConfidences = allConfidences
        self.onSelectSlice = onSelectSlice
        self.onSnapToOptimal = onSnapToOptimal
        self.onScrubbingChanged = onScrubbingChanged
        self.onReDetectSeam = onReDetectSeam
        self.onDirectAppend = onDirectAppend
        self.onManageSlices = onManageSlices
        self.onApplyCropToAll = onApplyCropToAll
    }
    
    private var isAtOptimal: Bool {
        abs(offset - optimalOffset) < 0.5
    }
    
    private var sliderBinding: Binding<CGFloat> {
        Binding<CGFloat>(
            get: { offset },
            set: { newVal in
                if abs(newVal - optimalOffset) < 3.5 && abs(offset - optimalOffset) >= 3.5 {
                    offset = optimalOffset
                    HapticFeedbackManager.shared.triggerDialDetent()
                } else {
                    offset = newVal
                }
            }
        )
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // 1. 接缝快速选择条 (当多于 2 张截图时常驻显示)
            if totalSlices > 2 {
                seamNavigatorStrip
            }
            
            // 2. 二级功能分段选择 (接缝对齐 vs 切除顶栏底栏)
            subTabPicker
            
            // 3. 对应选项卡的核心控制区
            if activeSubTab == .seamAlignment {
                seamAlignmentControls
            } else {
                cropFixedBarsControls
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
    
    // MARK: - 1. 接缝快速选择导航条
    
    private var seamNavigatorStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(1..<totalSlices, id: \.self) { idx in
                    let isSelected = (sliceIndex == idx)
                    let conf = (idx - 1 < allConfidences.count) ? allConfidences[idx - 1] : 1.0
                    let isLowConf = conf < 0.40
                    
                    Button {
                        if sliceIndex != idx {
                            onSelectSlice?(idx)
                            HapticFeedbackManager.shared.triggerSelection()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isLowConf ? Color.orange : (isSelected ? Color.accentColor : Color.secondary.opacity(0.4)))
                                .frame(width: 6, height: 6)
                            
                            Text("接缝 \(idx)")
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            
                            if isLowConf {
                                Text("需检查")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.orange)
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
                        )
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    // MARK: - 2. 功能模式分段切换
    
    private var subTabPicker: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(SeamTunerSubTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeSubTab = tab
                        }
                        HapticFeedbackManager.shared.triggerSelection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: activeSubTab == tab ? .bold : .regular))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(activeSubTab == tab ? Color.accentColor.opacity(0.12) : Color.clear, in: Capsule())
                        .foregroundStyle(activeSubTab == tab ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // 截图切片管理入口
            if let onManage = onManageSlices {
                Button {
                    onManage()
                    HapticFeedbackManager.shared.triggerSelection()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 11))
                        Text("管理截图")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
    }
    
    // MARK: - 3A. 接缝对齐控制面板
    
    private var seamAlignmentControls: some View {
        VStack(spacing: 8) {
            // 接缝微调滑动条与步进微调按钮
            HStack(spacing: 8) {
                Button("-5") {
                    offset = max(range.lowerBound, offset - 5.0)
                    HapticFeedbackManager.shared.triggerSelection()
                }
                .font(.system(size: 10, weight: .bold))
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.06), in: Circle())
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
                
                Button {
                    offset = max(range.lowerBound, offset - 1.0)
                    HapticFeedbackManager.shared.triggerSelection()
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                
                VStack(spacing: 2) {
                    Slider(
                        value: sliderBinding,
                        in: range,
                        onEditingChanged: { editing in
                            onScrubbingChanged?(editing)
                            if !editing {
                                HapticFeedbackManager.shared.triggerSelection()
                            }
                        }
                    )
                    .tint(Color.accentColor)
                    
                    HStack {
                        Text("拉近接缝")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button {
                            if !isAtOptimal {
                                onSnapToOptimal()
                                HapticFeedbackManager.shared.triggerSnap()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(String(format: "%+.0f 像素", offset))
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(isAtOptimal ? .secondary : Color.accentColor)
                                if !isAtOptimal {
                                    Text("重置")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text("推开接缝")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Button {
                    offset = min(range.upperBound, offset + 1.0)
                    HapticFeedbackManager.shared.triggerSelection()
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                
                Button("+5") {
                    offset = min(range.upperBound, offset + 5.0)
                    HapticFeedbackManager.shared.triggerSelection()
                }
                .font(.system(size: 10, weight: .bold))
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.06), in: Circle())
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
            }
            
            // 底部高级对齐工具栏：重影透视对齐、重新识别、首尾相连
            HStack(spacing: 8) {
                // 透视重影对齐开关
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isGhostingEnabled.toggle()
                    }
                    HapticFeedbackManager.shared.triggerSelection()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isGhostingEnabled ? "square.2.layers.3d.fill" : "square.2.layers.3d")
                            .font(.system(size: 11))
                        Text("重影对齐")
                            .font(.system(size: 11, weight: isGhostingEnabled ? .bold : .medium))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(isGhostingEnabled ? Color.accentColor : Color.primary.opacity(0.06), in: Capsule())
                    .foregroundStyle(isGhostingEnabled ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // 重新识别当前接缝
                if let onReDetect = onReDetectSeam {
                    Button {
                        onReDetect()
                        HapticFeedbackManager.shared.triggerSnap()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                            Text("重新识别")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
                
                // 首尾直接相连 (零重合拼接保底)
                if let onAppend = onDirectAppend {
                    Button {
                        onAppend()
                        HapticFeedbackManager.shared.triggerSnap()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "link")
                                .font(.system(size: 10, weight: .bold))
                            Text("首尾相连")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
                
                // 恢复自动对齐
                Button {
                    onSnapToOptimal()
                    HapticFeedbackManager.shared.triggerSnap()
                } label: {
                    Text("恢复自动")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(isAtOptimal ? Color.clear : Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(isAtOptimal ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - 3B. 切除顶栏底栏控制面板
    
    private var cropFixedBarsControls: some View {
        VStack(spacing: 8) {
            // 切除顶栏
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.to.line")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("切除顶栏")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(width: 80, alignment: .leading)
                
                Button("-10") {
                    topCrop = max(0, topCrop - 10)
                    HapticFeedbackManager.shared.triggerSelection()
                }
                .font(.system(size: 10, weight: .bold))
                .frame(width: 30, height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
                
                Button("-2") {
                    topCrop = max(0, topCrop - 2)
                    HapticFeedbackManager.shared.triggerSelection()
                }
                .font(.system(size: 10, weight: .bold))
                .frame(width: 26, height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("\(Int(topCrop)) 像素")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .frame(minWidth: 54)
                
                Spacer()
                
                Button("+2") {
                    topCrop = min(800, topCrop + 2)
                    HapticFeedbackManager.shared.triggerSelection()
                }
                .font(.system(size: 10, weight: .bold))
                .frame(width: 26, height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
                
                Button("+10") {
                    topCrop = min(800, topCrop + 10)
                    HapticFeedbackManager.shared.triggerSelection()
                }
                .font(.system(size: 10, weight: .bold))
                .frame(width: 30, height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
            }
            
            // 切除底栏
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("切除底栏")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(width: 80, alignment: .leading)
                
                Button("-10") {
                    bottomCrop = max(0, bottomCrop - 10)
                    HapticFeedbackManager.shared.triggerSelection()
                }
                .font(.system(size: 10, weight: .bold))
                .frame(width: 30, height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
                
                Button("-2") {
                    bottomCrop = max(0, bottomCrop - 2)
                    HapticFeedbackManager.shared.triggerSelection()
                }
                .font(.system(size: 10, weight: .bold))
                .frame(width: 26, height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("\(Int(bottomCrop)) 像素")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .frame(minWidth: 54)
                
                Spacer()
                
                Button("+2") {
                    bottomCrop = min(800, bottomCrop + 2)
                    HapticFeedbackManager.shared.triggerSelection()
                }
                .font(.system(size: 10, weight: .bold))
                .frame(width: 26, height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
                
                Button("+10") {
                    bottomCrop = min(800, bottomCrop + 10)
                    HapticFeedbackManager.shared.triggerSelection()
                }
                .font(.system(size: 10, weight: .bold))
                .frame(width: 30, height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
            }
            
            // 批量应用与预设快捷键
            HStack(spacing: 8) {
                // 常见预设
                HStack(spacing: 4) {
                    Button("不切顶栏") {
                        topCrop = 0
                        HapticFeedbackManager.shared.triggerSelection()
                    }
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3.5)
                    .background(Color.primary.opacity(0.05), in: Capsule())
                    .buttonStyle(.plain)
                    
                    Button("不切底栏") {
                        bottomCrop = 0
                        HapticFeedbackManager.shared.triggerSelection()
                    }
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3.5)
                    .background(Color.primary.opacity(0.05), in: Capsule())
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                if let onApplyAll = onApplyCropToAll {
                    Button {
                        onApplyAll(topCrop, bottomCrop)
                        HapticFeedbackManager.shared.triggerSnap()
                        showAppliedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showAppliedToast = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showAppliedToast ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10, weight: .bold))
                            Text(showAppliedToast ? "已应用全部" : "应用到全部截图")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
        }
    }
}
