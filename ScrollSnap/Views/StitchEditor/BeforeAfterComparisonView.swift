import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 极度优雅的无缝拼合双目对比帘幕 (Interactive Before/After Split Curtain)
/// 支持手指左右滑动玻璃游标，直观对比「原始重叠分散截屏」与「ScrollSnap 算法去重拼合结果」
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
                                title: "ScrollSnap 算法无缝长图",
                                subtitle: "吸顶/吸底全自动去重 · 智能接缝无裂痕",
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
                                    title: "原始多张截图",
                                    subtitle: "存在大量重复顶栏与错位气泡",
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
                            Text("左：原始分散截图")
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(Color.indigo).frame(width: 6, height: 6)
                            Text("右：ScrollSnap 无缝长图")
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
            .navigationTitle("无缝拼合对比帘幕")
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
