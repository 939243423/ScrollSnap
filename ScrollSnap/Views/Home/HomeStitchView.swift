import SwiftUI
import PhotosUI
#if canImport(ReplayKit)
import ReplayKit
#endif

public struct HomeStitchView: View {
    @StateObject private var photoObserver = PhotoLibraryObserver.shared
    @StateObject private var storeKit = StoreKitManager.shared
    
    @State private var selectedStitchIndex: Int = 0
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var activeSessionToEdit: StitchSession?
    @State private var isShowingWebCapture = false
    @State private var isShowingSettings = false
    @State private var isProcessingStitch = false
    @State private var isShowingBroadcastGuide = false
    @State private var isShowingActionShortcutGuide = false
    @State private var activeBroadcastSlices: [String] = []
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Status Bar
                    headerBar
                    
                    // Unfinished ReplayKit Broadcast Session Alert Banner
                    if !activeBroadcastSlices.isEmpty {
                        activeBroadcastAlertBanner
                    }
                    
                    // Auto-detected Recent Continuous Screenshots
                    if !photoObserver.recentScreenshotAssets.isEmpty {
                        recentDetectedScreenshotsBanner
                    }
                    
                    // Core Capture Actions Grid
                    coreActionsGrid
                    
                    // Action Button & Back Tap (操作按钮与轻点背面) Shortcut Guide Card
                    actionShortcutCard
                    
                    // Broadcast Rolling Screen Capture Card
                    broadcastGuideCard
                    
                    // Recent Stitched Works 3D Stage
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
            .sheet(isPresented: $isShowingActionShortcutGuide) {
                ActionShortcutGuideSheet()
            }
            .onAppear {
                refreshActiveBroadcastSlices()
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
    
    private var activeBroadcastAlertBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "record.circle.fill")
                    .font(.body)
                    .foregroundStyle(Color.orange)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("检测到录屏截取的 \(activeBroadcastSlices.count) 屏切片")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("轻触立即自动对齐并拼合为长图")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("立即拼合") {
                HapticFeedbackManager.shared.triggerSnap()
                stitchActiveBroadcastSlices()
            }
            .font(.system(.caption, design: .rounded).weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
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
    
    private var actionShortcutCard: some View {
        Button {
            HapticFeedbackManager.shared.triggerSelection()
            isShowingActionShortcutGuide = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .foregroundStyle(Color.blue)
                        .font(.body.weight(.semibold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("支持 15 Pro 操作按钮 & 轻点背面")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    Text("连按截屏后，轻敲背面或按一下操作按钮，即可免打开 App 自动拼好复制！")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var broadcastGuideCard: some View {
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
                Text("轻按右侧录制按钮，在微信等应用匀速滚屏，后台实时捕获")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Native ReplayKit Broadcast Picker View inside card
            #if canImport(ReplayKit)
            BroadcastPickerViewRepresentable(preferredExtension: "com.scrollsnap.broadcast")
                .frame(width: 44, height: 44)
            #else
            Button {
                isShowingBroadcastGuide = true
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            #endif
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private var recentStitchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("历史长截图展台 (3D 拟物视角)")
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(.secondary)
            
            if let dir = AppGroupConstants.completedStitchesDirectory,
               let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]),
               !items.isEmpty {
                let stitchItems = items.map { CompletedStitchItem(id: $0.path, url: $0) }
                
                Stage3DCoverFlowView(items: stitchItems, selectedIndex: $selectedStitchIndex) { item, isSelected in
                    if let image = UIImage(contentsOfFile: item.url.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.15),
                                        lineWidth: isSelected ? 1.5 : 0.8
                                    )
                            )
                    }
                }
                .frame(height: 260)
                .padding(.vertical, 8)
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
    
    private func refreshActiveBroadcastSlices() {
        self.activeBroadcastSlices = SharedStore.shared.listActiveBroadcastSlicePaths()
    }
    
    private func stitchActiveBroadcastSlices() {
        guard !activeBroadcastSlices.isEmpty else { return }
        isProcessingStitch = true
        
        Task {
            do {
                let session = try await StitchEngine.shared.stitchSlices(
                    fileRelativePaths: activeBroadcastSlices,
                    source: .replayKitBroadcast,
                    presetMode: .chatRecord
                )
                await MainActor.run {
                    self.activeSessionToEdit = session
                    self.isProcessingStitch = false
                    SharedStore.shared.resetActiveBroadcastSession()
                    refreshActiveBroadcastSlices()
                }
            } catch {
                await MainActor.run {
                    self.isProcessingStitch = false
                }
            }
        }
    }
    
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
                let session = try await StitchEngine.shared.stitchSlices(
                    fileRelativePaths: paths,
                    source: .photoLibrary,
                    presetMode: .chatRecord
                )
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

private struct CompletedStitchItem: Identifiable {
    let id: String
    let url: URL
}

// MARK: - Native RPSystemBroadcastPickerView Representable

#if canImport(ReplayKit)
private struct BroadcastPickerViewRepresentable: UIViewRepresentable {
    let preferredExtension: String
    
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        picker.preferredExtension = preferredExtension
        picker.showsMicrophoneButton = false
        return picker
    }
    
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
#endif

// MARK: - Action Button & Back Tap Setup Guide Sheet

private struct ActionShortcutGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("如何配置 iPhone 15 Pro 操作按钮与轻点背面截屏")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    
                    Text("无需每次打开 App，只需在任意应用截取 2~5 张图后，按一下操作按钮或轻敲背面两下，系统将在后台自动拼接并把长截图存入剪贴板！")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        stepCard(
                            tag: "A",
                            title: "配置 iPhone 15 Pro / 16 Pro 操作按钮 (Action Button)",
                            steps: [
                                "打开系统「设置」 -> 点击「操作按钮」",
                                "横向滑动选择「快捷指令」选项",
                                "轻触下方的选取列表，在 ScrollSnap 下勾选「一键拼合长截图」",
                                "完成！今后在任何 App 截屏后，长按侧边操作按钮，立即自动拼合存入剪切板。"
                            ]
                        )
                        
                        stepCard(
                            tag: "B",
                            title: "配置「轻点背面两下」 (Back Tap，所有 iPhone 均支持)",
                            steps: [
                                "打开系统「设置」 -> 点击「辅助功能」",
                                "点击「触控」 -> 滑至最底部点击「轻点背面」",
                                "选择「轻点两下」或「轻点三下」",
                                "在「快捷指令」区域中勾选「ScrollSnap：一键拼合长截图」",
                                "完成！日常连截几张图后，食指轻敲手机背面两下，立刻听到清脆触觉振动并完成拼合！"
                            ]
                        )
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("快捷触发指引")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func stepCard(tag: String, title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(tag)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .frame(width: 22, height: 22)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(steps.indices, id: \.self) { i in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(steps[i])
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                    stepRow(index: 2, title: "长按录制按钮并选择 ScrollSnap", detail: "在弹出列表中勾选「ScrollSnap 滚屏录制」，然后轻触「开始直播」。")
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
