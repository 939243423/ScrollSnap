import SwiftUI
import PhotosUI
import Photos
import AVFoundation
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if canImport(ReplayKit)
import ReplayKit
#endif

private struct MovieFile: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("imported_\(UUID().uuidString).\(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)")
            if FileManager.default.fileExists(atPath: copy.path) {
                try? FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

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
    @State private var toastMessage: String = ""
    @State private var isShowingToast: Bool = false
    @State private var detectedClipboardURL: URL?
    @State private var lastSavedImage: UIImage?
    @State private var selectedVideoPickerItems: [PhotosPickerItem] = []
    @State private var isDismissedRecentScreenshots = false
    @State private var isDismissedRecentVideo = false
    @State private var isDismissedClipboardURL = false
    @State private var processingStatusMessage = "正在智能拼接长图..."
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Header Bar with Quota Pill
                    headerBar
                    
                    // Photo Permission Denied / Restricted Warning Banner
                    if photoObserver.authorizationStatus == .denied || photoObserver.authorizationStatus == .restricted {
                        photoPermissionDeniedBanner
                    }
                    
                    // Intelligent Contextual Hub: Single highest priority action to avoid banner fatigue
                    smartContextualHub
                    
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
                checkClipboardForURL()
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
            .onChange(of: selectedVideoPickerItems) { _, items in
                handleSelectedVideoPickerItem(items)
            }
            .overlay(alignment: .bottom) {
                if isShowingToast {
                    toastOverlayView
                }
            }
            .scrollSnapLoadingHUD(isPresented: isProcessingStitch, message: processingStatusMessage)
        }
    }
    
    private var toastOverlayView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.subheadline)
                Text(toastMessage)
                    .font(ScrollSnapTheme.FontToken.itemTitle)
                    .foregroundStyle(.primary)
            }
            
            #if canImport(UIKit)
            if let img = lastSavedImage {
                HStack(spacing: 8) {
                    Button {
                        UIPasteboard.general.image = img
                        HapticFeedbackManager.shared.triggerSnap()
                        self.toastMessage = "长截图已复制到剪贴板！"
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc.fill")
                            Text("复制长图")
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.18))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ScrollSnapButtonStyle.bouncy)
                    
                    Button {
                        isShowingStudioShowroom = true
                        HapticFeedbackManager.shared.triggerSelection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "cube.transparent.fill")
                            Text("套3D机壳")
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.18))
                        .foregroundStyle(Color.purple)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ScrollSnapButtonStyle.bouncy)
                }
            }
            #endif
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .liquidGlassPill()
        .transition(.asymmetric(
            insertion: .scale(scale: 0.86).combined(with: .opacity).combined(with: .move(edge: .bottom)),
            removal: .scale(scale: 0.94).combined(with: .opacity)
        ))
        .padding(.bottom, 24)
    }
    
    private func showToast(message: String) {
        self.toastMessage = message
        withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
            self.isShowingToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.isShowingToast = false
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("长截图")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                Text("自动拼接长截图 · 支持轻点背面与快捷指令")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private var photoPermissionDeniedBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.red)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("需要相册访问权限")
                    .font(ScrollSnapTheme.FontToken.itemTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("请在系统设置允许访问相册，以智能感知截屏与保存长图")
                    .font(ScrollSnapTheme.FontToken.captionHint)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Button("去开启") {
                #if canImport(UIKit)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            }
            .font(.system(.caption, design: .rounded).weight(.bold))
            .padding(.horizontal, ScrollSnapTheme.Spacing.md)
            .padding(.vertical, ScrollSnapTheme.Spacing.xs)
            .background(Color.red)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
        .padding(ScrollSnapTheme.Spacing.md)
        .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg, strokeColor: Color.red.opacity(0.35))
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
    
    private func checkClipboardForURL() {
        #if canImport(UIKit)
        if let url = UIPasteboard.general.url {
            self.detectedClipboardURL = url
        } else if let string = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                  (string.hasPrefix("http://") || string.hasPrefix("https://")),
                  let url = URL(string: string) {
            self.detectedClipboardURL = url
        } else {
            self.detectedClipboardURL = nil
        }
        #endif
    }
    
    private func clipboardURLBanner(_ url: URL) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "safari.fill")
                    .font(.body)
                    .foregroundStyle(Color.teal)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("剪贴板文章链接")
                        .font(ScrollSnapTheme.FontToken.itemTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    ScrollSnapBadge("0 截屏", tint: .teal)
                }
                Text(url.host ?? url.absoluteString)
                    .font(ScrollSnapTheme.FontToken.captionHint)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button("整页直出") {
                HapticFeedbackManager.shared.triggerSnap()
                self.isShowingWebCapture = true
            }
            .font(.system(.caption, design: .rounded).weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, ScrollSnapTheme.Spacing.md)
            .padding(.vertical, ScrollSnapTheme.Spacing.xs)
            .background(Color.teal)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isDismissedClipboardURL = true
                }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(ScrollSnapButtonStyle.circleDismiss)
        }
        .padding(ScrollSnapTheme.Spacing.md + 2)
        .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg, strokeColor: Color.teal.opacity(0.35))
    }
    
    private func recentScreenRecordingBanner(_ video: PHAsset) -> some View {
        let durationSec = max(1, Int(video.duration))
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: "video.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.purple)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("录屏转长图")
                            .font(ScrollSnapTheme.FontToken.cardTitle)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        ScrollSnapBadge("\(durationSec)s 视频", tint: .purple)
                    }
                    Text("从滑动录屏提取画面，自动去除重复内容")
                        .font(ScrollSnapTheme.FontToken.captionHint)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isDismissedRecentVideo = true
                    }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(ScrollSnapButtonStyle.circleDismiss)
            }
            
            VStack(spacing: 10) {
                Button {
                    HapticFeedbackManager.shared.triggerSnap()
                    stitchVideoAsset(video, deleteOriginalVideo: true)
                } label: {
                    HStack(spacing: 8) {
                        if isProcessingStitch {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "film.stack.fill")
                                .font(.body.weight(.semibold))
                        }
                        Text("保存长图并删除原录屏")
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer()
                        Image(systemName: "trash.slash.fill")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScrollSnapButtonStyle.heroPrimary(gradient: ScrollSnapTheme.Colors.videoGradient))
                .disabled(isProcessingStitch)
                
                HStack(spacing: 10) {
                    Button {
                        HapticFeedbackManager.shared.triggerSelection()
                        stitchVideoAsset(video, deleteOriginalVideo: false)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                            Text("仅存长图")
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ScrollSnapButtonStyle.glassSecondary)
                    .disabled(isProcessingStitch)
                    
                    Button {
                        HapticFeedbackManager.shared.triggerSelection()
                        stitchVideoAsset(video, deleteOriginalVideo: false, openInEditor: true)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text("工作台精修")
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ScrollSnapButtonStyle.glassSecondary)
                    .disabled(isProcessingStitch)
                }
            }
        }
        .padding(ScrollSnapTheme.Spacing.lg)
        .scrollSnapCard(radius: ScrollSnapTheme.Radius.xl, strokeColor: Color.purple.opacity(0.35))
    }
    
    private var recentDetectedScreenshotsBanner: some View {
        let count = photoObserver.recentScreenshotAssets.count
        return VStack(alignment: .leading, spacing: 14) {
            // Header: Status badge & Title
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: "bolt.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("检测到连续截屏")
                            .font(ScrollSnapTheme.FontToken.cardTitle)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        ScrollSnapBadge("\(count) 张截图", tint: .accentColor)
                    }
                    Text("已按时间排好顺序，可直接拼成长图")
                        .font(ScrollSnapTheme.FontToken.captionHint)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isDismissedRecentScreenshots = true
                    }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(ScrollSnapButtonStyle.circleDismiss)
            }
            
            // Primary Action Buttons
            VStack(spacing: 10) {
                // Killer Action 1: Save long screenshot AND delete raw slices!
                Button {
                    HapticFeedbackManager.shared.triggerSnap()
                    quickSaveRecentAssets(photoObserver.recentScreenshotAssets, deleteOriginals: true)
                } label: {
                    HStack(spacing: 8) {
                        if isProcessingStitch {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.body.weight(.semibold))
                        }
                        Text("保存长图并删除 \(count) 张原截图")
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer()
                        Image(systemName: "trash.slash.fill")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScrollSnapButtonStyle.heroPrimary(gradient: ScrollSnapTheme.Colors.primaryGradient))
                .disabled(isProcessingStitch)
                
                // Secondary Actions Row
                HStack(spacing: 10) {
                    // Action 2: Only save to album without deleting
                    Button {
                        HapticFeedbackManager.shared.triggerSelection()
                        quickSaveRecentAssets(photoObserver.recentScreenshotAssets, deleteOriginals: false)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                            Text("仅存长图")
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ScrollSnapButtonStyle.glassSecondary)
                    .disabled(isProcessingStitch)
                    
                    // Action 3: Open in Editor
                    Button {
                        HapticFeedbackManager.shared.triggerSelection()
                        stitchRecentAssets(photoObserver.recentScreenshotAssets)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text("工作台精修")
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ScrollSnapButtonStyle.glassSecondary)
                    .disabled(isProcessingStitch)
                }
            }
        }
        .padding(ScrollSnapTheme.Spacing.lg)
        .scrollSnapCard(radius: ScrollSnapTheme.Radius.xl, strokeColor: Color.accentColor.opacity(0.35))
    }
    
    @ViewBuilder
    private var smartContextualHub: some View {
        if !activeBroadcastSlices.isEmpty {
            activeBroadcastAlertBanner
        } else if let videoAsset = photoObserver.recentScreenRecordingAsset, !isDismissedRecentVideo {
            recentScreenRecordingBanner(videoAsset)
        } else if photoObserver.recentScreenshotAssets.count >= 2, !isDismissedRecentScreenshots {
            recentDetectedScreenshotsBanner
        } else if let url = detectedClipboardURL, !isDismissedClipboardURL {
            clipboardURLBanner(url)
        }
    }
    
    private var coreActionsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Screenshots Picker
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    matching: .screenshots,
                    photoLibrary: .shared()
                ) {
                    actionCard(
                        title: "照片拼长图",
                        subtitle: "选多张截图自动拼接",
                        iconName: "photo.stack.fill",
                        tint: Color.indigo,
                        tag: "常用"
                    )
                }
                .buttonStyle(ScrollSnapButtonStyle.bouncy)
                
                // Screen Recording Video Picker
                PhotosPicker(
                    selection: $selectedVideoPickerItems,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    actionCard(
                        title: "录屏转长图",
                        subtitle: "自动识别滑动内容",
                        iconName: "film.stack.fill",
                        tint: Color.purple,
                        tag: "视频"
                    )
                }
                .buttonStyle(ScrollSnapButtonStyle.bouncy)
            }
            
            HStack(spacing: 10) {
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
                        title: "网页截图",
                        subtitle: "输入网址保存整页",
                        iconName: "safari.fill",
                        tint: Color.teal,
                        tag: "网页"
                    )
                }
                .buttonStyle(ScrollSnapButtonStyle.bouncy)
                
                // 3D Studio Poster
                Button {
                    HapticFeedbackManager.shared.triggerSelection()
                    isShowingStudioShowroom = true
                } label: {
                    actionCard(
                        title: "带壳截图",
                        subtitle: "生成手机样机海报",
                        iconName: "cube.transparent.fill",
                        tint: Color.pink,
                        tag: "样机"
                    )
                }
                .buttonStyle(ScrollSnapButtonStyle.bouncy)
            }
        }
    }
    
    private func actionCard(
        title: String,
        subtitle: String,
        iconName: String,
        tint: Color,
        tag: String? = nil
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            RadialGradient(
                colors: [tint.opacity(0.12), Color.clear],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 90
            )
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    LiquidGlassIconPod(
                        systemName: iconName,
                        tint: tint,
                        size: 38,
                        cornerRadius: ScrollSnapTheme.Radius.sm
                    )
                    Spacer()
                    if let tag = tag {
                        ScrollSnapBadge(tag, tint: tint)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ScrollSnapTheme.FontToken.itemTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(subtitle)
                        .font(ScrollSnapTheme.FontToken.captionHint)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .padding(13)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 108)
        .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg, strokeColor: tint.opacity(0.28))
    }
    
    private var quickCaptureHub: some View {
        HStack(spacing: 10) {
            // Left: Action Button & Back Tap (15 Pro / 轻敲背面免开 App 极速拼图)
            Button {
                HapticFeedbackManager.shared.triggerSelection()
                isShowingActionShortcutGuide = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    RadialGradient(
                        colors: [Color.blue.opacity(0.12), Color.clear],
                        center: .topTrailing,
                        startRadius: 8,
                        endRadius: 90
                    )
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            LiquidGlassIconPod(
                                systemName: "iphone.radiowaves.left.and.right",
                                tint: Color.blue,
                                size: 38,
                                cornerRadius: ScrollSnapTheme.Radius.sm
                            )
                            Spacer()
                            ScrollSnapBadge("快捷", tint: .blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("轻点背面 / 操作按钮")
                                .font(ScrollSnapTheme.FontToken.itemTitle)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text("截屏后轻按直接拼图")
                                .font(ScrollSnapTheme.FontToken.captionHint)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    .padding(13)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 108)
                .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg, strokeColor: Color.blue.opacity(0.28))
            }
            .buttonStyle(ScrollSnapButtonStyle.bouncy)
            
            // Right: ReplayKit Rolling Broadcast Capture (微信录屏长截)
            Button {
                HapticFeedbackManager.shared.triggerSelection()
                isShowingBroadcastGuide = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    RadialGradient(
                        colors: [Color.orange.opacity(0.12), Color.clear],
                        center: .topTrailing,
                        startRadius: 8,
                        endRadius: 90
                    )
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            LiquidGlassIconPod(
                                systemName: "record.circle.fill",
                                tint: Color.orange,
                                size: 38,
                                cornerRadius: ScrollSnapTheme.Radius.sm
                            )
                            Spacer()
                            ScrollSnapBadge("免切回", tint: .orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("滚动录屏截取")
                                .font(ScrollSnapTheme.FontToken.itemTitle)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text("边滑边录自动拼长图")
                                .font(ScrollSnapTheme.FontToken.captionHint)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    .padding(13)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 108)
                .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg, strokeColor: Color.orange.opacity(0.28))
            }
            .buttonStyle(ScrollSnapButtonStyle.bouncy)
        }
    }
    
    private var recentStitchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("历史长截图")
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
                    
                    Text("左右滑动浏览示例 · 点击卡片体验编辑器")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
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
        processingStatusMessage = "正在拼接录屏画面..."
        isProcessingStitch = true
        
        Task {
            do {
                let session = try await StitchEngine.shared.stitchSlices(
                    fileRelativePaths: activeBroadcastSlices,
                    source: .replayKitBroadcast,
                    presetMode: .smartAuto
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
        
        processingStatusMessage = "正在读取并拼接截图..."
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
    
    private func handleSelectedVideoPickerItem(_ items: [PhotosPickerItem]) {
        guard let item = items.first else { return }
        guard quotaManager.canStitch() else {
            isShowingPaywall = true
            self.selectedVideoPickerItems.removeAll()
            return
        }
        
        processingStatusMessage = "正在提取视频画面..."
        isProcessingStitch = true
        Task {
            var tempURL: URL?
            if let movie = try? await item.loadTransferable(type: MovieFile.self) {
                tempURL = movie.url
            } else if let movieData = try? await item.loadTransferable(type: Data.self) {
                let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("imported_\(UUID().uuidString).mov")
                try? movieData.write(to: fallback)
                tempURL = fallback
            }
            
            guard let videoURL = tempURL else {
                await MainActor.run {
                    self.isProcessingStitch = false
                    self.selectedVideoPickerItems.removeAll()
                    self.showToast(message: "无法直接读取选中的视频，请确认相册权限或重试")
                }
                return
            }
            
            let avAsset = AVAsset(url: videoURL)
            do {
                let frames = try await VideoFrameExtractor.shared.extractFrames(from: avAsset) { current, total in
                    Task { @MainActor in
                        HapticFeedbackManager.shared.triggerDialDetent()
                    }
                }
                guard frames.count >= 2 else {
                    await MainActor.run {
                        self.isProcessingStitch = false
                        self.selectedVideoPickerItems.removeAll()
                        self.showToast(message: "视频中未检测到足够的滑动画面")
                    }
                    return
                }
                
                var paths: [String] = []
                for (index, frame) in frames.enumerated() {
                    if let data = frame.jpegData(compressionQuality: 0.9),
                       let path = SharedStore.shared.writeBroadcastSlice(data: data, index: index) {
                        paths.append(path)
                    }
                }
                
                let session = try await StitchEngine.shared.stitchSlices(fileRelativePaths: paths, source: .photoLibrary)
                await MainActor.run {
                    self.activeSessionToEdit = session
                    self.isProcessingStitch = false
                    self.selectedVideoPickerItems.removeAll()
                }
            } catch {
                await MainActor.run {
                    self.isProcessingStitch = false
                    self.selectedVideoPickerItems.removeAll()
                    self.showToast(message: "视频抽帧拼接失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func quickSaveRecentAssets(_ assets: [PHAsset], deleteOriginals: Bool) {
        guard quotaManager.canStitch() else {
            isShowingPaywall = true
            return
        }
        
        processingStatusMessage = "正在读取并拼接 \(assets.count) 张截图..."
        isProcessingStitch = true
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        
        Task.detached(priority: .userInitiated) {
            var paths: [String] = []
            let sortedAssets = assets.sorted { ($0.creationDate ?? Date.distantPast) < ($1.creationDate ?? Date.distantPast) }
            for (index, asset) in sortedAssets.enumerated() {
                imageManager.requestImageDataAndOrientation(for: asset, options: requestOptions) { data, _, _, _ in
                    if let data = data,
                       let path = SharedStore.shared.writeBroadcastSlice(data: data, index: index) {
                        paths.append(path)
                    }
                }
            }
            
            guard paths.count >= 2 else {
                await MainActor.run {
                    self.isProcessingStitch = false
                    self.showToast(message: "相册未能获取到完整截图数据，请检查网络或重新选取")
                }
                return
            }
            
            do {
                let session = try await StitchEngine.shared.stitchSlices(fileRelativePaths: paths, source: .photoLibrary)
                let tempOutput = FileManager.default.temporaryDirectory.appendingPathComponent("ScrollSnap_\(Int(Date().timeIntervalSince1970)).jpg")
                try TiledImageRenderer.renderStitchedImageToFile(session: session, outputURL: tempOutput, format: .jpeg, quality: 0.95)
                
                #if canImport(UIKit)
                guard let image = UIImage(contentsOfFile: tempOutput.path) else {
                    await MainActor.run { self.isProcessingStitch = false }
                    return
                }
                
                let isPro = await MainActor.run { self.storeKit.isProUser }
                let watermarked = ExportWatermarkManager.shared.appendWatermarkIfNeeded(to: image, isProUser: isPro)
                
                // 1. Save stitched image to photo library
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: watermarked)
                }
                
                // 2. If user opted to delete raw temporary slices, request system deletion
                if deleteOriginals {
                    try? await PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.deleteAssets(sortedAssets as NSArray)
                    }
                }
                #endif
                
                await MainActor.run {
                    self.isProcessingStitch = false
                    self.quotaManager.recordStitchUsage()
                    self.lastSavedImage = watermarked
                    HapticFeedbackManager.shared.triggerSnap()
                    SoundEffectManager.shared.playShutter()
                    StoreReviewManager.shared.recordSuccessfulExport()
                    let msg = deleteOriginals ? "已保存长图，并已删除 \(sortedAssets.count) 张原截图" : "已保存长图至相册"
                    self.showToast(message: msg)
                    self.photoObserver.scanRecentScreenshots()
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
        
        processingStatusMessage = "正在拼接截图..."
        isProcessingStitch = true
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        
        Task.detached(priority: .userInitiated) {
            var paths: [String] = []
            let sortedAssets = assets.sorted { ($0.creationDate ?? Date.distantPast) < ($1.creationDate ?? Date.distantPast) }
            for (index, asset) in sortedAssets.enumerated() {
                imageManager.requestImageDataAndOrientation(for: asset, options: requestOptions) { data, _, _, _ in
                    if let data = data,
                       let path = SharedStore.shared.writeBroadcastSlice(data: data, index: index) {
                        paths.append(path)
                    }
                }
            }
            
            guard paths.count >= 2 else {
                await MainActor.run {
                    self.isProcessingStitch = false
                    self.showToast(message: "相册未能获取到完整截图数据，请检查网络或重新选取")
                }
                return
            }
            
            if let session = try? await StitchEngine.shared.stitchSlices(
                fileRelativePaths: paths,
                source: .photoLibrary,
                sourceAssetIdentifiers: sortedAssets.map(\.localIdentifier)
            ) {
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
    
    private func stitchVideoAsset(_ asset: PHAsset, deleteOriginalVideo: Bool, openInEditor: Bool = false) {
        guard quotaManager.canStitch() else {
            isShowingPaywall = true
            return
        }
        
        processingStatusMessage = "正在提取并合成长图..."
        isProcessingStitch = true
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            guard let avAsset = avAsset else {
                Task { @MainActor in
                    self.isProcessingStitch = false
                    self.showToast(message: "无法读取视频，可能正在从 iCloud 下载")
                }
                return
            }
            
            Task.detached(priority: .userInitiated) {
                do {
                    let frames = try await VideoFrameExtractor.shared.extractFrames(from: avAsset) { current, total in
                        Task { @MainActor in
                            HapticFeedbackManager.shared.triggerDialDetent()
                        }
                    }
                    guard frames.count >= 2 else {
                        await MainActor.run {
                            self.isProcessingStitch = false
                            self.showToast(message: "视频未能提取到足够的滚动画面")
                        }
                        return
                    }
                    
                    var paths: [String] = []
                    for (index, frame) in frames.enumerated() {
                        if let data = frame.jpegData(compressionQuality: 0.9),
                           let path = SharedStore.shared.writeBroadcastSlice(data: data, index: index) {
                            paths.append(path)
                        }
                    }
                    
                    let session = try await StitchEngine.shared.stitchSlices(
                        fileRelativePaths: paths,
                        source: .photoLibrary,
                        sourceAssetIdentifiers: [asset.localIdentifier]
                    )
                    
                    if openInEditor {
                        await MainActor.run {
                            self.activeSessionToEdit = session
                            self.isProcessingStitch = false
                        }
                        return
                    }
                    
                    let tempOutput = FileManager.default.temporaryDirectory.appendingPathComponent("ScrollSnap_Video_\(Int(Date().timeIntervalSince1970)).jpg")
                    try TiledImageRenderer.renderStitchedImageToFile(session: session, outputURL: tempOutput, format: .jpeg, quality: 0.95)
                    
                    #if canImport(UIKit)
                    guard let image = UIImage(contentsOfFile: tempOutput.path) else {
                        await MainActor.run { self.isProcessingStitch = false }
                        return
                    }
                    
                    let isPro = await MainActor.run { self.storeKit.isProUser }
                    let watermarked = ExportWatermarkManager.shared.appendWatermarkIfNeeded(to: image, isProUser: isPro)
                    
                    // 1. Save stitched image to photo library
                    try await PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAsset(from: watermarked)
                    }
                    
                    // 2. If requested, delete raw video
                    if deleteOriginalVideo {
                        try? await PHPhotoLibrary.shared().performChanges {
                            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
                        }
                    }
                    #endif
                    
                    await MainActor.run {
                        self.isProcessingStitch = false
                        self.quotaManager.recordStitchUsage()
                        self.lastSavedImage = watermarked
                        HapticFeedbackManager.shared.triggerSnap()
                        SoundEffectManager.shared.playShutter()
                        StoreReviewManager.shared.recordSuccessfulExport()
                        let msg = deleteOriginalVideo ? "已从录屏生成长图，并已删除原视频" : "已从录屏生成长图并保存至相册"
                        self.showToast(message: msg)
                        self.photoObserver.scanRecentScreenshots()
                    }
                } catch {
                    await MainActor.run {
                        self.isProcessingStitch = false
                    }
                }
            }
        }
    }
    private var sampleShowcaseCards: [ShowcaseStitchCard] {
        [
            ShowcaseStitchCard(
                id: "sample_chat",
                title: "微信研发群长对话",
                category: "聊天记录拼接",
                pixelHeight: "3,420 px",
                gradientColors: [Color(red: 0.12, green: 0.28, blue: 0.20), Color(red: 0.05, green: 0.14, blue: 0.10)],
                icon: "message.badge.filled.fill",
                preset: .chatRecord
            ),
            ShowcaseStitchCard(
                id: "sample_social",
                title: "小红书秋季穿搭清单",
                category: "九宫格切片",
                pixelHeight: "4,860 px",
                gradientColors: [Color(red: 0.35, green: 0.12, blue: 0.22), Color(red: 0.18, green: 0.05, blue: 0.12)],
                icon: "square.grid.3x3.fill",
                preset: .continuousFeed
            ),
            ShowcaseStitchCard(
                id: "sample_web",
                title: "Safari 苹果空间计算专栏",
                category: "长文去顶栏 · 带壳展示",
                pixelHeight: "14,890 px",
                gradientColors: [Color(red: 0.10, green: 0.16, blue: 0.32), Color(red: 0.05, green: 0.08, blue: 0.18)],
                icon: "safari.fill",
                preset: .webArticle
            )
        ]
    }
    
    private func openSampleShowcaseEditor(_ card: ShowcaseStitchCard) {
        let paths = ensureSampleSlicesExist(card: card)
        let slice1 = StitchItem(
            relativeFilePath: paths[0],
            originalWidth: 1170,
            originalHeight: 1800,
            topCropInset: card.preset.defaultTopCropInset,
            bottomCropInset: card.preset.defaultBottomCropInset,
            calculatedOverlapWithPrevious: 0,
            manualOffsetAdjustment: 0,
            optimalSeamLineY: 1700
        )
        let slice2 = StitchItem(
            relativeFilePath: paths[1],
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
    
    private func ensureSampleSlicesExist(card: ShowcaseStitchCard) -> [String] {
        let name1 = "sample_\(card.id)_1.jpg"
        let name2 = "sample_\(card.id)_2.jpg"
        let rel1 = "active_session/\(name1)"
        let rel2 = "active_session/\(name2)"
        
        let url1 = SharedStore.shared.resolveFileURL(relativePath: rel1)
        let url2 = SharedStore.shared.resolveFileURL(relativePath: rel2)
        
        if let u1 = url1, FileManager.default.fileExists(atPath: u1.path),
           let u2 = url2, FileManager.default.fileExists(atPath: u2.path) {
            return [rel1, rel2]
        }
        
        #if canImport(UIKit)
        let img1 = createSampleSliceImage(title: card.title, subtitle: card.category, part: 1)
        let img2 = createSampleSliceImage(title: card.title, subtitle: card.category, part: 2)
        
        if let d1 = img1.jpegData(compressionQuality: 0.9) {
            _ = SharedStore.shared.writeBroadcastSlice(data: d1, index: 101)
        }
        if let d2 = img2.jpegData(compressionQuality: 0.9) {
            _ = SharedStore.shared.writeBroadcastSlice(data: d2, index: 102)
        }
        return ["active_session/slice_101.jpg", "active_session/slice_102.jpg"]
        #else
        return ["sample_1.png", "sample_2.png"]
        #endif
    }
    
    #if canImport(UIKit)
    private func createSampleSliceImage(title: String, subtitle: String, part: Int) -> UIImage {
        let size = CGSize(width: 1170, height: 1800)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Dark elegant canvas background
            UIColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            // Top Navigation Bar Mockup
            let navRect = CGRect(x: 0, y: 0, width: size.width, height: 160)
            UIColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1.0).setFill()
            ctx.fill(navRect)
            
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 42, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .regular),
                .foregroundColor: UIColor.systemGray2
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92)
            ]
            
            (title as NSString).draw(at: CGPoint(x: 60, y: 64), withAttributes: titleAttrs)
            
            // Content Cards
            for i in 0..<4 {
                let cardY = CGFloat(200 + i * 360)
                let cardRect = CGRect(x: 50, y: cardY, width: size.width - 100, height: 320)
                let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 28)
                UIColor(red: 0.15, green: 0.16, blue: 0.20, alpha: 1.0).setFill()
                path.fill()
                
                // Avatar Pod
                let avatarRect = CGRect(x: 80, y: cardY + 30, width: 70, height: 70)
                let avatarPath = UIBezierPath(ovalIn: avatarRect)
                (i % 2 == 0 ? UIColor.systemIndigo : UIColor.systemTeal).setFill()
                avatarPath.fill()
                
                let itemTitle = "\(subtitle) · 示例切片 \(part)-\(i + 1)"
                (itemTitle as NSString).draw(at: CGPoint(x: 175, y: cardY + 45), withAttributes: titleAttrs)
                
                let body = "ScrollSnap 离线长截图工具。支持自动对齐、接缝滚轮微调、隐私涂抹保护与带壳样机海报。"
                let bodyRect = CGRect(x: 80, y: cardY + 130, width: size.width - 160, height: 160)
                (body as NSString).draw(in: bodyRect, withAttributes: bodyAttrs)
            }
        }
    }
    #endif
    
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
            ScrollView {
                VStack(spacing: 20) {
                    // Header Hero
                    VStack(spacing: 8) {
                        LiquidGlassIconPod(
                            systemName: "record.circle.fill",
                            tint: .orange,
                            size: 54,
                            cornerRadius: ScrollSnapTheme.Radius.md
                        )
                        Text("滚动录屏拼接长图")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                        Text("在微信、小红书或任意应用内匀速向下滑动屏幕，系统录屏将在后台自动提取画面并拼接成长图，无需多次截屏。")
                            .font(ScrollSnapTheme.FontToken.captionHint)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)
                    
                    #if canImport(ReplayKit)
                    // Quick Launch Action Box
                    VStack(spacing: 8) {
                        Text("快捷启动")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.orange.opacity(0.15))
                            
                            HStack(spacing: 8) {
                                Image(systemName: "record.circle.fill")
                                    .foregroundStyle(.orange)
                                Text("启动 ScrollSnap 录屏")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                            
                            // ReplayKit Broadcast Picker covering the button to receive tap
                            BroadcastPickerViewRepresentable(preferredExtension: "com.scrollsnap.broadcast")
                                .opacity(0.015)
                        }
                        .frame(height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 4)
                    #endif
                    
                    // 4 Step-by-Step Flow Cards
                    VStack(spacing: 12) {
                        guideStepCard(
                            stepNumber: "1",
                            title: "长按控制中心的录屏按钮",
                            description: "打开控制中心，长按录屏图标，勾选「ScrollSnap」后点击「开始直播」。",
                            iconName: "hand.tap.fill",
                            tint: .blue
                        )
                        guideStepCard(
                            stepNumber: "2",
                            title: "切换到目标应用",
                            description: "切回微信、网页或聊天记录等需要长截图的界面，等待 3 秒倒计时结束。",
                            iconName: "app.badge.fill",
                            tint: .purple
                        )
                        guideStepCard(
                            stepNumber: "3",
                            title: "匀速向下滑动",
                            description: "平稳向下滑动屏幕，系统会在后台自动去除重合部分。",
                            iconName: "arrow.down.circle.fill",
                            tint: .orange
                        )
                        guideStepCard(
                            stepNumber: "4",
                            title: "点击顶部红点停止录屏",
                            description: "滑完后点击灵动岛或状态栏红点停止录制，打开 ScrollSnap 即可查看长图。",
                            iconName: "checkmark.seal.fill",
                            tint: .green
                        )
                    }
                    
                    // Privacy & Performance Guarantee
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title3)
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("本地离线处理 · 不上传网络")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("所有录屏画面均在手机本地处理，不经过任何外部服务器。")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .scrollSnapCard(radius: ScrollSnapTheme.Radius.md, strokeColor: Color.teal.opacity(0.3))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("滚动录屏指南")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.body.weight(.bold))
                }
            }
        }
    }
    
    private func guideStepCard(stepNumber: String, title: String, description: String, iconName: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 36, height: 36)
                Text(stepNumber)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: iconName)
                        .font(.caption)
                        .foregroundStyle(tint)
                }
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg, strokeColor: tint.opacity(0.25))
    }
}

