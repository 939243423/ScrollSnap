import SwiftUI
import Photos
#if canImport(UIKit)
import UIKit
#endif

public enum EditorToolMode: String, CaseIterable, Identifiable {
    case seamTuner = "调接缝"
    case privacyBrush = "打码"
    case annotation = "标注"
    case socialSlicer = "切图"
    
    public var id: String { rawValue }
    public var iconName: String {
        switch self {
        case .seamTuner: return "arrow.up.and.down"
        case .privacyBrush: return "eye.slash"
        case .annotation: return "pencil.tip"
        case .socialSlicer: return "square.grid.3x3"
        }
    }
}

public struct StitchEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var quotaManager = QuotaManager.shared
    @StateObject private var storeKit = StoreKitManager.shared
    @StateObject private var privacySanitizer = PrivacySanitizer.shared
    @StateObject private var textExtractor = TextExtractor.shared
    
    @State var session: StitchSession
    @State private var activeToolMode: EditorToolMode? = nil
    
    // Seam Fine-tuning State
    @State private var selectedSliceIndex: Int = 1
    @State private var seamDialOffset: CGFloat = 0.0
    @State private var seamDragStartOffset: CGFloat = 0.0
    
    // Privacy Redaction & Brush State
    @State private var brushStrokes: [RedactionStroke] = []
    @State private var redactionShapeMode: RedactionShapeMode = .brush
    @State private var redactionStyleChoice: RedactionStyleChoice = .mosaic
    @State private var brushStrokeWidth: CGFloat = 28.0
    @State private var currentBrushStroke: RedactionStroke? = nil
    
    // Annotation Suite State
    @State private var canvasInteractionMode: CanvasInteractionMode = .draw
    @State private var annotations: [AnnotationItem] = []
    @State private var activeAnnotationKind: AnnotationKind = .highlighter
    @State private var activeAnnotationColor: AnnotationColor = .crimsonRed
    @State private var annotationLineWidth: CGFloat = 3.5
    @State private var nextStepBadgeNumber: Int = 1
    @State private var currentDrawingItem: AnnotationItem?
    @State private var selectedAnnotationId: UUID? = nil
    @State private var textInputPrompt: String = ""
    @State private var isShowingTextAlert: Bool = false
    @State private var pendingTextLocation: CGPoint = .zero
    
    // Interactive Loupe (Magnifying Glass) State
    @State private var isShowingLoupe: Bool = false
    @State private var loupePosition: CGPoint = .zero
    @State private var loupeDisplayPosition: CGPoint? = nil
    
    // Canvas & Comparison State
    @StateObject private var scrollController = CanvasScrollController()
    @State private var canvasZoomScale: CGFloat = 1.0
    @State private var isShowingComparisonSheet: Bool = false
    @State private var comparisonBeforeImage: UIImage?
    @State private var comparisonAfterImage: UIImage?
    
    // Social Slicer State
    @State private var selectedSlicePreset: ImageSlicer.SlicePreset = .nine
    @State private var generatedSlices: [UIImage] = []
    @State private var isSlicing: Bool = false
    @State private var isShowingSlicesSavedAlert: Bool = false
    
    // OCR Text Extraction State
    @State private var isShowingTextExtractorSheet: Bool = false
    @State private var extractedFullText: String = ""
    
    // Export State
    @State private var selectedExportFormat: ExportFormat = .jpeg
    @State private var isShowingExportSheet: Bool = false
    @State private var exportedFileURL: URL?
    @State private var isExporting: Bool = false
    @State private var isShowingPaywall: Bool = false
    @State private var isCopiedToClipboardToast: Bool = false
    @State private var toastMessage: String = "长图已复制到剪贴板"
    @State private var isDismissedConfidenceWarning: Bool = false
    
    private var hasLowConfidenceSeams: Bool {
        session.slices.dropFirst().contains { $0.confidence < 0.35 }
    }
    
    public init(session: StitchSession) {
        self._session = State(initialValue: session)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main Interactive Canvas
                canvasScrollView
                
                // Seam Intelligence Hint

                
                // Floating Quick Scrubber (Docked on Right Edge)
                if session.presetMode != .horizontalCompare {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            CanvasMinimapView(controller: scrollController)
                                .padding(.trailing, 2)
                        }
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .allowsHitTesting(activeToolMode != .annotation && activeToolMode != .privacyBrush || canvasInteractionMode == .browse)
                }
                
                // Floating Zoom Reset Pill (shown when zoomed in)
                if canvasZoomScale > 1.1 {
                    VStack {
                        HStack {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    canvasZoomScale = 1.0
                                }
                                HapticFeedbackManager.shared.triggerSelection()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("恢复原比例")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                                .foregroundStyle(.primary)
                                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 16)
                            .padding(.top, 8)
                            Spacer()
                        }
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                
                // Bottom Liquid Glass Floating Modular Control Bar
                bottomLiquidControlBar
                
                // Magnifying Loupe Overlay when inspecting fine details
                if isShowingLoupe {
                    InteractiveLoupeView(
                        touchPosition: loupePosition,
                        displayPosition: loupeDisplayPosition,
                        onDismiss: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                isShowingLoupe = false
                            }
                        }
                    ) {
                        annotatedCanvasStack
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.7).combined(with: .opacity),
                        removal: .scale(scale: 0.85).combined(with: .opacity)
                    ))
                }
                
                // Copied to Clipboard Notification Toast
                if isCopiedToClipboardToast {
                    clipboardToastView
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(session.presetMode.title + "长截图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(7)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .accessibilityLabel("关闭")
                }
                
                ToolbarItem(placement: .principal) {
                    presetModeMenu
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            prepareAndOpenComparisonSheet()
                        } label: {
                            Image(systemName: "rectangle.split.2x1")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(6)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("对比与浏览")
                        .buttonStyle(ScrollSnapButtonStyle.bouncy)
                        
                        Button {
                            copyDirectlyToClipboard()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(6)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .keyboardShortcut("c", modifiers: .command)
                        .accessibilityLabel("复制长截图")
                        .buttonStyle(ScrollSnapButtonStyle.bouncy)
                        
                        Button {
                            saveDirectlyToAlbum()
                        } label: {
                            HStack(spacing: 5) {
                                if isExporting {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                Text("存相册")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5.5)
                            .background(ScrollSnapTheme.Colors.primaryGradient)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                        .keyboardShortcut("s", modifiers: .command)
                        .accessibilityLabel("保存长截图到相册")
                        .disabled(isExporting)
                        .buttonStyle(ScrollSnapButtonStyle.bouncy)
                        
                        Menu {
                            Section("微信分享") {
                                Button {
                                    copyDirectlyToClipboard(isWeChatSharing: true)
                                } label: {
                                    Label("复制长图发微信", systemImage: "paperplane")
                                }
                            }
                            if !session.sourceAssetIdentifiers.isEmpty {
                                Section("清理") {
                                    Button {
                                        saveDirectlyToAlbum(deleteOriginals: true)
                                    } label: {
                                        Label("存长图并删除原截图", systemImage: "trash.slash")
                                    }
                                }
                            }
                            Section("对比") {
                                Button {
                                    prepareAndOpenComparisonSheet()
                                } label: {
                                    Label("对比原图", systemImage: "rectangle.split.2x1")
                                }
                            }
                            Section("更多导出格式") {
                                ForEach(ExportFormat.allCases) { format in
                                    Button {
                                        selectedExportFormat = format
                                        handleExportRequest()
                                    } label: {
                                        Label(format.rawValue, systemImage: format == .pdf ? "doc.richtext" : "photo")
                                    }
                                }
                            }
                        } label: {
                            if isExporting {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(6)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingComparisonSheet) {
                BeforeAfterComparisonView(
                    beforeImage: comparisonBeforeImage,
                    afterImage: comparisonAfterImage,
                    session: session
                )
            }
            .sheet(isPresented: $isShowingExportSheet, onDismiss: {
                if let url = exportedFileURL {
                    try? FileManager.default.removeItem(at: url)
                    exportedFileURL = nil
                }
            }) {
                if let url = exportedFileURL {
                    ShareSheetView(activityItems: [url])
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                ProSubscriptionView()
            }
            .sheet(isPresented: $isShowingTextExtractorSheet) {
                TextExtractorSheet(text: extractedFullText)
            }
            .alert("添加文字说明", isPresented: $isShowingTextAlert) {
                TextField("输入批注文字", text: $textInputPrompt)
                Button("确定") {
                    addTextAnnotation()
                }
                Button("取消", role: .cancel) {}
            }
            .alert("已保存到相册", isPresented: $isShowingSlicesSavedAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text("已将长图拆解为 \(generatedSlices.count) 张切片，可前往微信或小红书发布。")
            }
            .background {
                Button("") {
                    handleUndoAction()
                }
                .keyboardShortcut("z", modifiers: .command)
                .opacity(0)
            }
            .onDisappear {
                if let url = exportedFileURL {
                    try? FileManager.default.removeItem(at: url)
                    exportedFileURL = nil
                }
                AppCacheManager.shared.cleanupSession(sessionId: session.id)
            }
        }
    }
    
    // MARK: - Canvas View
    
    private var canvasScrollView: some View {
        GeometryReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                VStack(spacing: 0) {
                    annotatedCanvasStack
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 16)
                .frame(minWidth: proxy.size.width)
                #if canImport(UIKit)
                .background(
                    ScrollViewAccessor { scrollView in
                        scrollController.attach(to: scrollView)
                    }
                )
                #endif
            }
            .scrollIndicators(.hidden)
        }
    }
    
    private var verticalLayouts: [SliceCanvasLayout] {
        let displayWidth: CGFloat = (session.slices.first?.originalWidth ?? 393) / 3.0
        return TiledImageRenderer.computeVerticalLayout(session: session, canvasWidth: displayWidth)
    }
    
    private var sliceYOffsets: [CGFloat] {
        return verticalLayouts.map { $0.canvasY }
    }
    
    private var annotatedCanvasStack: some View {
        let isHorizontal = (session.presetMode == .horizontalCompare)
        let targetDisplayHeight: CGFloat = isHorizontal ? 360.0 : (session.totalEstimatedHeight / 3.0)
        let displayWidth: CGFloat = (session.slices.first?.originalWidth ?? 393) / 3.0
        let totalDisplayWidth: CGFloat = isHorizontal ? (session.totalEstimatedWidth / 3.0) : displayWidth
        let layouts = verticalLayouts
        
        return ZStack(alignment: .topLeading) {
            if isHorizontal {
                // Horizontal Compare: Side by Side
                HStack(spacing: 3) {
                    ForEach(Array(session.slices.enumerated()), id: \.element.id) { index, slice in
                        renderHorizontalSliceView(index: index, slice: slice, targetHeight: targetDisplayHeight)
                    }
                }
            } else {
                // Underneath: Raw Stitched Slices placed at mathematically exact seam positions
                ForEach(Array(session.slices.enumerated()), id: \.element.id) { index, slice in
                    if index < layouts.count {
                        let layout = layouts[index]
                        renderSliceView(index: index, slice: slice, layout: layout, displayWidth: displayWidth)
                            .offset(y: layout.canvasY)
                    }
                }
            }
            
            // Middle: Rendered Annotations
            ForEach(annotations) { item in
                renderAnnotationOverlay(item: item, canvasWidth: totalDisplayWidth, canvasHeight: targetDisplayHeight)
                    .overlay {
                        if selectedAnnotationId == item.id {
                            selectionOverlay(for: item, canvasWidth: totalDisplayWidth, canvasHeight: targetDisplayHeight)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if canvasInteractionMode == .browse {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                if selectedAnnotationId == item.id {
                                    selectedAnnotationId = nil
                                } else {
                                    selectedAnnotationId = item.id
                                }
                            }
                            HapticFeedbackManager.shared.triggerSelection()
                        }
                    }
            }
            
            // Rendered Privacy Frost & Mosaic Strokes
            ForEach(brushStrokes) { stroke in
                renderBrushStroke(stroke: stroke)
            }
            
            // Current In-progress Drawing Shape
            if let drawing = currentDrawingItem {
                renderAnnotationOverlay(item: drawing, canvasWidth: totalDisplayWidth, canvasHeight: targetDisplayHeight)
            }
            
            // Current In-progress Brush Stroke
            if let brush = currentBrushStroke {
                renderBrushStroke(stroke: brush)
            }
            
            // Top: Interaction Layer for Gesture Input (only active in Draw mode)
            if (activeToolMode == .annotation || activeToolMode == .privacyBrush) && canvasInteractionMode == .draw {
                Color.white.opacity(0.001)
                    .frame(width: totalDisplayWidth, height: targetDisplayHeight)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if activeToolMode == .annotation {
                                    handleAnnotationDragChanged(value: value, canvasSize: CGSize(width: totalDisplayWidth, height: targetDisplayHeight))
                                } else if activeToolMode == .privacyBrush {
                                    handlePrivacyDragChanged(value: value, canvasSize: CGSize(width: totalDisplayWidth, height: targetDisplayHeight))
                                }
                            }
                            .onEnded { value in
                                if activeToolMode == .annotation {
                                    handleAnnotationDragEnded(value: value, canvasSize: CGSize(width: totalDisplayWidth, height: targetDisplayHeight))
                                } else if activeToolMode == .privacyBrush {
                                    handlePrivacyDragEnded(value: value, canvasSize: CGSize(width: totalDisplayWidth, height: targetDisplayHeight))
                                }
                            }
                    )
            }
        }
        .frame(width: totalDisplayWidth, height: targetDisplayHeight, alignment: .topLeading)
        .scaleEffect(canvasZoomScale, anchor: .top)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: canvasZoomScale)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 6)
        .onTapGesture(count: 2) {
            if activeToolMode == nil || canvasInteractionMode == .browse {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    canvasZoomScale = (canvasZoomScale > 1.2) ? 1.0 : 2.0
                }
                HapticFeedbackManager.shared.triggerSelection()
            }
        }
    }
    
    private func renderHorizontalSliceView(index: Int, slice: StitchItem, targetHeight: CGFloat) -> some View {
        let scaledWidth = (slice.originalWidth / max(1, slice.originalHeight)) * targetHeight
        return Group {
            if let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
               let image = UIImage(contentsOfFile: fileURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: scaledWidth, height: targetHeight)
                    .clipped()
            } else {
                Color.gray.opacity(0.2)
                    .frame(width: scaledWidth, height: targetHeight)
            }
        }
    }
    
    private func renderSliceView(index: Int, slice: StitchItem, layout: SliceCanvasLayout, displayWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            if let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
               let image = UIImage(contentsOfFile: fileURL.path) {
                
                let displayOriginalHeight = slice.originalHeight * layout.scale
                let displaySourceY = layout.sourceYStart * layout.scale
                let displayVisibleHeight = layout.canvasHeight
                
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: displayWidth, height: displayOriginalHeight)
                        .offset(y: -displaySourceY)
                        .frame(width: displayWidth, height: displayVisibleHeight, alignment: .top)
                        .clipped()
                    
                    // Seam indicator line when tuner mode is active
                    if activeToolMode == .seamTuner && index > 0 {
                        Rectangle()
                            .fill(selectedSliceIndex == index ? Color.accentColor : Color.secondary.opacity(0.4))
                            .frame(height: selectedSliceIndex == index ? 2 : 1)
                            .overlay(
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.and.down")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("第 \(index) 处接缝")
                                        .font(.caption2.bold())
                                    if abs(slice.manualOffsetAdjustment) > 0.5 {
                                        Text("\(slice.manualOffsetAdjustment > 0 ? "+" : "")\(Int(slice.manualOffsetAdjustment))px")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(Color.white.opacity(0.9))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedSliceIndex == index ? Color.accentColor : Color(white: 0.2))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
                                .scaleEffect(selectedSliceIndex == index ? 1.05 : 0.95)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedSliceIndex)
                                .offset(y: -14)
                                .gesture(
                                    DragGesture(minimumDistance: 3)
                                        .onChanged { gesture in
                                            if selectedSliceIndex != index {
                                                selectedSliceIndex = index
                                                seamDragStartOffset = session.slices[index].manualOffsetAdjustment
                                            }
                                            // Canvas is previewed at 1/3 scale, 1pt screen drag = 3px native coordinate
                                            let newOffset = seamDragStartOffset + gesture.translation.height * 3.0
                                            let range = currentSliceSeamRange
                                            if abs(newOffset) < 3.5 {
                                                if session.slices[index].manualOffsetAdjustment != 0 {
                                                    HapticFeedbackManager.shared.triggerDialDetent()
                                                }
                                                session.slices[index].manualOffsetAdjustment = 0
                                            } else {
                                                session.slices[index].manualOffsetAdjustment = max(range.lowerBound, min(range.upperBound, newOffset))
                                            }
                                        }
                                        .onEnded { _ in
                                            seamDragStartOffset = session.slices[index].manualOffsetAdjustment
                                            HapticFeedbackManager.shared.triggerSnap()
                                        }
                                )
                                .onTapGesture {
                                    selectedSliceIndex = index
                                    seamDragStartOffset = session.slices[index].manualOffsetAdjustment
                                    HapticFeedbackManager.shared.triggerSelection()
                                }
                            )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if activeToolMode == .seamTuner && index > 0 {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) {
                            selectedSliceIndex = index
                            seamDragStartOffset = session.slices[index].manualOffsetAdjustment
                        }
                        HapticFeedbackManager.shared.triggerSelection()
                    }
                }
            }
        }
    }
    
    // MARK: - Annotation Drawing
    
    @ViewBuilder
    private func renderAnnotationOverlay(item: AnnotationItem, canvasWidth: CGFloat, canvasHeight: CGFloat) -> some View {
        let start = CGPoint(x: item.startPoint.x * canvasWidth, y: item.startPoint.y * canvasHeight)
        let end = CGPoint(x: item.endPoint.x * canvasWidth, y: item.endPoint.y * canvasHeight)
        let color = item.color.swiftUIColor
        
        switch item.kind {
        case .rectangle:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: max(4, abs(end.x - start.x)),
                height: max(4, abs(end.y - start.y))
            )
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(color, lineWidth: item.lineWidth)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
            
        case .arrow:
            let angle = atan2(end.y - start.y, end.x - start.x)
            let length = hypot(end.x - start.x, end.y - start.y)
            let headLength: CGFloat = min(22.0, max(12.0, item.lineWidth * 3.8))
            let headAngle: CGFloat = .pi / 6.0
            let p1 = CGPoint(
                x: end.x - headLength * cos(angle - headAngle),
                y: end.y - headLength * sin(angle - headAngle)
            )
            let p2 = CGPoint(
                x: end.x - headLength * cos(angle + headAngle),
                y: end.y - headLength * sin(angle + headAngle)
            )
            
            ZStack {
                Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .stroke(color, style: StrokeStyle(lineWidth: item.lineWidth, lineCap: .round, lineJoin: .round))
                
                if length > 6 {
                    Path { path in
                        path.move(to: end)
                        path.addLine(to: p1)
                        path.addLine(to: p2)
                        path.closeSubpath()
                    }
                    .fill(color)
                }
            }
            
        case .stepBadge:
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 26, height: 26)
                Text("\(item.stepNumber)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .position(start)
            
        case .highlighter:
            Path { path in
                if let first = item.freehandPoints.first {
                    path.move(to: CGPoint(x: first.x * canvasWidth, y: first.y * canvasHeight))
                    for pt in item.freehandPoints.dropFirst() {
                        path.addLine(to: CGPoint(x: pt.x * canvasWidth, y: pt.y * canvasHeight))
                    }
                }
            }
            .stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: item.lineWidth * 3.5, lineCap: .round, lineJoin: .round))
            
        case .textNote:
            if !item.textContent.isEmpty {
                Text(item.textContent)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .position(start)
            }
            
        case .mosaic:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: max(4, abs(end.x - start.x)),
                height: max(4, abs(end.y - start.y))
            )
            ZStack {
                switch item.redactionStyle {
                case .pixelatedMosaic:
                    Canvas { context, size in
                        let tileSize: CGFloat = 8.0
                        let cols = Int(ceil(size.width / tileSize))
                        let rows = Int(ceil(size.height / tileSize))
                        for r in 0..<rows {
                            for c in 0..<cols {
                                let tileRect = CGRect(x: CGFloat(c) * tileSize, y: CGFloat(r) * tileSize, width: tileSize, height: tileSize)
                                let isEven = (r + c) % 2 == 0
                                let gray = isEven ? 0.82 : 0.65
                                context.fill(Path(tileRect), with: .color(Color(white: gray).opacity(0.95)))
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                    )
                case .frostedBlur:
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(Color.white.opacity(0.55))
                        .blur(radius: 1)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                        )
                case .blackout:
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(white: 0.08))
                }
            }
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
        }
    }
    
    private func computeBoundingRect(for item: AnnotationItem, canvasWidth: CGFloat, canvasHeight: CGFloat) -> CGRect {
        let start = CGPoint(x: item.startPoint.x * canvasWidth, y: item.startPoint.y * canvasHeight)
        let end = CGPoint(x: item.endPoint.x * canvasWidth, y: item.endPoint.y * canvasHeight)
        
        switch item.kind {
        case .rectangle, .mosaic:
            return CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: max(8, abs(end.x - start.x)),
                height: max(8, abs(end.y - start.y))
            )
        case .arrow:
            return CGRect(
                x: min(start.x, end.x) - 4,
                y: min(start.y, end.y) - 4,
                width: max(16, abs(end.x - start.x)) + 8,
                height: max(16, abs(end.y - start.y)) + 8
            )
        case .stepBadge:
            return CGRect(x: start.x - 14, y: start.y - 14, width: 28, height: 28)
        case .textNote:
            return CGRect(x: start.x - 30, y: start.y - 14, width: 60, height: 28)
        case .highlighter:
            let xs = item.freehandPoints.map { $0.x * canvasWidth }
            let ys = item.freehandPoints.map { $0.y * canvasHeight }
            let minX = xs.min() ?? start.x
            let maxX = xs.max() ?? end.x
            let minY = ys.min() ?? start.y
            let maxY = ys.max() ?? end.y
            return CGRect(x: minX - 4, y: minY - 4, width: max(8, maxX - minX + 8), height: max(8, maxY - minY + 8))
        }
    }
    
    @ViewBuilder
    private func selectionOverlay(for item: AnnotationItem, canvasWidth: CGFloat, canvasHeight: CGFloat) -> some View {
        let rect = computeBoundingRect(for: item, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: rect.width + 6, height: rect.height + 6)
                .position(x: rect.midX, y: rect.midY)
            
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    annotations.removeAll { $0.id == item.id }
                    selectedAnnotationId = nil
                }
                HapticFeedbackManager.shared.triggerSelection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white, Color.red)
                    .background(Circle().fill(Color.white).padding(2))
                    .shadow(color: .black.opacity(0.25), radius: 3)
            }
            .buttonStyle(.plain)
            .position(x: rect.maxX + 4, y: rect.minY - 4)
        }
    }
    
    private func handleAnnotationDragChanged(value: DragGesture.Value, canvasSize: CGSize) {
        let normStart = CGPoint(x: value.startLocation.x / canvasSize.width, y: value.startLocation.y / canvasSize.height)
        let normCurrent = CGPoint(x: value.location.x / canvasSize.width, y: value.location.y / canvasSize.height)
        
        switch activeAnnotationKind {
        case .rectangle, .arrow:
            currentDrawingItem = AnnotationItem(
                kind: activeAnnotationKind,
                color: activeAnnotationColor,
                lineWidth: annotationLineWidth,
                startPoint: normStart,
                endPoint: normCurrent
            )
        case .highlighter:
            if currentDrawingItem == nil {
                currentDrawingItem = AnnotationItem(
                    kind: .highlighter,
                    color: activeAnnotationColor,
                    lineWidth: annotationLineWidth,
                    freehandPoints: [normStart]
                )
            } else {
                currentDrawingItem?.freehandPoints.append(normCurrent)
            }
        case .stepBadge, .textNote, .mosaic:
            break
        }
    }
    
    private func handleAnnotationDragEnded(value: DragGesture.Value, canvasSize: CGSize) {
        let normLocation = CGPoint(x: value.location.x / canvasSize.width, y: value.location.y / canvasSize.height)
        
        if activeAnnotationKind == .stepBadge {
            let badge = AnnotationItem(
                kind: .stepBadge,
                color: activeAnnotationColor,
                startPoint: normLocation,
                stepNumber: nextStepBadgeNumber
            )
            annotations.append(badge)
            nextStepBadgeNumber += 1
            HapticFeedbackManager.shared.triggerSnap()
            return
        }
        
        if activeAnnotationKind == .textNote {
            pendingTextLocation = normLocation
            textInputPrompt = ""
            isShowingTextAlert = true
            return
        }
        
        if let drawing = currentDrawingItem {
            annotations.append(drawing)
            currentDrawingItem = nil
            HapticFeedbackManager.shared.triggerSnap()
        }
    }
    
    private func addTextAnnotation() {
        guard !textInputPrompt.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let textItem = AnnotationItem(
            kind: .textNote,
            color: activeAnnotationColor,
            startPoint: pendingTextLocation,
            textContent: textInputPrompt
        )
        annotations.append(textItem)
        HapticFeedbackManager.shared.triggerSnap()
    }
    
    private func handlePrivacyDragChanged(value: DragGesture.Value, canvasSize: CGSize) {
        if redactionShapeMode == .brush {
            let loc = value.location
            if currentBrushStroke == nil {
                currentBrushStroke = RedactionStroke(
                    points: [loc],
                    brushType: redactionStyleChoice.brushType,
                    lineWidth: brushStrokeWidth
                )
            } else {
                currentBrushStroke?.points.append(loc)
            }
            HapticFeedbackManager.shared.triggerDialDetent()
        } else {
            let normStart = CGPoint(x: value.startLocation.x / canvasSize.width, y: value.startLocation.y / canvasSize.height)
            let normCurrent = CGPoint(x: value.location.x / canvasSize.width, y: value.location.y / canvasSize.height)
            currentDrawingItem = AnnotationItem(
                kind: .mosaic,
                color: .midnightBlack,
                lineWidth: 2.0,
                startPoint: normStart,
                endPoint: normCurrent,
                isBlackout: (redactionStyleChoice == .blackout),
                redactionStyle: redactionStyleChoice.regionStyle
            )
        }
    }
    
    private func handlePrivacyDragEnded(value: DragGesture.Value, canvasSize: CGSize) {
        if redactionShapeMode == .brush {
            if let stroke = currentBrushStroke {
                brushStrokes.append(stroke)
                currentBrushStroke = nil
                HapticFeedbackManager.shared.triggerSnap()
            }
        } else {
            if let drawing = currentDrawingItem {
                annotations.append(drawing)
                currentDrawingItem = nil
                HapticFeedbackManager.shared.triggerSnap()
            }
        }
    }
    
    @ViewBuilder
    private func renderBrushStroke(stroke: RedactionStroke) -> some View {
        let path = Path { p in
            guard let first = stroke.points.first else { return }
            p.move(to: first)
            for pt in stroke.points.dropFirst() {
                p.addLine(to: pt)
            }
        }
        
        switch stroke.brushType {
        case .frostedGlass:
            path.stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round))
                .blur(radius: 4)
        case .pixelateMosaic:
            ZStack {
                path.stroke(Color(white: 0.72), style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .square, lineJoin: .round))
                path.stroke(Color(white: 0.45), style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .square, lineJoin: .round, dash: [stroke.lineWidth * 0.6, stroke.lineWidth * 0.6]))
            }
        case .confidentialInk:
            path.stroke(Color(white: 0.1), style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
    
    // MARK: - Dynamic Seam Range
    
    private var currentSliceSeamRange: ClosedRange<CGFloat> {
        guard selectedSliceIndex > 0 && selectedSliceIndex < session.slices.count else {
            return -600...1200
        }
        let slice = session.slices[selectedSliceIndex]
        let baseOverlap = slice.calculatedOverlapWithPrevious
        let h = slice.originalHeight
        let minAdj = -max(baseOverlap + 120.0, 600.0)
        let maxAdj = max(800.0, h * 0.85 - baseOverlap)
        return minAdj...maxAdj
    }
    
    // MARK: - Liquid Glass Bottom Control Bar
    
    private var bottomLiquidControlBar: some View {
        VStack(spacing: 8) {
            // Secondary expanded tool options panel (only shown if a tool is active)
            if let mode = activeToolMode {
                switch mode {
                case .seamTuner:
                    let safeIndex = max(1, min(selectedSliceIndex, max(1, session.slices.count - 1)))
                    TactileSeamDialView(
                        offset: Binding<CGFloat>(
                            get: {
                                guard safeIndex > 0 && safeIndex < session.slices.count else { return 0 }
                                return session.slices[safeIndex].manualOffsetAdjustment
                            },
                            set: { newOffset in
                                guard safeIndex > 0 && safeIndex < session.slices.count else { return }
                                session.slices[safeIndex].manualOffsetAdjustment = newOffset
                            }
                        ),
                        optimalOffset: 0.0,
                        range: currentSliceSeamRange,
                        sliceIndex: safeIndex,
                        totalSlices: session.slices.count,
                        onSelectSlice: { idx in
                            selectedSliceIndex = idx
                        },
                        onSnapToOptimal: {
                            if safeIndex > 0 && safeIndex < session.slices.count {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    session.slices[safeIndex].manualOffsetAdjustment = 0
                                }
                            }
                        },
                        onScrubbingChanged: nil
                    )
                case .privacyBrush:
                    LiquidBrushRedactionView(
                        shapeMode: $redactionShapeMode,
                        styleChoice: $redactionStyleChoice,
                        brushWidth: $brushStrokeWidth,
                        interactionMode: $canvasInteractionMode,
                        strokes: $brushStrokes,
                        annotations: $annotations,
                        onAutoSanitize: {
                            runVisionAutoSanitization()
                        },
                        isSanitizing: privacySanitizer.isDetecting
                    )
                case .annotation:
                    annotationToolsPanel
                case .socialSlicer:
                    socialSlicerPanel
                }
            }
            
            // Primary 4-Tab Liquid Glass Bar
            HStack(spacing: 8) {
                ForEach(EditorToolMode.allCases) { mode in
                    Button {
                        HapticFeedbackManager.shared.triggerSelection()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            if activeToolMode == mode {
                                activeToolMode = nil
                                selectedAnnotationId = nil
                            } else {
                                activeToolMode = mode
                                canvasInteractionMode = .draw
                                selectedAnnotationId = nil
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 16, weight: activeToolMode == mode ? .bold : .medium))
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: activeToolMode == mode ? .bold : .regular))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundStyle(activeToolMode == mode ? Color.accentColor : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            activeToolMode == mode
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScrollSnapButtonStyle.bouncy)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .liquidGlassCard(cornerRadius: 24, strokeOpacity: 0.32)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // Sub-panel: Annotation Tools (Clean & Focused on Markup)
    private var annotationToolsPanel: some View {
        VStack(spacing: 10) {
            // Row 1: Mode Switcher (Draw vs Browse) & Smart Actions
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Button {
                        canvasInteractionMode = .draw
                        HapticFeedbackManager.shared.triggerSelection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.tip.crop.circle")
                            Text("绘制")
                        }
                        .font(.system(size: 11, weight: canvasInteractionMode == .draw ? .bold : .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(canvasInteractionMode == .draw ? Color.accentColor : Color.clear)
                        .foregroundStyle(canvasInteractionMode == .draw ? Color.white : Color.secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        canvasInteractionMode = .browse
                        HapticFeedbackManager.shared.triggerSelection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.draw")
                            Text("浏览/选择")
                        }
                        .font(.system(size: 11, weight: canvasInteractionMode == .browse ? .bold : .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(canvasInteractionMode == .browse ? Color.accentColor : Color.clear)
                        .foregroundStyle(canvasInteractionMode == .browse ? Color.white : Color.secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(3)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
                
                Spacer()
                
                // OCR Text Extraction
                Button {
                    runFullTextOCR()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.viewfinder")
                        Text("提取文字")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.indigo.opacity(0.18))
                    .foregroundStyle(Color.indigo)
                    .clipShape(Capsule())
                }
                
                // Undo
                Button {
                    handleAnnotationUndo()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(nonMosaicAnnotationsCount == 0 ? Color.secondary.opacity(0.3) : Color.primary)
                }
                .disabled(nonMosaicAnnotationsCount == 0)
                .buttonStyle(ScrollSnapButtonStyle.bouncy)
                
                // Clear all annotations
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        annotations.removeAll { $0.kind != .mosaic }
                        selectedAnnotationId = nil
                    }
                    HapticFeedbackManager.shared.triggerWarning()
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(nonMosaicAnnotationsCount == 0 ? Color.secondary.opacity(0.3) : Color.red.opacity(0.85))
                }
                .disabled(nonMosaicAnnotationsCount == 0)
                .buttonStyle(ScrollSnapButtonStyle.bouncy)
            }
            .padding(.horizontal, 4)
            
            Divider().opacity(0.3)
            
            // Row 2: 5 Tools (Brush/Highlighter, Rectangle, Arrow, Text, Step Badge)
            HStack(spacing: 5) {
                annotationToolButton(kind: .highlighter, title: "画笔", icon: "pencil.tip")
                annotationToolButton(kind: .rectangle, title: "方框", icon: "rectangle")
                annotationToolButton(kind: .arrow, title: "箭头", icon: "arrow.up.right")
                annotationToolButton(kind: .textNote, title: "文字", icon: "textformat")
                annotationToolButton(kind: .stepBadge, title: "序号", icon: "1.circle.fill")
            }
            .padding(.horizontal, 4)
            
            Divider().opacity(0.3)
            
            // Row 3: Stroke Width & Color Selector
            HStack(spacing: 10) {
                Text("粗细")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                ForEach([(2.0, "细"), (4.0, "中"), (7.0, "粗")], id: \.0) { width, title in
                    Button {
                        annotationLineWidth = width
                        HapticFeedbackManager.shared.triggerSelection()
                    } label: {
                        Text(title)
                            .font(.system(size: 11, weight: annotationLineWidth == width ? .bold : .regular))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(annotationLineWidth == width ? Color.primary.opacity(0.15) : Color.clear)
                            .foregroundStyle(annotationLineWidth == width ? Color.accentColor : Color.secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                HStack(spacing: 7) {
                    ForEach([AnnotationColor.crimsonRed, .electricOrange, .neonYellow, .mintGreen, .deepIndigo, .midnightBlack, .pureWhite], id: \.self) { color in
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: 17, height: 17)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.2), lineWidth: color == .pureWhite ? 1 : 0)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.accentColor, lineWidth: activeAnnotationColor == color ? 2.5 : 0)
                                    .scaleEffect(1.3)
                            )
                            .onTapGesture {
                                activeAnnotationColor = color
                                HapticFeedbackManager.shared.triggerSelection()
                            }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .liquidGlassCard(cornerRadius: 18)
    }
    
    private var nonMosaicAnnotationsCount: Int {
        annotations.filter { $0.kind != .mosaic }.count
    }
    
    private func handleAnnotationUndo() {
        if let lastIdx = annotations.lastIndex(where: { $0.kind != .mosaic }) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                _ = annotations.remove(at: lastIdx)
                selectedAnnotationId = nil
            }
            HapticFeedbackManager.shared.triggerSelection()
        }
    }
    
    private func annotationToolButton(kind: AnnotationKind, title: String, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                activeAnnotationKind = kind
                canvasInteractionMode = .draw
            }
            HapticFeedbackManager.shared.triggerSelection()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: activeAnnotationKind == kind ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(activeAnnotationKind == kind ? Color.accentColor : Color.primary.opacity(0.08))
            .foregroundStyle(activeAnnotationKind == kind ? Color.white : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // Sub-panel: Social Slicer (Interactive 3x3 Stage)
    private var socialSlicerPanel: some View {
        VStack(spacing: 8) {
            if !generatedSlices.isEmpty {
                SocialGridStageView(
                    slices: generatedSlices,
                    onSaveToAlbum: {
                        saveGeneratedSlicesToAlbum()
                    },
                    onReset: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            generatedSlices.removeAll()
                        }
                    },
                    isSaving: isSlicing
                )
            } else {
                HStack(spacing: 12) {
                    ForEach(ImageSlicer.SlicePreset.allCases) { preset in
                        Button {
                            selectedSlicePreset = preset
                            HapticFeedbackManager.shared.triggerSelection()
                        } label: {
                            Text(preset.title)
                                .font(.system(size: 11, weight: selectedSlicePreset == preset ? .bold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedSlicePreset == preset ? Color.accentColor : Color.secondary.opacity(0.15))
                                .foregroundStyle(selectedSlicePreset == preset ? Color.white : Color.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Button {
                    triggerSlicePreview()
                } label: {
                    HStack(spacing: 6) {
                        if isSlicing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "square.grid.3x3.fill")
                        }
                        Text("切为 \(selectedSlicePreset.rawValue) 张图")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
                .disabled(isSlicing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .liquidGlassCard(cornerRadius: 20)
    }
    
    // Toast View
    private var clipboardToastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(toastMessage)
                .font(.footnote.bold())
            
            #if canImport(UIKit)
            if toastMessage.contains("微信"), let wechatURL = URL(string: "weixin://"), UIApplication.shared.canOpenURL(wechatURL) {
                Button {
                    UIApplication.shared.open(wechatURL)
                } label: {
                    HStack(spacing: 3) {
                        Text("打开微信")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.green.opacity(0.18))
                    .foregroundStyle(Color.green)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            #endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .liquidGlassPill()
        .transition(.move(edge: .bottom).combined(with: .scale(scale: 0.9)).combined(with: .opacity))
        .padding(.bottom, 120)
    }
    
    // MARK: - Action Handlers
    
    private var presetModeMenu: some View {
        Menu {
            ForEach(StitchPresetMode.allCases) { mode in
                Button {
                    changePresetMode(mode)
                } label: {
                    if session.presetMode == mode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(session.presetMode.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Image(systemName: "chevron.down.circle.fill")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .liquidGlassPill()
        }
    }
    
    private func changePresetMode(_ newMode: StitchPresetMode) {
        guard session.presetMode != newMode else { return }
        session.presetMode = newMode
        
        switch newMode {
        case .movieSubtitles:
            for i in 0..<session.slices.count {
                if i == 0 {
                    session.slices[i].topCropInset = 0
                    session.slices[i].bottomCropInset = 0
                    session.slices[i].calculatedOverlapWithPrevious = 0
                } else {
                    session.slices[i].topCropInset = session.slices[i].originalHeight * 0.82
                    session.slices[i].bottomCropInset = 0
                    session.slices[i].calculatedOverlapWithPrevious = 0
                    session.slices[i].manualOffsetAdjustment = 0
                }
            }
        case .webArticle:
            for i in 0..<session.slices.count {
                session.slices[i].topCropInset = (i > 0) ? newMode.defaultTopCropInset : 0
                session.slices[i].bottomCropInset = (i < session.slices.count - 1) ? newMode.defaultBottomCropInset : 0
            }
        case .continuousFeed, .horizontalCompare:
            for i in 0..<session.slices.count {
                session.slices[i].topCropInset = 0
                session.slices[i].bottomCropInset = 0
            }
        case .chatRecord, .smartAuto:
            for i in 0..<session.slices.count {
                if i == 0 {
                    session.slices[i].topCropInset = 0
                    session.slices[i].bottomCropInset = session.slices.count > 1 ? newMode.defaultBottomCropInset : 0
                } else if i == session.slices.count - 1 {
                    session.slices[i].topCropInset = newMode.defaultTopCropInset
                    session.slices[i].bottomCropInset = 0
                } else {
                    session.slices[i].topCropInset = newMode.defaultTopCropInset
                    session.slices[i].bottomCropInset = newMode.defaultBottomCropInset
                }
            }
        }
        HapticFeedbackManager.shared.triggerSnap()
    }
    
    private func adjustSliceOverlap(sliceIndex: Int, delta: CGFloat) {
        guard sliceIndex > 0 && sliceIndex < session.slices.count else { return }
        session.slices[sliceIndex].manualOverlapAdjustment += delta
        
        // Tactile Magnetic Haptics on 44pt / 88pt sweet spot
        let newOverlap = session.slices[sliceIndex].effectiveOverlap
        if abs(newOverlap - 44) < 2 || abs(newOverlap - 88) < 2 {
            HapticFeedbackManager.shared.triggerSnap()
        } else {
            HapticFeedbackManager.shared.triggerSelection()
        }
    }
    
    // Split Curtain Comparison Preparation
    private func prepareAndOpenComparisonSheet() {
        HapticFeedbackManager.shared.triggerSelection()
        Task {
            let tempAfter = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            try? TiledImageRenderer.renderStitchedImageToFile(
                session: session,
                annotations: annotations,
                brushStrokes: brushStrokes,
                outputURL: tempAfter,
                format: .jpeg,
                quality: 0.90
            )
            let afterImg = UIImage(contentsOfFile: tempAfter.path)
            try? FileManager.default.removeItem(at: tempAfter)
            
            // Generate real un-cropped stacked "Before" image to visually demonstrate duplicate nav bar removal
            var beforeImg: UIImage?
            #if canImport(UIKit)
            let canvasWidth = session.slices.first?.originalWidth ?? 393
            var rawTotalHeight: CGFloat = 0
            for slice in session.slices {
                rawTotalHeight += slice.originalHeight
            }
            let rawMaxHeight = min(rawTotalHeight, 20480.0)
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: rawMaxHeight))
            let rawStackedData = renderer.jpegData(withCompressionQuality: 0.85) { ctx in
                var yOffset: CGFloat = 0
                for slice in session.slices {
                    guard let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
                          let img = UIImage(contentsOfFile: fileURL.path) else { continue }
                    img.draw(in: CGRect(x: 0, y: yOffset, width: canvasWidth, height: slice.originalHeight))
                    yOffset += slice.originalHeight
                    if yOffset >= rawMaxHeight { break }
                }
            }
            beforeImg = UIImage(data: rawStackedData)
            #endif
            
            await MainActor.run {
                self.comparisonBeforeImage = beforeImg
                self.comparisonAfterImage = afterImg
                self.isShowingComparisonSheet = true
            }
        }
    }
    
    // AI Vision Auto Sanitization
    private func runVisionAutoSanitization() {
        Task {
            let tempOutput = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            defer { try? FileManager.default.removeItem(at: tempOutput) }
            try? TiledImageRenderer.renderStitchedImageToFile(
                session: session,
                outputURL: tempOutput,
                format: .jpeg
            )
            
            if let image = UIImage(contentsOfFile: tempOutput.path) {
                let autoMosaics = await privacySanitizer.detectSensitiveRegions(in: image)
                await MainActor.run {
                    if autoMosaics.isEmpty {
                        self.toastMessage = "未检测到头像或号码等信息"
                    } else {
                        self.annotations.append(contentsOf: autoMosaics)
                        self.toastMessage = "已遮挡 \(autoMosaics.count) 处敏感信息"
                    }
                    HapticFeedbackManager.shared.triggerSnap()
                    showToast()
                }
            }
        }
    }
    
    // Full-Text OCR Extraction
    private func runFullTextOCR() {
        Task {
            let tempOutput = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            defer { try? FileManager.default.removeItem(at: tempOutput) }
            try? TiledImageRenderer.renderStitchedImageToFile(
                session: session,
                outputURL: tempOutput,
                format: .jpeg
            )
            
            if let image = UIImage(contentsOfFile: tempOutput.path) {
                let result = await textExtractor.extractFullText(from: image)
                await MainActor.run {
                    self.extractedFullText = result.plainText
                    UIPasteboard.general.string = result.plainText
                    self.isShowingTextExtractorSheet = true
                    HapticFeedbackManager.shared.triggerSnap()
                }
            }
        }
    }
    
    private func triggerSlicePreview() {
        guard !session.slices.isEmpty else { return }
        isSlicing = true
        
        Task {
            let tempOutput = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            defer { try? FileManager.default.removeItem(at: tempOutput) }
            try? TiledImageRenderer.renderStitchedImageToFile(
                session: session,
                annotations: annotations,
                brushStrokes: brushStrokes,
                outputURL: tempOutput,
                format: .jpeg
            )
            
            if let image = UIImage(contentsOfFile: tempOutput.path) {
                let slices = ImageSlicer.shared.sliceImage(image: image, count: selectedSlicePreset.rawValue)
                await MainActor.run {
                    self.generatedSlices = slices
                    self.isSlicing = false
                    HapticFeedbackManager.shared.triggerSnap()
                }
            } else {
                await MainActor.run { self.isSlicing = false }
            }
        }
    }
    
    private func saveGeneratedSlicesToAlbum() {
        guard !generatedSlices.isEmpty else { return }
        isSlicing = true
        Task {
            try? await ImageSlicer.shared.saveSlicesToAlbum(slices: generatedSlices)
            await MainActor.run {
                self.isSlicing = false
                self.isShowingSlicesSavedAlert = true
                HapticFeedbackManager.shared.triggerSnap()
                SoundEffectManager.shared.playShutter()
                StoreReviewManager.shared.recordSuccessfulExport()
            }
        }
    }
    
    private func copyDirectlyToClipboard(isWeChatSharing: Bool = false) {
        guard quotaManager.canStitch() else {
            isShowingPaywall = true
            return
        }
        
        Task {
            let tempOutput = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            defer { try? FileManager.default.removeItem(at: tempOutput) }
            try? TiledImageRenderer.renderStitchedImageToFile(
                session: session,
                annotations: annotations,
                brushStrokes: brushStrokes,
                outputURL: tempOutput,
                format: .jpeg
            )
            
            if let image = UIImage(contentsOfFile: tempOutput.path) {
                let finalImage = ExportWatermarkManager.shared.appendWatermarkIfNeeded(to: image, isProUser: storeKit.isProUser)
                UIPasteboard.general.image = finalImage
                quotaManager.recordStitchUsage()
                
                await MainActor.run {
                    HapticFeedbackManager.shared.triggerSnap()
                    SoundEffectManager.shared.playMagneticSnap()
                    StoreReviewManager.shared.recordSuccessfulExport()
                    self.toastMessage = isWeChatSharing
                        ? "长截图已复制，去微信长按粘贴即可发送"
                        : "已复制长截图到剪贴板，可直接粘贴"
                    showToast()
                }
            }
        }
    }
    
    private func handleUndoAction() {
        if activeToolMode == .privacyBrush {
            if redactionShapeMode == .brush && !brushStrokes.isEmpty {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    _ = brushStrokes.removeLast()
                }
                HapticFeedbackManager.shared.triggerSelection()
            } else if let lastMosaicIdx = annotations.lastIndex(where: { $0.kind == .mosaic }) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    _ = annotations.remove(at: lastMosaicIdx)
                    selectedAnnotationId = nil
                }
                HapticFeedbackManager.shared.triggerSelection()
            } else if !brushStrokes.isEmpty {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    _ = brushStrokes.removeLast()
                }
                HapticFeedbackManager.shared.triggerSelection()
            }
        } else if let lastIdx = annotations.lastIndex(where: { $0.kind != .mosaic }) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                _ = annotations.remove(at: lastIdx)
                selectedAnnotationId = nil
            }
            HapticFeedbackManager.shared.triggerSelection()
        } else if !annotations.isEmpty {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                _ = annotations.removeLast()
                selectedAnnotationId = nil
            }
            HapticFeedbackManager.shared.triggerSelection()
        } else if !brushStrokes.isEmpty {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                _ = brushStrokes.removeLast()
            }
            HapticFeedbackManager.shared.triggerSelection()
        }
    }
    
    private func showToast() {
        withAnimation {
            isCopiedToClipboardToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                isCopiedToClipboardToast = false
            }
        }
    }
    
    private func saveDirectlyToAlbum(deleteOriginals: Bool = false) {
        guard quotaManager.canStitch() else {
            isShowingPaywall = true
            return
        }
        
        isExporting = true
        let tempOutput = FileManager.default.temporaryDirectory.appendingPathComponent("ScrollSnap_\(Int(Date().timeIntervalSince1970)).jpg")
        defer { try? FileManager.default.removeItem(at: tempOutput) }
        
        Task {
            do {
                try TiledImageRenderer.renderStitchedImageToFile(
                    session: session,
                    annotations: annotations,
                    brushStrokes: brushStrokes,
                    outputURL: tempOutput,
                    format: .jpeg,
                    quality: 0.95
                )
                
                #if canImport(UIKit)
                guard let image = UIImage(contentsOfFile: tempOutput.path) else {
                    await MainActor.run { isExporting = false }
                    return
                }
                
                let watermarked = ExportWatermarkManager.shared.appendWatermarkIfNeeded(to: image, isProUser: storeKit.isProUser)
                
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: watermarked)
                }
                
                // Save copy to AppGroup completed_stitches directory so recent history is updated
                if let jpegData = watermarked.jpegData(compressionQuality: 0.90) {
                    SharedStore.shared.saveCompletedStitch(data: jpegData)
                }
                
                // If requested to delete original source assets
                if deleteOriginals && !session.sourceAssetIdentifiers.isEmpty {
                    let assets = PHAsset.fetchAssets(withLocalIdentifiers: session.sourceAssetIdentifiers, options: nil)
                    var toDelete: [PHAsset] = []
                    assets.enumerateObjects { asset, _, _ in
                        toDelete.append(asset)
                    }
                    if !toDelete.isEmpty {
                        try? await PHPhotoLibrary.shared().performChanges {
                            PHAssetChangeRequest.deleteAssets(toDelete as NSArray)
                        }
                    }
                }
                #endif
                
                quotaManager.recordStitchUsage()
                
                await MainActor.run {
                    self.isExporting = false
                    HapticFeedbackManager.shared.triggerSnap()
                    SoundEffectManager.shared.playShutter()
                    StoreReviewManager.shared.recordSuccessfulExport()
                    self.toastMessage = deleteOriginals ? "已保存长图，并已删除 \(session.sourceAssetIdentifiers.count) 张原截图" : "已保存长图至相册"
                    showToast()
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                }
            }
        }
    }
    
    private func handleExportRequest() {
        guard quotaManager.canStitch() else {
            isShowingPaywall = true
            return
        }
        
        isExporting = true
        let ext = selectedExportFormat.fileExtension
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("ScrollSnap_\(Int(Date().timeIntervalSince1970)).\(ext)")
        
        Task {
            do {
                try TiledImageRenderer.renderStitchedImageToFile(
                    session: session,
                    annotations: annotations,
                    brushStrokes: brushStrokes,
                    outputURL: outputURL,
                    format: selectedExportFormat
                )
                
                #if canImport(UIKit)
                if selectedExportFormat != .pdf, let rawImage = UIImage(contentsOfFile: outputURL.path) {
                    let watermarked = ExportWatermarkManager.shared.appendWatermarkIfNeeded(to: rawImage, isProUser: storeKit.isProUser)
                    if let data = (selectedExportFormat == .png ? watermarked.pngData() : watermarked.jpegData(compressionQuality: 0.9)) {
                        try? data.write(to: outputURL)
                        SharedStore.shared.saveCompletedStitch(data: data)
                    }
                }
                #endif
                
                quotaManager.recordStitchUsage()
                
                await MainActor.run {
                    self.exportedFileURL = outputURL
                    self.isExporting = false
                    self.isShowingExportSheet = true
                    HapticFeedbackManager.shared.triggerSnap()
                    SoundEffectManager.shared.playShutter()
                    StoreReviewManager.shared.recordSuccessfulExport()
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                }
            }
        }
    }
}

