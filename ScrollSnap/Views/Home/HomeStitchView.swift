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
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var activeSessionToEdit: StitchSession?
    @State private var isShowingWebCapture = false
    @State private var isShowingSettings = false
    @State private var isShowingPaywall = false
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
    @State private var completedStitchFiles: [URL] = []
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Photo Permission Denied / Restricted Warning Banner
                    if photoObserver.authorizationStatus == .denied || photoObserver.authorizationStatus == .restricted {
                        photoPermissionDeniedBanner
                    }
                    
                    // Intelligent Contextual Hub: Single highest priority action to avoid banner fatigue
                    smartContextualHub
                    
                    // Core Actions Grid
                    coreActionsGrid
                    
                    // Recent Stitched Works
                    recentStitchesSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("长截图")
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
                        if storeKit.isProUser {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                                Text("永久会员")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                        } else {
                            HStack(spacing: 4) {
                                Text("免费版")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                Text("\(quotaManager.remainingDailyFreeStitches)/\(QuotaManager.defaultDailyLimit)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                            .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(item: $activeSessionToEdit, onDismiss: {
                refreshCompletedStitches()
                AppCacheManager.shared.clearTemporaryCache()
            }) { session in
                StitchEditorView(session: session)
            }
            .sheet(isPresented: $isShowingWebCapture) {
                WebCaptureView { newSession in
                    self.activeSessionToEdit = newSession
                }
            }
            .sheet(isPresented: $isShowingSettings, onDismiss: {
                refreshCompletedStitches()
            }) {
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
                refreshCompletedStitches()
                checkClipboardForURL()
                if WhatsNewManager.shared.shouldShowWhatsNew() {
                    isShowingWhatsNew = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshBroadcastSession"))) { _ in
                refreshActiveBroadcastSlices()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshCompletedStitches"))) { _ in
                refreshCompletedStitches()
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
        .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg)
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
                HStack(spacing: 6) {
                    Text("滚动录屏完成")
                        .font(ScrollSnapTheme.FontToken.itemTitle)
                    ScrollSnapBadge("\(activeBroadcastSlices.count) 屏", tint: .orange)
                }
                Text("轻触立即拼接为长图")
                    .font(ScrollSnapTheme.FontToken.captionHint)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("一键拼长图") {
                HapticFeedbackManager.shared.triggerSnap()
                stitchActiveBroadcastSlices()
            }
            .font(.system(.caption, design: .rounded).weight(.bold))
            .padding(.horizontal, ScrollSnapTheme.Spacing.md)
            .padding(.vertical, ScrollSnapTheme.Spacing.xs)
            .background(Color.orange)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    SharedStore.shared.resetActiveBroadcastSession()
                    refreshActiveBroadcastSlices()
                }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(ScrollSnapButtonStyle.circleDismiss)
        }
        .padding(ScrollSnapTheme.Spacing.md)
        .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg)
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
        .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg)
    }
    
    private func recentScreenRecordingBanner(_ video: PHAsset) -> some View {
        let durationSec = max(1, Int(video.duration))
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "film.stack.fill")
                    .font(.body)
                    .foregroundStyle(Color.purple)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("相册新录屏")
                        .font(ScrollSnapTheme.FontToken.itemTitle)
                    ScrollSnapBadge("\(durationSec)s", tint: .purple)
                }
                Text("自动提取画面并拼接为长图")
                    .font(ScrollSnapTheme.FontToken.captionHint)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button("转为长图") {
                HapticFeedbackManager.shared.triggerSnap()
                stitchVideoAsset(video, deleteOriginalVideo: false, openInEditor: true)
            }
            .font(.system(.caption, design: .rounded).weight(.bold))
            .padding(.horizontal, ScrollSnapTheme.Spacing.md)
            .padding(.vertical, ScrollSnapTheme.Spacing.xs)
            .background(Color.purple)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .disabled(isProcessingStitch)
            
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isDismissedRecentVideo = true
                }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(ScrollSnapButtonStyle.circleDismiss)
        }
        .padding(ScrollSnapTheme.Spacing.md)
        .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg)
    }
    
    private var recentDetectedScreenshotsBanner: some View {
        let count = photoObserver.recentScreenshotAssets.count
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("检测到连续截图")
                        .font(ScrollSnapTheme.FontToken.itemTitle)
                    ScrollSnapBadge("\(count) 张", tint: .accentColor)
                }
                Text("已按时间排好顺序，可直接拼接")
                    .font(ScrollSnapTheme.FontToken.captionHint)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button("一键拼接") {
                HapticFeedbackManager.shared.triggerSnap()
                stitchRecentAssets(photoObserver.recentScreenshotAssets)
            }
            .font(.system(.caption, design: .rounded).weight(.bold))
            .padding(.horizontal, ScrollSnapTheme.Spacing.md)
            .padding(.vertical, ScrollSnapTheme.Spacing.xs)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .disabled(isProcessingStitch)
            
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isDismissedRecentScreenshots = true
                }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(ScrollSnapButtonStyle.circleDismiss)
        }
        .padding(ScrollSnapTheme.Spacing.md)
        .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg)
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
        VStack(spacing: 12) {
            // Main Hero Action Card: Photos Picker
            PhotosPicker(
                selection: $selectedPhotoItems,
                matching: .screenshots,
                photoLibrary: .shared()
            ) {
                HStack(spacing: 16) {
                    LiquidGlassIconPod(
                        systemName: "photo.on.rectangle.angled",
                        tint: Color.accentColor,
                        size: 46,
                        cornerRadius: ScrollSnapTheme.Radius.md
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("选择截图拼接")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("从相册选择连续截图自动拼接")
                            .font(ScrollSnapTheme.FontToken.captionHint)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg)
            }
            .buttonStyle(ScrollSnapButtonStyle.bouncy)
            
            // Sub Actions Row 1: Real Tools (录屏转长图 & 网页长截图)
            HStack(spacing: 10) {
                // Screen Recording Video Picker
                PhotosPicker(
                    selection: $selectedVideoPickerItems,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    actionCard(
                        title: "录屏转长图",
                        subtitle: "相册视频自动提取",
                        iconName: "film.stack.fill",
                        tint: Color.accentColor,
                        tag: "相册"
                    )
                }
                .buttonStyle(ScrollSnapButtonStyle.bouncy)
                
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
                        title: "网页长截图",
                        subtitle: "输入网址整页截取",
                        iconName: "safari.fill",
                        tint: Color.accentColor,
                        tag: "网页"
                    )
                }
                .buttonStyle(ScrollSnapButtonStyle.bouncy)
            }
            
            // Sub Actions Row 2: Guides & Shortcuts (滚动录屏指南 & 轻点背面快捷拼)
            HStack(spacing: 10) {
                // Rolling Screen Recording Capture Guide
                Button {
                    HapticFeedbackManager.shared.triggerSelection()
                    isShowingBroadcastGuide = true
                } label: {
                    actionCard(
                        title: "滚动录屏长截",
                        subtitle: "边录屏边滑动拼图",
                        iconName: "record.circle.fill",
                        tint: Color.accentColor,
                        tag: "免切"
                    )
                }
                .buttonStyle(ScrollSnapButtonStyle.bouncy)
                
                // Action Button / Back Tap Shortcut Guide
                Button {
                    HapticFeedbackManager.shared.triggerSelection()
                    isShowingActionShortcutGuide = true
                } label: {
                    actionCard(
                        title: "轻点背面快捷拼",
                        subtitle: "轻敲手机直接拼长图",
                        iconName: "iphone.radiowaves.left.and.right",
                        tint: Color.accentColor,
                        tag: "快捷"
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 104)
        .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg)
    }
    
    private var recentStitchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(completedStitchFiles.isEmpty ? "最近保存" : "最近保存 (\(completedStitchFiles.count))")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !completedStitchFiles.isEmpty {
                    Button("清空") {
                        clearCompletedHistory()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            
            if !completedStitchFiles.isEmpty {
                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ]
                
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(completedStitchFiles, id: \.path) { fileURL in
                        let item = CompletedStitchItem(id: fileURL.path, url: fileURL)
                        if let image = UIImage(contentsOfFile: fileURL.path) {
                            Button {
                                HapticFeedbackManager.shared.triggerSelection()
                                openCompletedStitch(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    ZStack(alignment: .bottomTrailing) {
                                        Color(uiColor: .secondarySystemGroupedBackground)
                                            .frame(height: 220)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 208)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .padding(6)
                                        
                                        // 一键快捷复制按钮
                                        Button {
                                            UIPasteboard.general.image = image
                                            HapticFeedbackManager.shared.triggerSnap()
                                            showToast(message: "已复制长截图到剪贴板")
                                        } label: {
                                            HStack(spacing: 3) {
                                                Image(systemName: "doc.on.doc")
                                                    .font(.system(size: 10, weight: .semibold))
                                                Text("复制")
                                                    .font(.system(size: 11, weight: .semibold))
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.ultraThinMaterial, in: Capsule())
                                            .foregroundStyle(.primary)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(8)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                                    )
                                    
                                    HStack {
                                        Text("\(Int(image.size.width * image.scale)) × \(Int(image.size.height * image.scale))")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    
                    Text("暂无长截图历史，保存后的长图会在此显示")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
    
    private func refreshCompletedStitches() {
        let dir = AppGroupConstants.completedStitchesDirectory
        let items = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        self.completedStitchFiles = items
            .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
            .sorted(by: {
                let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return d1 > d2
            })
    }
    
    private func clearCompletedHistory() {
        let dir = AppGroupConstants.completedStitchesDirectory
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.completedStitchFiles = []
        HapticFeedbackManager.shared.triggerSelection()
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
            defer {
                if let url = tempURL {
                    try? FileManager.default.removeItem(at: url)
                }
            }
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
                defer {
                    try? FileManager.default.removeItem(at: tempOutput)
                }
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
                
                if let jpegData = watermarked.jpegData(compressionQuality: 0.90) {
                    SharedStore.shared.saveCompletedStitch(data: jpegData)
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
                    self.refreshCompletedStitches()
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
                    defer {
                        try? FileManager.default.removeItem(at: tempOutput)
                    }
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
                    
                    if let jpegData = watermarked.jpegData(compressionQuality: 0.90) {
                        SharedStore.shared.saveCompletedStitch(data: jpegData)
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
                        self.refreshCompletedStitches()
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
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
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
