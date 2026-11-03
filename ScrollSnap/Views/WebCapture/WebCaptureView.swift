import SwiftUI
import WebKit

public struct WebCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    public let onCaptured: (StitchSession) -> Void
    
    @State private var urlString: String = "https://apple.com"
    @State private var isLoading: Bool = false
    @State private var webView = WKWebView()
    @State private var isCapturing: Bool = false
    
    public init(onCaptured: @escaping (StitchSession) -> Void) {
        self.onCaptured = onCaptured
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top URL Bar
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                    
                    TextField("输入网址...", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            loadURL()
                        }
                    
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button {
                            loadURL()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                
                Divider()
                
                // Native Web View Container
                WebViewRepresentable(webView: webView, urlString: urlString, isLoading: $isLoading)
            }
            .navigationTitle("网页全页长截图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        captureFullPage()
                    } label: {
                        if isCapturing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("一键全截")
                                .font(.system(.body, design: .rounded).weight(.bold))
                        }
                    }
                    .disabled(isCapturing || isLoading)
                }
            }
            .onAppear {
                loadURL()
            }
        }
    }
    
    private func loadURL() {
        var formatted = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.hasPrefix("http://") && !formatted.hasPrefix("https://") {
            formatted = "https://" + formatted
        }
        if let url = URL(string: formatted) {
            webView.load(URLRequest(url: url))
        }
    }
    
    private func captureFullPage() {
        isCapturing = true
        HapticFeedbackManager.shared.triggerSnap()
        
        // Execute javascript to fetch accurate full document height across SPAs and standard HTML5 pages
        let heightScript = "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight, document.body.offsetHeight, document.documentElement.offsetHeight, 1000)"
        webView.evaluateJavaScript(heightScript) { result, _ in
            let scrollHeight = (result as? CGFloat) ?? 1200
            let captureWidth = max(webView.bounds.width, 393)
            
            let config = WKSnapshotConfiguration()
            config.rect = CGRect(x: 0, y: 0, width: captureWidth, height: min(scrollHeight, 16000))
            config.afterScreenUpdates = true
            
            webView.takeSnapshot(with: config) { image, error in
                guard let image = image, let data = image.jpegData(compressionQuality: 0.9) else {
                    isCapturing = false
                    return
                }
                
                if let path = SharedStore.shared.writeBroadcastSlice(data: data, index: 0) {
                    let item = StitchItem(
                        relativeFilePath: path,
                        originalWidth: image.size.width * image.scale,
                        originalHeight: image.size.height * image.scale,
                        calculatedOverlapWithPrevious: 0,
                        manualOffsetAdjustment: 0,
                        optimalSeamLineY: 0
                    )
                    
                    let session = StitchSession(
                        source: .webViewFullPage,
                        slices: [item],
                        title: "WebCapture_\(Int(Date().timeIntervalSince1970))"
                    )
                    
                    HapticFeedbackManager.shared.triggerSuccess()
                    onCaptured(session)
                    dismiss()
                }
                isCapturing = false
            }
        }
    }
}

private struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    let urlString: String
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
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
    }
}