private struct ActionShortcutGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isCopiedShortcutName = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Hero
                    VStack(spacing: 8) {
                        LiquidGlassIconPod(
                            systemName: "iphone.radiowaves.left.and.right",
                            tint: .blue,
                            size: 54,
                            cornerRadius: ScrollSnapTheme.Radius.md
                        )
                        Text("轻点背面与操作按钮拼图")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                        Text("截屏后轻点手机背面两下，或长按侧边操作按钮，自动将最近截取的图片拼成长图并存入相册。")
                            .font(ScrollSnapTheme.FontToken.captionHint)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)
                    
                    // Quick Action Strip
                    HStack(spacing: 12) {
                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = "一键拼合长截图"
                            HapticFeedbackManager.shared.triggerSnap()
                            withAnimation { isCopiedShortcutName = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { isCopiedShortcutName = false }
                            }
                            #endif
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isCopiedShortcutName ? "checkmark" : "doc.on.doc.fill")
                                Text(isCopiedShortcutName ? "已复制指令名" : "复制快捷指令名称")
                            }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.18))
                            .foregroundStyle(Color.blue)
                            .clipShape(Capsule())
                        }
                        
                        Button {
                            #if canImport(UIKit)
                            if let url = URL(string: "shortcuts://") {
                                UIApplication.shared.open(url)
                            }
                            #endif
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                Text("打开快捷指令 App")
                            }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.08))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                        }
                    }
                    
                    // 2 Core Setup Methods
                    VStack(spacing: 14) {
                        // Method 1: Back Tap (Every iPhone)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                ScrollSnapBadge("方案 A · 所有 iPhone 通用", tint: .indigo)
                                Spacer()
                                Text("最推荐").font(.caption2.bold()).foregroundStyle(.indigo)
                            }
                            Text("轻点背面两下拼长图")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("1. 打开系统「设置」->「辅助功能」->「触控」；")
                                Text("2. 滑到最底部，点击「轻点背面」；")
                                Text("3. 选择「轻点两下」（或轻点三下）；")
                                Text("4. 在快捷指令列表勾选「ScrollSnap: 一键拼合长截图」。")
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg, strokeColor: Color.indigo.opacity(0.3))
                        
                        // Method 2: Action Button (15 Pro / 16)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                ScrollSnapBadge("方案 B · iPhone 15 Pro / 16", tint: .blue)
                                Spacer()
                                Text("侧键直出").font(.caption2.bold()).foregroundStyle(.blue)
                            }
                            Text("长按操作按钮 (Action Button)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("1. 打开系统「设置」->「操作按钮」；")
                                Text("2. 左右划动转盘，选择「快捷指令」；")
                                Text("3. 点击选取，选择「ScrollSnap: 一键拼合长截图」；")
                                Text("4. 截屏后长按操作按钮，自动完成拼接。")
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg, strokeColor: Color.blue.opacity(0.3))
                    }
                    
                    // Usage Scenario Callout
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.orange)
                            Text("使用示例")
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text("在微信中连续截几张图，轻敲手机背面两下听到快门提示音，回到聊天输入框长按粘贴即可发送。无需手动打开应用。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .scrollSnapCard(radius: ScrollSnapTheme.Radius.md, strokeColor: Color.orange.opacity(0.25))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("快捷拼图设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.body.weight(.bold))
                }
            }
        }
    }
}
