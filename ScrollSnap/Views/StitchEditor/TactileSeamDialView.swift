import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum DialSpeedMultiplier: CGFloat, CaseIterable {
    case micro = 0.5
    case standard = 1.0
    case fast = 10.0
    case jump = 50.0
    
    public var label: String {
        switch self {
        case .micro: return "0.5x"
        case .standard: return "1.0x"
        case .fast: return "10x"
        case .jump: return "50x"
        }
    }
}

public struct TactileSeamDialView: View {
    @Binding public var offset: CGFloat
    public let optimalOffset: CGFloat
    public let range: ClosedRange<CGFloat>
    public var sliceIndex: Int = 1
    public var totalSlices: Int = 2
    public var onSelectSlice: ((Int) -> Void)? = nil
    public let onSnapToOptimal: () -> Void
    public let onScrubbingChanged: ((Bool) -> Void)?
    
    public init(
        offset: Binding<CGFloat>,
        optimalOffset: CGFloat = 0.0,
        range: ClosedRange<CGFloat> = -600...1200,
        sliceIndex: Int = 1,
        totalSlices: Int = 2,
        onSelectSlice: ((Int) -> Void)? = nil,
        onSnapToOptimal: @escaping () -> Void = {},
        onScrubbingChanged: ((Bool) -> Void)? = nil
    ) {
        self._offset = offset
        self.optimalOffset = optimalOffset
        self.range = range
        self.sliceIndex = sliceIndex
        self.totalSlices = totalSlices
        self.onSelectSlice = onSelectSlice
        self.onSnapToOptimal = onSnapToOptimal
        self.onScrubbingChanged = onScrubbingChanged
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
        VStack(spacing: 10) {
            // Header: 接缝选择与状态
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    
                    Text("第 \(sliceIndex) 处接缝")
                        .font(.subheadline.weight(.bold))
                    
                    if totalSlices > 2 {
                        Text("(共 \(totalSlices - 1) 处)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if totalSlices > 2 {
                    HStack(spacing: 8) {
                        Button {
                            if sliceIndex > 1 {
                                onSelectSlice?(sliceIndex - 1)
                                HapticFeedbackManager.shared.triggerSelection()
                            }
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.caption.weight(.bold))
                                .frame(width: 28, height: 26)
                                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .disabled(sliceIndex <= 1)
                        .buttonStyle(.plain)
                        
                        Button {
                            if sliceIndex < totalSlices - 1 {
                                onSelectSlice?(sliceIndex + 1)
                                HapticFeedbackManager.shared.triggerSelection()
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .frame(width: 28, height: 26)
                                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .disabled(sliceIndex >= totalSlices - 1)
                        .buttonStyle(.plain)
                    }
                }
                
                Button {
                    onSnapToOptimal()
                    HapticFeedbackManager.shared.triggerSnap()
                } label: {
                    Text("恢复自动对齐")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isAtOptimal ? Color.clear : Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(isAtOptimal ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // Slider 微调栏：直观、小巧
            HStack(spacing: 12) {
                Button {
                    offset = max(range.lowerBound, offset - 1.0)
                    HapticFeedbackManager.shared.triggerSelection()
                } label: {
                    Image(systemName: "minus")
                        .font(.body.weight(.bold))
                        .frame(width: 36, height: 36)
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
                        Text("上移")
                            .font(.system(size: 10))
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
                        Text("下移")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Button {
                    offset = min(range.upperBound, offset + 1.0)
                    HapticFeedbackManager.shared.triggerSelection()
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}
