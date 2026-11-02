import SwiftUI
import PhotosUI

public struct HomeStitchView: View {
    @StateObject private var photoObserver = PhotoLibraryObserver.shared
    @StateObject private var storeKit = StoreKitManager.shared
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var activeSessionToEdit: StitchSession?
    @State private var isShowingWebCapture = false
    @State private var isShowingSettings = false
    @State private var isProcessingStitch = false
    @State private var isShowingBroadcastGuide = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Status Bar
                    headerBar
                    
                    // Auto-detected Recent Continuous Screenshots
                    if !photoObserver.recentScreenshotAssets.isEmpty {
                        recentDetectedScreenshotsBanner
                    }
                    
                    // Core Capture Actions
                    coreActionsGrid
                    
                    // Broadcast Rolling Screen Capture Guide Card
                    broadcastGuideCard
                    
                    // Recent Stitched Works
                    recentStitchesSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("滚动画布")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if storeKit.isProUser {
                        Text("PRO")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .sheet(item: $activeSessionToEdit) { session in
                StitchEditorView(session: session)
            }
            .sheet(isPresented: $isShowingWebCapture) {
                WebCaptureView { newSession in
                    self.activeSessionToEdit = newSession
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $isShowingBroadcastGuide) {
                BroadcastGuideSheet()
            }
            .onChange(of: selectedPhotoItems) { _, items in
                handleSelectedPhotoPickerItems(items)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("长截图工坊")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                Text("端侧无损连续拼接与屏幕录制长截屏")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    
    private var recentDetectedScreenshotsBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                
                Text("检测到 \(photoObserver.recentScreenshotAssets.count) 张最近连续截屏")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                
                Spacer()
                
                Button("一键拼合") {
                    HapticFeedbackManager.shared.triggerSnap()
                    stitchRecentAssets(photoObserver.recentScreenshotAssets)
                }
                .font(.system(.caption, design: .rounded).weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            
            Text("拍摄于 5 分钟内，宽高比符合当前屏幕尺寸，可直接对齐拼接。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
    
    private var coreActionsGrid: some View {
        HStack(spacing: 12) {
            // Photos Picker
            PhotosPicker(
                selection: $selectedPhotoItems,
                matching: .screenshots,
                photoLibrary: .shared()
            ) {
                actionCard(
                    title: "相册多图拼接",
                    subtitle: "选择连续截图",
                    iconName: "photo.stack",
                    tint: Color(red: 0.29, green: 0.33, blue: 0.41)
                )
            }
            .buttonStyle(.plain)
            
            // Web Page Capture
            Button {
                HapticFeedbackManager.shared.triggerSelection()
                isShowingWebCapture = true
            } label: {
                actionCard(
                    title: "网页全页截图",
                    subtitle: "输入网址一键滚截",
                    iconName: "safari.fill",
                    tint: Color(red: 0.35, green: 0.52, blue: 0.44)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func actionCard(title: String, subtitle: String, iconName: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .font(.body.weight(.semibold))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 110)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private var broadcastGuideCard: some View {
        Button {
            HapticFeedbackManager.shared.triggerSelection()
            isShowingBroadcastGuide = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.78, green: 0.58, blue: 0.28).opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "record.circle")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(red: 0.78, green: 0.58, blue: 0.28))
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("跨应用滚动截屏 (录屏广播)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("在微信、小红书等应用下滑屏幕，即可自动录制并拼合长图")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var recentStitchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("历史长截图")
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(.secondary)
            
            if let dir = AppGroupConstants.completedStitchesDirectory,
               let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]),
               !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items, id: \.path) { fileURL in
                            if let image = UIImage(contentsOfFile: fileURL.path) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                                    )
                                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("暂无长截图记录，从相册或录屏开始")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleSelectedPhotoPickerItems(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isProcessingStitch = true
        
        Task {
            var paths: [String] = []
            for (index, item) in items.enumerated() {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let savedRelPath = SharedStore.shared.writeBroadcastSlice(data: data, index: index) {
                    paths.append(savedRelPath)
                }
            }
            
            do {
                let session = try await StitchEngine.shared.stitchSlices(fileRelativePaths: paths, source: .photoLibrary)
                await MainActor.run {
                    self.activeSessionToEdit = session
                    self.isProcessingStitch = false
                    self.selectedPhotoItems.removeAll()
                }
            } catch {
                await MainActor.run {
                    self.isProcessingStitch = false
                }
            }
        }
    }
    
    private func stitchRecentAssets(_ assets: [PHAsset]) {
        isProcessingStitch = true
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        
        Task.detached(priority: .userInitiated) {
            var paths: [String] = []
            for (index, asset) in assets.enumerated() {
                imageManager.requestImageDataAndOrientation(for: asset, options: requestOptions) { data, _, _, _ in
                    if let data = data,
                       let path = SharedStore.shared.writeBroadcastSlice(data: data, index: index) {
                        paths.append(path)
                    }
                }
            }
            
            if let session = try? await StitchEngine.shared.stitchSlices(fileRelativePaths: paths, source: .photoLibrary) {
                await MainActor.run {
                    self.activeSessionToEdit = session
                    self.isProcessingStitch = false
                }
            }
        }
    }
}

// MARK: - Broadcast Guide Sheet

private struct BroadcastGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("如何使用滚动录屏截取长图")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                
                VStack(alignment: .leading, spacing: 16) {
                    stepRow(index: 1, title: "打开系统控制中心", detail: "从屏幕右上角向下滑动，找到「屏幕录制」按钮。")
                    stepRow(index: 2, title: "长按录制按钮并选择 ScrollSnap", detail: "在弹出列表中勾选「ScrollSnap 滚动画布」，然后轻触「开始直播」。")
                    stepRow(index: 3, title: "切换至目标应用并匀速滚动", detail: "打开任意需要长截图的界面（如聊天对话或文章），自顶向下匀速慢速滑动。")
                    stepRow(index: 4, title: "轻触状态栏红点结束并拼合", detail: "停止录屏后返回 ScrollSnap，系统已自动按位移提取关键帧并无缝拼合。")
                }
                
                Spacer()
                
                Button("我知道了") {
                    dismiss()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(24)
            .navigationTitle("录屏长截图指引")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func stepRow(index: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.15))
                .foregroundStyle(.tint)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
