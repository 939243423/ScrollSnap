import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum ComparisonTabMode: String, CaseIterable, Identifiable {
    case splitCurtain = "滑动对比"
    case swipeGallery = "逐张浏览"
    public var id: String { rawValue }
}

/// 拼图对比与逐张原图画廊视图 (Before/After Comparison & Slice Gallery)
/// 支持左右拉动帘幕对比拼接效果，也支持像微信画册一样横向逐张滑动画廊浏览原图
public struct BeforeAfterComparisonView: View {
    public let beforeImage: UIImage?
    public let afterImage: UIImage?
    public var session: StitchSession?
    
    @Environment(\.dismiss) private var dismiss
    @State private var tabMode: ComparisonTabMode = .splitCurtain
    @State private var splitRatio: CGFloat = 0.5
    @State private var isDragging: Bool = false
    @State private var currentSliceIndex: Int = 0
    @State private var loadedSliceImages: [UIImage] = []
    
    public init(
        beforeImage: UIImage? = nil,
        afterImage: UIImage? = nil,
        session: StitchSession? = nil
    ) {
        self.beforeImage = beforeImage
        self.afterImage = afterImage
        self.session = session
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if tabMode == .splitCurtain {
                    splitCurtainView
                } else {
                    swipeGalleryView
                }
            }
            .navigationTitle(tabMode == .splitCurtain ? "拼图前后对比" : "逐张浏览原图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
                
                if !loadedSliceImages.isEmpty {
                    ToolbarItem(placement: .principal) {
                        Picker("对比模式", selection: $tabMode) {
                            ForEach(ComparisonTabMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                    }
                }
            }
            .onAppear {
                loadSessionSliceImages()
            }
        }
    }
    
    private func loadSessionSliceImages() {
        guard let session = session else { return }
        var imgs: [UIImage] = []
        for slice in session.slices {
            if let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
               let img = UIImage(contentsOfFile: fileURL.path) {
                imgs.append(img)
            }
        }
        self.loadedSliceImages = imgs
    }
    
    // MARK: - Mode 1: Split Curtain Comparison
    
    private var splitCurtainView: some View {
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
                        color: Color.accentColor
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
                            color: .secondary
                        )
                        .frame(width: size.width, height: size.height)
                    }
                }
                .frame(width: max(0, splitX), alignment: .leading)
                .clipped()
                
                // 3. Center Split Handle Bar
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
        .overlay(alignment: .bottom) {
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.secondary).frame(width: 6, height: 6)
                    Text("左：原始截图")
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.accentColor).frame(width: 6, height: 6)
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
    
    // MARK: - Mode 2: Swipeable Slice Gallery (WeChat-style inspection)
    
    private var swipeGalleryView: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentSliceIndex) {
                ForEach(Array(loadedSliceImages.enumerated()), id: \.offset) { index, img in
                    ZoomableSliceImageView(image: img)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            
            // Bottom Info Capsule
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.caption2)
                Text("第 \(currentSliceIndex + 1) / \(loadedSliceImages.count) 张 · 双击放大或左右滑动")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .liquidGlassPill()
            .padding(.bottom, 36)
        }
    }
    
    private func placeholderView(title: String, subtitle: String, color: Color) -> some View {
        ZStack {
            color.opacity(0.18)
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
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

private struct ZoomableSliceImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    MagnificationGesture()
                        .onChanged { val in
                            scale = max(1.0, min(4.0, lastScale * val))
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale < 1.05 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    scale = 1.0
                                    lastScale = 1.0
                                }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        if scale > 1.2 {
                            scale = 1.0
                            lastScale = 1.0
                        } else {
                            scale = 2.2
                            lastScale = 2.2
                        }
                    }
                    HapticFeedbackManager.shared.triggerSelection()
                }
        }
    }
}
