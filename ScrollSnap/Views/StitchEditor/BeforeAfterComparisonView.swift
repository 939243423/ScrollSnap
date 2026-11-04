import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 拼图前后对比视图 (Interactive Before/After Split Curtain)
/// 支持左右拖动滑块，对比原始截图与拼接效果
public struct BeforeAfterComparisonView: View {
    public let beforeImage: UIImage?
    public let afterImage: UIImage?
    
    @Environment(\.dismiss) private var dismiss
    @State private var splitRatio: CGFloat = 0.5
    @State private var isDragging: Bool = false
    
    public init(beforeImage: UIImage? = nil, afterImage: UIImage? = nil) {
        self.beforeImage = beforeImage
        self.afterImage = afterImage
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                GeometryReader { proxy in
                    let size = proxy.size
                    let splitX = size.width * splitRatio
                    
                    ZStack(alignment: .leading) {
                        // 1. Right Layer: "After" ScrollSnap Seamless Stitched Image
                        if let after = afterImage {
                            Image(uiImage: after)
                                .resizable()
                                .scaledToFit()
                                .frame(width: size.width, height: size.height)
                        } else {
                            placeholderView(
                                title: "拼接长图",
                                subtitle: "自动去除重合部分",
                                color: .indigo
                            )
                            .frame(width: size.width, height: size.height)
                        }
                        
                        // 2. Left Layer: "Before" Raw Overlapping Screenshots (Clipped to splitX)
                        Group {
                            if let before = beforeImage {
                                Image(uiImage: before)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: size.width, height: size.height)
                            } else {
                                placeholderView(
                                    title: "原始截图",
                                    subtitle: "包含重叠部分",
                                    color: .orange
                                )
                                .frame(width: size.width, height: size.height)
                            }
                        }
                        .frame(width: max(0, splitX), alignment: .leading)
                        .clipped()
                        
                        // 3. Center Split Handle Bar (Liquid Glass Light Saber)
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.1), Color.white, Color.white.opacity(0.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 2)
                                .shadow(color: .white.opacity(0.8), radius: 4)
                        }
                        .position(x: splitX, y: size.height / 2)
                        
                        // 4. Center Drag Pill Indicator
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9, weight: .bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white).shadow(color: .black.opacity(0.3), radius: 8, y: 2))
                        .position(x: splitX, y: size.height / 2)
                        .scaleEffect(isDragging ? 1.15 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("对比滑块")
                        .accessibilityValue("左侧原图显示 \(Int(splitRatio * 100))%，右侧拼接图显示 \(Int((1 - splitRatio) * 100))%")
                        .accessibilityAdjustableAction { direction in
                            switch direction {
                            case .increment:
                                splitRatio = min(0.95, splitRatio + 0.1)
                            case .decrement:
                                splitRatio = max(0.05, splitRatio - 0.1)
                            @unknown default:
                                break
                            }
                            HapticFeedbackManager.shared.triggerSelection()
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                isDragging = true
                                let newRatio = min(max(val.location.x / size.width, 0.05), 0.95)
                                if abs(newRatio - 0.5) < 0.02 && abs(splitRatio - 0.5) >= 0.02 {
                                    HapticFeedbackManager.shared.triggerSnap()
                                } else {
                                    HapticFeedbackManager.shared.triggerSelection()
                                }
                                self.splitRatio = newRatio
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                }
                
                // Bottom Floating Badge Readout
                VStack {
                    Spacer()
                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(Color.orange).frame(width: 6, height: 6)
                            Text("左：原始截图")
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(Color.indigo).frame(width: 6, height: 6)
                            Text("右：拼接长图")
                        }
                    }
                    .font(.caption2.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .liquidGlassPill()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("拼图对比")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }
    
    private func placeholderView(title: String, subtitle: String, color: Color) -> some View {
        ZStack {
            color.opacity(0.18)
            VStack(spacing: 8) {
                Image(systemName: color == .indigo ? "wand.and.stars" : "photo.on.rectangle.angled")
                    .font(.system(size: 36))
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