#if canImport(UIKit)
public struct ShareSheetView: UIViewControllerRepresentable {
    public let activityItems: [Any]
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

public struct TextExtractorSheet: View {
    public let text: String
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextEditor(text: .constant(text))
                    .font(.body)
                    .padding(8)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: ScrollSnapTheme.Radius.md, style: .continuous))
                
                Button {
                    UIPasteboard.general.string = text
                    HapticFeedbackManager.shared.triggerSnap()
                    dismiss()
                } label: {
                    Label("复制全部文字", systemImage: "doc.on.doc.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScrollSnapButtonStyle.heroPrimary(gradient: ScrollSnapTheme.Colors.primaryGradient))
            }
            .padding()
            .navigationTitle("识别文字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct ScrollViewAccessor: UIViewRepresentable {
    let onAttach: (UIScrollView) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            if let scrollView = findParentScrollView(of: view) {
                onAttach(scrollView)
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = findParentScrollView(of: uiView) {
                onAttach(scrollView)
            }
        }
    }
    
    private func findParentScrollView(of view: UIView) -> UIScrollView? {
        var current: UIView? = view
        while let parent = current?.superview {
            if let scroll = parent as? UIScrollView {
                return scroll
            }
            current = parent
        }
        return nil
    }
}
#endif
