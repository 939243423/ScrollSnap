import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct TactileSeamDialView: View {
    @Binding public var offset: CGFloat
    public let optimalOffset: CGFloat
    public let range: ClosedRange<CGFloat>
    public let onSnapToOptimal: () -> Void
    
    @State private var dragStartOffset: CGFloat = 0
    @State private var isFineGrained: Bool = false
    @State private var lastDetentOffset: CGFloat = 0
    
    public init(
        offset: Binding<CGFloat>,
        optimalOffset: CGFloat = 0.0,
        range: ClosedRange<CGFloat> = -50...50,
        onSnapToOptimal: @escaping () -> Void = {}
    ) {
        self._offset = offset
        self.optimalOffset = optimalOffset
        self.range = range
        self.onSnapToOptimal = onSnapToOptimal
    }
    
    private var isLockedToOptimal: Bool {
        abs(offset - optimalOffset) < 0.5
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header: Seam Energy & Status
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(isLockedToOptimal ? Color.green : Color.orange)
                    Text("接缝对齐能量谱")
                        .font(.caption.bold())
                }
                
                Spacer()
                
                // Alignment readout
                HStack(spacing: 4) {
                    Text(String(format: "%+.1f px", offset))
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(isLockedToOptimal ? Color.green : Color.primary)
                    
                    if isLockedToOptimal {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.green)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(isLockedToOptimal ? Color.green.opacity(0.15) : Color.white.opacity(0.08))
                )
            }
            .padding(.horizontal, 4)
            
            // Seam Energy Curve Visualizer
            energyWaveformView
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                )
            
            // Knurled Mechanical Dial Wheel
            mechanicalDialView
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.clear, Color.black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    // Center Reticle Needle Indicator
                    VStack(spacing: 0) {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(isLockedToOptimal ? Color.green : Color.orange)
                        Rectangle()
                            .fill(isLockedToOptimal ? Color.green : Color.orange)
                            .frame(width: 2, height: 26)
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(isLockedToOptimal ? Color.green : Color.orange)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Controls Footer
            HStack(spacing: 12) {
                Button {
                    isFineGrained.toggle()
                    HapticFeedbackManager.shared.triggerSelection()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isFineGrained ? "scope" : "slider.horizontal.3")
                        Text(isFineGrained ? "0.5x 微调" : "1.0x 步长")
                    }
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        offset = optimalOffset
                    }
                    HapticFeedbackManager.shared.triggerMagneticLock()
                    onSnapToOptimal()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                        Text("最佳缝合点")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(Color.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.green.opacity(0.16)))
                }
                .buttonStyle(.plain)
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        offset = 0.0
                    }
                    HapticFeedbackManager.shared.triggerSelection()
                } label: {
                    Text("重置归零")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 20)
    }
    
    // Simulated Energy Waveform (NCC Parabola with Noise)
    private var energyWaveformView: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let midX = width / 2.0
            
            ZStack {
                // Waveform curve
                Path { path in
                    let step = 3.0
                    var isFirst = true
                    for x in stride(from: 0.0, through: Double(width), by: step) {
                        let relX = (CGFloat(x) - midX) / (width * 0.45)
                        // Inverted Gaussian error valley: lower is better alignment
                        let simulatedError = 1.0 - exp(-pow(relX - (optimalOffset - offset) / 40.0, 2) * 3.5)
                        let y = height * 0.15 + (height * 0.7) * simulatedError
                        
                        if isFirst {
                            path.move(to: CGPoint(x: x, y: y))
                            isFirst = false
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.3),
                            isLockedToOptimal ? Color.green : Color.orange,
                            Color.blue.opacity(0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2.2
                )
                
                // Optimal Point Target Pin
                let optimalX = midX + (optimalOffset - offset) * (width * 0.45 / 40.0)
                if optimalX >= 0 && optimalX <= width {
                    Circle()
                        .fill(isLockedToOptimal ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                        .position(x: optimalX, y: height * 0.2)
                        .shadow(color: isLockedToOptimal ? Color.green : Color.orange, radius: 4)
                }
            }
        }
    }
    
    // Knurled Ruler Wheel
    private var mechanicalDialView: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let center = width / 2.0
            let tickSpacing: CGFloat = isFineGrained ? 14.0 : 8.0
            
            Canvas { context, size in
                let currentOffset = offset
                let midY = size.height / 2.0
                
                // Draw ruler ticks
                let minVal = Int(range.lowerBound)
                let maxVal = Int(range.upperBound)
                
                for val in minVal...maxVal {
                    let tickX = center + (CGFloat(val) - currentOffset) * tickSpacing
                    guard tickX >= -20 && tickX <= size.width + 20 else { continue }
                    
                    let isMajor = val % 10 == 0
                    let isMedium = val % 5 == 0
                    let tickHeight: CGFloat = isMajor ? 24 : (isMedium ? 16 : 9)
                    let tickOpacity: Double = isMajor ? 0.9 : (isMedium ? 0.6 : 0.3)
                    
                    let tickRect = CGRect(
                        x: tickX - 0.5,
                        y: midY - tickHeight / 2.0,
                        width: 1.0,
                        height: tickHeight
                    )
                    
                    let color = (val == Int(optimalOffset)) ? Color.green : Color.white
                    context.fill(Path(tickRect), with: .color(color.opacity(tickOpacity)))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartOffset == 0 {
                            dragStartOffset = offset
                        }
                        let sensitivity: CGFloat = isFineGrained ? 0.25 : 0.55
                        let delta = -value.translation.width * sensitivity / (tickSpacing * 0.5)
                        var newOffset = dragStartOffset + delta
                        newOffset = min(max(newOffset, range.lowerBound), range.upperBound)
                        
                        // Check if hitting detents
                        if abs(newOffset - lastDetentOffset) >= 1.0 {
                            lastDetentOffset = round(newOffset)
                            HapticFeedbackManager.shared.triggerDialDetent()
                        }
                        
                        // Magnetic snap when near optimal
                        if abs(newOffset - optimalOffset) < 1.0 {
                            newOffset = optimalOffset
                            HapticFeedbackManager.shared.triggerMagneticLock()
                        }
                        
                        self.offset = newOffset
                    }
                    .onEnded { _ in
                        dragStartOffset = 0
                    }
            )
        }
    }
}
