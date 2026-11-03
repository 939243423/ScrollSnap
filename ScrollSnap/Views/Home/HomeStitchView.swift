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
    @State private var isShowingStudioShowroom = false
    @State private var isProcessingStitch = false
    @State private var isShowingBroadcastGuide = false
    @State private var isShowingActionShortcutGuide = false
    @State private var isShowingWhatsNew = false
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
                    
                    // Hardware & Broadcast Quick Capture Hub (Streamlined 2-Column Hub)
                    quickCaptureHub
                    
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
            .sheet(isPresented: $isShowingStudioShowroom) {
                StudioShowroomView()
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
            .sheet(isPresented: $isShowingWhatsNew) {
                WhatsNewSheetView()
            }
            .onAppear {
                quotaManager.refreshQuota()
                refreshActiveBroadcastSlices()
                if WhatsNewManager.shared.shouldShowWhatsNew() {
                    isShowingWhatsNew = true
                }
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
                Image(systemName: "rectangle.stack.fill")
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
        HStack(spacing: 10) {
            // Photos Picker
            PhotosPicker(
                selection: $selectedPhotoItems,
                matching: .screenshots,
                photoLibrary: .shared()
            ) {
                actionCard(
                    title: "相册拼接",
                    subtitle: "选择连续截图",
                    iconName: "photo.stack",
                    tint: Color.indigo
                )
            }
            .buttonStyle(.plain)
            
            // 3D Studio Poster
            Button {
                HapticFeedbackManager.shared.triggerSelection()
                isShowingStudioShowroom = true
            } label: {
                actionCard(
                    title: "3D 摄影棚",
                    subtitle: "悬浮海报直出",
                    iconName: "cube.transparent",
                    tint: Color.purple
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
                    title: "网页全页",
                    subtitle: "URL一键滚截",
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
    
    private var quickCaptureHub: some View {
        HStack(spacing: 10) {
            // Left: Action Button & Back Tap (15 Pro / 轻敲背面免开 App 极速拼图)
            Button {
                HapticFeedbackManager.shared.triggerSelection()
                isShowingActionShortcutGuide = true
            } label: {
                HStack(spacing: 10) {
                    LiquidGlassIconPod(
                        systemName: "iphone.radiowaves.left.and.right",
                        tint: Color.blue,
                        size: 38,
                        cornerRadius: 11
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("侧键 / 轻敲背面")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("0.3s")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                        Text("截屏后轻敲两下直接拼好")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(12)
                .liquidGlassCard(cornerRadius: 18, strokeOpacity: 0.25)
            }
            .buttonStyle(.plain)
            
            // Right: ReplayKit Rolling Broadcast Capture (微信录屏长截)
            HStack(spacing: 10) {
                LiquidGlassIconPod(
                    systemName: "record.circle.fill",
                    tint: Color.orange,
                    size: 38,
                    cornerRadius: 11
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("滚动录屏截取")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("微信后台匀速录制")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                
                #if canImport(ReplayKit)
                BroadcastPickerViewRepresentable(preferredExtension: "com.scrollsnap.broadcast")
                    .frame(width: 36, height: 36)
                #else
                Button {
                    isShowingBroadcastGuide = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                #endif
            }
            .padding(12)
            .liquidGlassCard(cornerRadius: 18, strokeOpacity: 0.25)
        }
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
                    Button {
                        HapticFeedbackManager.shared.triggerSelection()
                        openCompletedStitch(item)
                    } label: {
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
                    .buttonStyle(.plain)
                }
                .frame(height: 260)
                .padding(.vertical, 8)
            } else {
                // Curated Interactive Sample Showcase in 3D Cover Flow
                VStack(spacing: 8) {
                    Stage3DCoverFlowView(items: sampleShowcaseCards, selectedIndex: $selectedStitchIndex) { card, isSelected in
                        Button {
                            HapticFeedbackManager.shared.triggerSelection()
                            openSampleShowcaseEditor(card)
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                LinearGradient(
                                    colors: card.gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                
                                // Decorative Mock Layout Inside Card
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: card.icon)
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text(card.pixelHeight)
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.black.opacity(0.35)))
                                            .foregroundStyle(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(card.category)
                                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.8))
                                    Text(card.title)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "hand.tap.fill")
                                            .font(.system(size: 9))
                                        Text("轻触体验编辑器")
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.top, 2)
                                }
                                .padding(12)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? Color.accentColor : Color.white.opacity(0.18),
                                        lineWidth: isSelected ? 2.0 : 0.8
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 250)
                    .padding(.vertical, 4)
                    
                    Text("左滑滑动 3D 展台 · 轻触任意示例卡片开启全功能测试")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
    private var sampleShowcaseCards: [ShowcaseStitchCard] {
        [
            ShowcaseStitchCard(
                id: "sample_chat",
                title: "微信研发群长对话",
                category: "聊天记录 · 智能去重",
                pixelHeight: "3,420 px",
                gradientColors: [Color(red: 0.12, green: 0.28, blue: 0.20), Color(red: 0.05, green: 0.14, blue: 0.10)],
                icon: "message.badge.filled.fill",
                preset: .chatRecord
            ),
            ShowcaseStitchCard(
                id: "sample_social",
                title: "小红书秋季穿搭清单",
                category: "九宫格切片 · 朋友圈直发",
                pixelHeight: "4,860 px",
                gradientColors: [Color(red: 0.35, green: 0.12, blue: 0.22), Color(red: 0.18, green: 0.05, blue: 0.12)],
                icon: "square.grid.3x3.fill",
                preset: .continuousFeed
            ),
            ShowcaseStitchCard(
                id: "sample_web",
                title: "Safari 苹果空间计算专栏",
                category: "长文去顶栏 · 原色钛带壳",
                pixelHeight: "14,890 px",
                gradientColors: [Color(red: 0.10, green: 0.16, blue: 0.32), Color(red: 0.05, green: 0.08, blue: 0.18)],
                icon: "safari.fill",
                preset: .webArticle
            )
        ]
    }
    
    private func openSampleShowcaseEditor(_ card: ShowcaseStitchCard) {
        let slice1 = StitchItem(
            relativeFilePath: "sample_1.png",
            originalWidth: 1170,
            originalHeight: 1800,
            topCropInset: card.preset.defaultTopCropInset,
            bottomCropInset: card.preset.defaultBottomCropInset,
            calculatedOverlapWithPrevious: 0,
            manualOffsetAdjustment: 0,
            optimalSeamLineY: 1700
        )
        let slice2 = StitchItem(
            relativeFilePath: "sample_2.png",
            originalWidth: 1170,
            originalHeight: 1920,
            topCropInset: card.preset.defaultTopCropInset,
            bottomCropInset: card.preset.defaultBottomCropInset,
            calculatedOverlapWithPrevious: 240,
            manualOffsetAdjustment: 0,
            optimalSeamLineY: 1820
        )
        let sampleSession = StitchSession(
            presetMode: card.preset,
            slices: [slice1, slice2],
            title: card.title,
            deviceScreenWidth: 393,
            deviceScreenScale: 3.0
        )
        self.activeSessionToEdit = sampleSession
    }
    
    private func openCompletedStitch(_ item: CompletedStitchItem) {
        if let image = UIImage(contentsOfFile: item.url.path) {
            let slice = StitchItem(
                relativeFilePath: "completed_stitches/\(item.url.lastPathComponent)",
                originalWidth: image.size.width * image.scale,
                originalHeight: image.size.height * image.scale,
                calculatedOverlapWithPrevious: 0,
                manualOffsetAdjustment: 0,
                optimalSeamLineY: 0
            )
            let session = StitchSession(
                slices: [slice],
                title: item.url.deletingPathExtension().lastPathComponent
            )
            self.activeSessionToEdit = session
        }
    }
}

private struct ShowcaseStitchCard: Identifiable {
    let id: String
    let title: String
    let category: String
    let pixelHeight: String
    let gradientColors: [Color]
    let icon: String
    let preset: StitchPresetMode
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
