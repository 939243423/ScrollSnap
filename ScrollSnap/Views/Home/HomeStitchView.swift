import SwiftUI
import PhotosUI
#if canImport(ReplayKit)
import ReplayKit
#endif

public struct HomeStitchView: View {
    @StateObject private var photoObserver = PhotoLibraryObserver.shared
    @StateObject private var storeKit = StoreKitManager.shared
    @StateObject private var quotaManager = QuotaManager.shared
    
    @State private var selectedStitchIndex: Int = 0
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var activeSessionToEdit: StitchSession?
    @State private var isShowingWebCapture = false
    @State private var isShowingSettings = false
    @State private var isShowingPaywall = false
    @State private var isProcessingStitch = false
    @State private var isShowingBroadcastGuide = false
    @State private var isShowingActionShortcutGuide = false
    @State private var activeBroadcastSlices: [String] = []
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Header Bar with Quota Pill
                    headerBar
                    
                    // Unfinished ReplayKit Broadcast Session Alert Banner
                    if !activeBroadcastSlices.isEmpty {
                        activeBroadcastAlertBanner
                    }
                    
                    // Auto-detected Recent Continuous Screenshots
                    if !photoObserver.recentScreenshotAssets.isEmpty {
                        recentDetectedScreenshotsBanner
                    }
                    
                    // Core Actions Grid
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
                    Button {
                        isShowingPaywall = true
                    } label: {
                        HStack(spacing: 4) {
                            if storeKit.isProUser {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                Text("永久会员")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            } else {
                                Text("今日免费 \(quotaManager.remainingDailyFreeStitches)/\(QuotaManager.defaultDailyLimit)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(quotaManager.remainingDailyFreeStitches > 0 ? Color.primary : Color.orange)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .liquidGlassPill(accentTint: storeKit.isProUser ? .green : nil)
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
            .sheet(isPresented: $isShowingPaywall) {
                ProSubscriptionView()
            }
            .sheet(isPresented: $isShowingBroadcastGuide) {
                BroadcastGuideSheet()
            }
            .sheet(isPresented: $isShowingActionShortcutGuide) {
                ActionShortcutGuideSheet()
            }
            .onAppear {
                quotaManager.refreshQuota()
                refreshActiveBroadcastSlices()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshBroadcastSession"))) { _ in
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
            VStack(alignment: .leading, spacing: 3) {
                Text("长截图工坊")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                Text("端侧无损连续拼接 · 支持 15 Pro 操作按钮与双击背面")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
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
        .liquidGlassCard(cornerRadius: 18, strokeOpacity: 0.35)
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
        .liquidGlassCard(cornerRadius: 20, strokeOpacity: 0.3)
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
                    tint: Color.indigo
                )
            }
            .buttonStyle(.plain)
            
            // Web Page Capture
            Button {
                guard quotaManager.canStitch() else {
                    isShowingPaywall = true
                    return
                }
                HapticFeedbackManager.shared.triggerSelection()
                isShowingWebCapture = true
            } label: {
                actionCard(
                    title: "网页全页截图",
                    subtitle: "输入网址一键滚截",
                    iconName: "safari.fill",
                    tint: Color.teal
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func actionCard(title: String, subtitle: String, iconName: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LiquidGlassIconPod(
                systemName: iconName,
                tint: tint,
                size: 40,
                cornerRadius: 12
            )
            
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
        .frame(height: 105)
        .padding(14)
        .liquidGlassCard(cornerRadius: 18, strokeOpacity: 0.25)
    }
    
    private var actionShortcutCard: some View {
        Button {
            HapticFeedbackManager.shared.triggerSelection()
            isShowingActionShortcutGuide = true
        } label: {
            HStack(spacing: 14) {
                LiquidGlassIconPod(
                    systemName: "iphone.radiowaves.left.and.right",
                    tint: Color.blue,
                    size: 44,
                    cornerRadius: 14
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("15 Pro 操作按钮 & 轻点背面")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("秒级")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    Text("连按截屏后，轻敲背面或按侧键，免开 App 0.3秒拼好入剪贴板！")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .liquidGlassCard(cornerRadius: 18, strokeOpacity: 0.25)
        }
        .buttonStyle(.plain)
    }
    
    private var broadcastGuideCard: some View {
        HStack(spacing: 16) {
            LiquidGlassIconPod(
                systemName: "record.circle.fill",
                tint: Color.orange,
                size: 46,
                cornerRadius: 14
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("跨应用滚动截屏 (录屏广播)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                Text("轻按右侧录制按钮，在微信等应用匀速滚屏，后台实时捕获")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
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
        .liquidGlassCard(cornerRadius: 20, strokeOpacity: 0.28)
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
                .liquidGlassCard(cornerRadius: 18, strokeOpacity: 0.2)
            }
        }
    }
    
    // MARK: - Actions
    
    private func refreshActiveBroadcastSlices() {
        self.activeBroadcastSlices = SharedStore.shared.listActiveBroadcastSlicePaths()
    }
    
    private func stitchActiveBroadcastSlices() {
        guard quotaManager.canStitch() else {
            isShowingPaywall = true
            return
        }
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
        guard quotaManager.canStitch() else {
            isShowingPaywall = true
            self.selectedPhotoItems.removeAll()
            return
        }
        
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
        guard quotaManager.canStitch() else {
            isShowingPaywall = true
            return
        }
        
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
            } else {
                await MainActor.run {
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

private struct BroadcastGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("如何在微信中滚动截长图")
                    .font(.headline)
                Text("1. 在控制中心添加「屏幕录制」按钮；\n2. 长按录制按钮选择「ScrollSnap 录屏拼图」；\n3. 切回微信匀速滑动聊天记录；\n4. 点击灵动岛红点停止录制，长截图自动拼好。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding()
                Spacer()
            }
            .padding()
            .navigationTitle("滚动录屏指南")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("知道了") { dismiss() }
                }
            }
        }
    }
}

private struct ActionShortcutGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("配置 15 Pro 操作按钮与双击背面")
                    .font(.headline)
                Text("1. 打开系统「设置」->「操作按钮」（或「辅助功能」->「触控」->「轻点背面」）；\n2. 选择「快捷指令」；\n3. 找到并勾选「ScrollSnap: 一键拼合最近截屏」；\n4. 以后在任意 App 截取多张图后，直接按侧键或敲击手机背面两下，系统后台自动拼合长图并存入剪贴板！")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding()
                Spacer()
            }
            .padding()
            .navigationTitle("硬件触发配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
