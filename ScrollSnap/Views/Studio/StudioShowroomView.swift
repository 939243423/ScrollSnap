import SwiftUI
import PhotosUI
import Photos
#if canImport(UIKit)
import UIKit
#endif

public enum StudioLightingTheme: String, CaseIterable, Identifiable {
    case cupertinoSunset = "加州暖霞"
    case auroraCyan = "极光青蓝"
    case spaceObsidian = "极夜黑曜"
    case studioClean = "棚拍纯白"
    case transparentAlpha = "透明无底"
    
    public var id: String { rawValue }
    
    public var backgroundGradient: [Color] {
        switch self {
        case .cupertinoSunset:
            return [Color(red: 0.15, green: 0.08, blue: 0.22), Color(red: 0.40, green: 0.15, blue: 0.28), Color(red: 0.88, green: 0.45, blue: 0.35)]
        case .auroraCyan:
            return [Color(red: 0.04, green: 0.12, blue: 0.18), Color(red: 0.08, green: 0.32, blue: 0.35), Color(red: 0.20, green: 0.65, blue: 0.55)]
        case .spaceObsidian:
            return [Color(red: 0.08, green: 0.08, blue: 0.09), Color(red: 0.14, green: 0.14, blue: 0.16), Color(red: 0.05, green: 0.05, blue: 0.06)]
        case .studioClean:
            return [Color(red: 0.94, green: 0.95, blue: 0.97), Color(red: 0.88, green: 0.90, blue: 0.93)]
        case .transparentAlpha:
            return [Color.clear, Color.clear]
        }
    }
}

public enum StudioAspectRatio: String, CaseIterable, Identifiable {
    case ratio3x4 = "3:4 经典"
    case ratio9x16 = "9:16 全屏"
    case ratio1x1 = "1:1 方形"
    
    public var id: String { rawValue }
    
    public var canvasSize: CGSize {
        switch self {
        case .ratio3x4: return CGSize(width: 420, height: 560)
        case .ratio9x16: return CGSize(width: 390, height: 693)
        case .ratio1x1: return CGSize(width: 480, height: 480)
        }
    }
}

public struct StudioShowroomView: View {
    public let stitchedImage: UIImage?
    public let onSavePoster: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentImage: UIImage?
    @State private var selectedAlbumItem: PhotosPickerItem?
    
    @State private var selectedTheme: StudioLightingTheme = .cupertinoSunset
    @State private var selectedFinish: DeviceFrameFinish = .naturalTitanium
    @State private var selectedRatio: StudioAspectRatio = .ratio3x4
    @State private var dragRotationX: CGFloat = -14.0
    @State private var dragRotationY: CGFloat = 18.0
    @State private var showShadow: Bool = true
    @State private var isExporting: Bool = false
    @State private var toastMessage: String = ""
    @State private var isShowingToast: Bool = false
    
