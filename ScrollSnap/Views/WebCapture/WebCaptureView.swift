import SwiftUI
import WebKit

public struct WebCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    public let onCaptured: (StitchSession) -> Void
    
    @State private var urlInputText: String = "https://apple.com"
    @State private var isLoading: Bool = false
    @State private var estimatedProgress: Double = 0.0
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var pageTitle: String = "网页长截图"
    @State private var isCapturing: Bool = false
    @State private var captureStatusHint: String = ""
    
    // Internal WebKit webView holder
    @State private var webView = WKWebView()
    
    public init(initialURL: URL? = nil, onCaptured: @escaping (StitchSession) -> Void) {
        if let initial = initialURL {
            self._urlInputText = State(initialValue: initial.absoluteString)
        }
        self.onCaptured = onCaptured
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Clean Navigation Bar
                urlSearchBar
                
                // Animated Loading Progress Strip
                if isLoading && estimatedProgress < 1.0 {
                    GeometryReader { p in
                        Rectangle()
                            .fill(ScrollSnapTheme.Colors.primaryGradient)
                            .frame(width: p.size.width * CGFloat(estimatedProgress), height: 2.5)
                            .animation(.linear(duration: 0.2), value: estimatedProgress)
                    }
                    .frame(height: 2.5)
                } else {
                    Divider()
                }
                
                // Native WebKit Viewport
                ZStack(alignment: .bottom) {
                    NativeWebViewRepresentable(
                        webView: webView,
                        isLoading: $isLoading,
                        progress: $estimatedProgress,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        pageTitle: $pageTitle
                    )
                    
                    // Floating Bottom Navigation & Capture Dock
                    bottomFloatingDock
                }
            }
            .navigationTitle(pageTitle.isEmpty ? "网页长截图" : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .font(.body)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        captureFullPage()
                    } label: {
                        if isCapturing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("截全页")
                                .font(.system(.body, design: .rounded).weight(.bold))
                        }
                    }
                    .disabled(isCapturing || isLoading)
                }
            }
            .onAppear {
                loadURL(urlString: urlInputText)
            }
        }
    }
    
    // MARK: - Search & URL Bar
    
    private var urlSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            
            TextField("输入或粘贴网址...", text: $urlInputText)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15))
                .onSubmit {
                    loadURL(urlString: urlInputText)
                }
            
            if !urlInputText.isEmpty {
                Button {
                    urlInputText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if isLoading {
                Button {
                    webView.stopLoading()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    loadURL(urlString: urlInputText)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
    
    // MARK: - Bottom Floating Safari Dock
    
    private var bottomFloatingDock: some View {
        HStack(spacing: 20) {
            // Backward Button
            Button {
                webView.goBack()
                HapticFeedbackManager.shared.triggerSelection()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
            }
            .disabled(!canGoBack)
            
            // Forward Button
            Button {
                webView.goForward()
                HapticFeedbackManager.shared.triggerSelection()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .disabled(!canGoForward)
            
            // Paste Clipboard Link
            Button {
                pasteFromClipboard()
            } label: {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
            }
            
            Spacer()
            
            // Primary One-Click Full-Page Capture Capsule
            Button {
                captureFullPage()
            } label: {
                HStack(spacing: 6) {
                    if isCapturing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text(captureStatusHint.isEmpty ? "渲染中..." : captureStatusHint)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    } else {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 14, weight: .bold))
                        Text("截取整页")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(ScrollSnapTheme.Colors.primaryGradient)
                .clipShape(Capsule())
                .shadow(color: Color.indigo.opacity(0.35), radius: 8, y: 3)
            }
            .disabled(isCapturing || isLoading)
            .buttonStyle(ScrollSnapButtonStyle.bouncy)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .liquidGlassPill()
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Logic
    
    private func pasteFromClipboard() {
        #if canImport(UIKit)
        if let clip = UIPasteboard.general.string {
            let extracted = cleanExtractURL(from: clip)
            self.urlInputText = extracted
            loadURL(urlString: extracted)
            HapticFeedbackManager.shared.triggerSnap()
        }
        #endif
    }
    
    private func cleanExtractURL(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find embedded http/https URL if user pasted mixed text
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let match = detector.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)),
           let range = Range(match.range, in: trimmed) {
            let found = String(trimmed[range])
            return sanitizeURLString(found)
        }
        
        return sanitizeURLString(trimmed)
    }
    
    private func sanitizeURLString(_ string: String) -> String {
        var formatted = string
        if !formatted.hasPrefix("http://") && !formatted.hasPrefix("https://") {
            formatted = "https://" + formatted
        }
        guard var components = URLComponents(string: formatted) else {
            return formatted
        }
        
        // Strip common tracking queries for cleaner screenshots and privacy protection
        let trackingKeys: Set<String> = [
            "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
            "spm_id_from", "from_source", "from=singlemessage", "isappinstalled",
            "fbclid", "gclid", "share_token"
        ]
        
        if let queryItems = components.queryItems {
            let filtered = queryItems.filter { !trackingKeys.contains($0.name.lowercased()) }
            components.queryItems = filtered.isEmpty ? nil : filtered
        }
        
        return components.url?.absoluteString ?? formatted
    }
    
    private func loadURL(urlString: String) {
        let sanitized = sanitizeURLString(urlString)
        self.urlInputText = sanitized
        if let url = URL(string: sanitized) {
            webView.load(URLRequest(url: url))
        }
    }
    
    private func captureFullPage() {
        guard !isCapturing else { return }
        isCapturing = true
        captureStatusHint = "正在生成完整网页长截图..."
        HapticFeedbackManager.shared.triggerSnap()
        
        // 优先使用 iOS 原生 WebKit createPDF 生成全页长图（零黑屏、完整捕获视口外所有内容）
        let pdfConfiguration = WKPDFConfiguration()
        
        webView.createPDF(configuration: pdfConfiguration) { result in
            switch result {
            case .success(let pdfData):
                if let renderedImage = self.renderPDFDataToImage(pdfData),
                   let data = renderedImage.jpegData(compressionQuality: 0.92) {
                    self.finishWebCapture(image: renderedImage, data: data)
                    return
                }
                // 若 PDF 栅格化失败，走备用快照逻辑
                self.fallbackSnapshotCapture()
                
            case .failure:
                self.fallbackSnapshotCapture()
            }
        }
    }
    
    private func fallbackSnapshotCapture() {
        let fallbackConfig = WKSnapshotConfiguration()
        fallbackConfig.afterScreenUpdates = true
        self.webView.takeSnapshot(with: fallbackConfig) { fallbackImg, error in
            if let fallbackImg = fallbackImg, let fallbackData = fallbackImg.jpegData(compressionQuality: 0.92) {
                self.finishWebCapture(image: fallbackImg, data: fallbackData)
            } else {
                self.isCapturing = false
                self.captureStatusHint = "截图失败，请刷新页面后重试"
                HapticFeedbackManager.shared.triggerWarning()
            }
        }
    }
    
    private func renderPDFDataToImage(_ data: Data) -> UIImage? {
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider),
              let page = document.page(at: 1) else {
            return nil
        }
        
        let pageRect = page.getBoxRect(.mediaBox)
        guard pageRect.width > 0, pageRect.height > 0 else { return nil }
        
        // 保证清晰度同时控制内存占用，最大宽度 1170（Retina 宽度）
        let targetWidth: CGFloat = min(max(pageRect.width * 2.0, 750), 1170)
        let scale = targetWidth / pageRect.width
        let scaledHeight = pageRect.height * scale
        let targetHeight = min(scaledHeight, 18000) // 最大高度上限
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: 0, y: targetSize.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            ctx.cgContext.drawPDFPage(page)
            ctx.cgContext.restoreGState()
        }
    }
    
    private func finishWebCapture(image: UIImage, data: Data) {
        if let path = SharedStore.shared.writeBroadcastSlice(data: data, index: 0) {
            let item = StitchItem(
                relativeFilePath: path,
                originalWidth: image.size.width * image.scale,
                originalHeight: image.size.height * image.scale,
                calculatedOverlapWithPrevious: 0,
                manualOffsetAdjustment: 0,
                optimalSeamLineY: 0
            )
            
            let titleClean = pageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let session = StitchSession(
                source: .webViewFullPage,
                presetMode: .webArticle,
                slices: [item],
                title: titleClean.isEmpty ? "网页长截图_\(Int(Date().timeIntervalSince1970))" : titleClean
            )
            
            HapticFeedbackManager.shared.triggerSuccess()
            SoundEffectManager.shared.playShutter()
            
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onCaptured(session)
            }
        }
        isCapturing = false
    }
}

// MARK: - Native WebKit UIViewRepresentable with KVO Binding

private struct NativeWebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    @Binding var isLoading: Bool
    @Binding var progress: Double
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var pageTitle: String
    
    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        context.coordinator.setupObservers(for: webView)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: NativeWebViewRepresentable
        private var observations: [NSKeyValueObservation] = []
        
        init(_ parent: NativeWebViewRepresentable) {
            self.parent = parent
        }
        
        func setupObservers(for webView: WKWebView) {
            observations.append(
                webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                    Task { @MainActor in
                        self?.parent.progress = wv.estimatedProgress
                    }
                }
            )
            observations.append(
                webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in
                    Task { @MainActor in
                        self?.parent.canGoBack = wv.canGoBack
                    }
                }
            )
            observations.append(
                webView.observe(\.canGoForward, options: [.new]) { [weak self] wv, _ in
                    Task { @MainActor in
                        self?.parent.canGoForward = wv.canGoForward
                    }
                }
            )
            observations.append(
                webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
                    Task { @MainActor in
                        if let title = wv.title, !title.isEmpty {
                            self?.parent.pageTitle = title
                        }
                    }
                }
            )
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        deinit {
            observations.removeAll()
        }
    }
}