    public init(
        stitchedImage: UIImage? = nil,
        onSavePoster: @escaping () -> Void = {}
    ) {
        self.stitchedImage = stitchedImage
        self.onSavePoster = onSavePoster
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Studio Backdrop
                LinearGradient(
                    colors: selectedTheme.backgroundGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 3D Interactive Stage
                    ZStack {
                        // Ambient Radial Spotlight Glow
                        RadialGradient(
                            colors: [Color.white.opacity(0.12), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 280
                        )
                        
                        // 3D Floating Device
                        deviceStageView
                            .gesture(
                                DragGesture()
                                    .onChanged { val in
                                        dragRotationY = min(max(val.translation.width * 0.15 + 18, -35), 35)
                                        dragRotationX = min(max(-val.translation.height * 0.15 - 14, -30), 20)
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            dragRotationX = -14.0
                                            dragRotationY = 18.0
                                        }
                                    }
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Bottom Customizer Tray
                    VStack(spacing: 12) {
                        // Lighting Themes
                        HStack {
                            Text("摄影棚氛围")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(StudioLightingTheme.allCases) { theme in
                                    Button {
                                        selectedTheme = theme
                                        HapticFeedbackManager.shared.triggerSelection()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(theme.backgroundGradient.first ?? Color.gray)
                                                .frame(width: 12, height: 12)
                                            Text(theme.rawValue)
                                                .font(.caption2.bold())
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule()
                                                .fill(selectedTheme == theme ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Device Bezel Finishes Bar
                        HStack {
                            Text("机身工艺")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 6) {
                                ForEach(DeviceFrameFinish.allCases) { finish in
                                    Button {
                                        selectedFinish = finish
                                        HapticFeedbackManager.shared.triggerSelection()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(finish.bezelGradient.first ?? Color.gray)
                                                .frame(width: 8, height: 8)
                                            Text(finish.shortName)
                                                .font(.system(size: 11, weight: selectedFinish == finish ? .bold : .medium))
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(selectedFinish == finish ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Aspect Ratio Bar
                        HStack {
                            Text("海报画幅")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 6) {
                                ForEach(StudioAspectRatio.allCases) { ratio in
                                    Button {
                                        selectedRatio = ratio
                                        HapticFeedbackManager.shared.triggerSelection()
                                    } label: {
                                        Text(ratio.rawValue)
                                            .font(.system(size: 11, weight: selectedRatio == ratio ? .bold : .medium))
                                            .lineLimit(1)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 5)
                                            .background(
                                                Capsule()
                                                    .fill(selectedRatio == ratio ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Action Button
                        Button {
                            exportPosterToAlbum()
                        } label: {
                            HStack(spacing: 8) {
                                if isExporting {
                                    ProgressView()
                                        .tint(.black)
                                    Text("正在生成超清 3D 海报...")
                                        .font(.headline.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.headline)
                                    Text("一键导出 \(selectedRatio.rawValue) 海报")
                                        .font(.headline.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Color.white))
                            .foregroundStyle(Color.black)
                            .shadow(color: Color.black.opacity(0.25), radius: 10, y: 4)
                        }
                        .disabled(isExporting)
                        .buttonStyle(ScrollSnapButtonStyle.bouncy)
                    }
                    .padding(18)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("3D 摄影棚制图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $selectedAlbumItem, matching: .images) {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.badge.plus")
                            Text("换图")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
            }
            .onAppear {
                if let initial = stitchedImage {
                    self.currentImage = initial
                }
            }
            .onChange(of: selectedAlbumItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run {
                            self.currentImage = img
                            HapticFeedbackManager.shared.triggerSnap()
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if isShowingToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(toastMessage)
                            .font(.footnote.bold())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .liquidGlassPill()
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    private var deviceStageView: some View {
        VStack(spacing: 0) {
            if let img = currentImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 460)
            } else {
                // Interactive Album Picker Placeholder
                PhotosPicker(selection: $selectedAlbumItem, matching: .images) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
                        .frame(width: 220, height: 440)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 38))
                                Text("轻触选择长截图或相片")
                                    .font(.headline.weight(.semibold))
                                Text("载入 3D 原色钛金属悬浮展台")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .foregroundStyle(.white)
                            .padding()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: selectedFinish.bezelGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(showShadow ? 0.45 : 0.0),
            radius: 30,
            x: dragRotationY * 0.8,
            y: 20
        )
        .rotation3DEffect(.degrees(Double(dragRotationY)), axis: (x: 0, y: 1, z: 0))
        .rotation3DEffect(.degrees(Double(dragRotationX)), axis: (x: 1, y: 0, z: 0))
    }
    
    private var posterExportCanvas: some View {
        ZStack {
            LinearGradient(
                colors: selectedTheme.backgroundGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            RadialGradient(
                colors: [Color.white.opacity(0.15), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 360
            )
            
            deviceStageView
        }
        .frame(width: selectedRatio.canvasSize.width, height: selectedRatio.canvasSize.height)
    }
    
    @MainActor
    private func exportPosterToAlbum() {
        isExporting = true
        HapticFeedbackManager.shared.triggerSnap()
        
        #if canImport(UIKit)
        let renderer = ImageRenderer(content: posterExportCanvas)
        renderer.scale = 2.0
        
        guard let posterImage = renderer.uiImage else {
            isExporting = false
            self.toastMessage = "海报渲染失败，请重试"
            withAnimation { self.isShowingToast = true }
            return
        }
        
        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: posterImage)
                }
                
                await MainActor.run {
                    self.isExporting = false
                    HapticFeedbackManager.shared.triggerSuccess()
                    SoundEffectManager.shared.playShutter()
                    StoreReviewManager.shared.recordSuccessfulExport()
                    self.onSavePoster()
                    self.toastMessage = "3D 摄影棚海报已保存至相册！"
                    withAnimation { self.isShowingToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation { self.isShowingToast = false }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.toastMessage = "保存失败: \(error.localizedDescription)"
                    withAnimation { self.isShowingToast = true }
                }
            }
        }
        #else
        isExporting = false
        #endif
    }
}
