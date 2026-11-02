import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum EditorToolMode: String, CaseIterable, Identifiable {
    case seamTuner = "接缝对齐"
    case annotation = "专业标注"
    case socialSlicer = "九宫格切片"
    case canvasStudio = "带壳画布"
    
    public var id: String { rawValue }
    public var iconName: String {
        switch self {
        case .seamTuner: return "arrow.up.and.down.and.sparkles"
        case .annotation: return "pencil.tip.crop.circle"
        case .socialSlicer: return "square.grid.3x3"
        case .canvasStudio: return "iphone"
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
    @State private var activeToolMode: EditorToolMode = .seamTuner
    
    // Seam Fine-tuning State
    @State private var selectedSliceIndex: Int = 1
    
    // Annotation Suite State
    @State private var annotations: [AnnotationItem] = []
    @State private var activeAnnotationKind: AnnotationKind = .rectangle
    @State private var activeAnnotationColor: AnnotationColor = .crimsonRed
    @State private var nextStepBadgeNumber: Int = 1
    @State private var currentDrawingItem: AnnotationItem?
    @State private var textInputPrompt: String = ""
    @State private var isShowingTextAlert: Bool = false
    @State private var pendingTextLocation: CGPoint = .zero
    
    // Canvas & Mockup State
    @State private var showDeviceFrame: Bool = false
    @State private var frameFinish: DeviceFrameFinish = .naturalTitanium
    @State private var canvasBackground: CanvasBackgroundStyle = .adaptiveBlur
    @State private var canvasPadding: CGFloat = 20.0
    
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
    @State private var toastMessage: String = "长截图已复制到剪贴板，可直接粘贴"
    
    public init(session: StitchSession) {
        self._session = State(initialValue: session)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main Interactive Canvas
                canvasScrollView
                
                // Bottom Liquid Glass Floating Modular Control Bar
                bottomLiquidControlBar
                
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
                    Button("完成") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    presetModeMenu
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            copyDirectlyToClipboard()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        
                        Menu {
                            Section("导出格式") {
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
                                Label("导出", systemImage: "square.and.arrow.up")
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                            }
                        }
                        .disabled(isExporting)
                    }
                }
            }
            .sheet(isPresented: $isShowingExportSheet) {
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
            .alert("已成功保存到系统相册", isPresented: $isShowingSlicesSavedAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text("已将长图拆解为 \(generatedSlices.count) 张高清九宫格切片，现在可直接前往微信或小红书发布。")
            }
        }
    }
    
    // MARK: - Canvas View
    
    private var canvasScrollView: some View {
        GeometryReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                VStack(spacing: 0) {
                    if showDeviceFrame {
                        DeviceFrameMockupView(
                            finish: frameFinish,
                            backgroundStyle: canvasBackground,
                            canvasPadding: canvasPadding
                        ) {
                            annotatedCanvasStack
                        }
                    } else {
                        annotatedCanvasStack
                    }
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 16)
                .frame(minWidth: proxy.size.width)
            }
        }
    }
    
    private var annotatedCanvasStack: some View {
        let displayWidth: CGFloat = (session.slices.first?.originalWidth ?? 393) / 3.0
        let totalDisplayHeight: CGFloat = session.totalEstimatedHeight / 3.0
        
        return ZStack(alignment: .topLeading) {
            // Underneath: Raw Stitched Slices
            VStack(spacing: 0) {
                ForEach(Array(session.slices.enumerated()), id: \.element.id) { index, slice in
                    renderSliceView(index: index, slice: slice, displayWidth: displayWidth)
                }
            }
            
            // Middle: Rendered Annotations
            ForEach(annotations) { item in
                renderAnnotationOverlay(item: item, canvasWidth: displayWidth, canvasHeight: totalDisplayHeight)
            }
            
            // Current In-progress Drawing Shape
            if let drawing = currentDrawingItem {
                renderAnnotationOverlay(item: drawing, canvasWidth: displayWidth, canvasHeight: totalDisplayHeight)
            }
            
            // Top: Interaction Layer for Gesture Input
            if activeToolMode == .annotation {
                Color.white.opacity(0.001)
                    .frame(width: displayWidth, height: totalDisplayHeight)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleAnnotationDragChanged(value: value, canvasSize: CGSize(width: displayWidth, height: totalDisplayHeight))
                            }
                            .onEnded { value in
                                handleAnnotationDragEnded(value: value, canvasSize: CGSize(width: displayWidth, height: totalDisplayHeight))
                            }
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: showDeviceFrame ? 0 : 8, style: .continuous))
        .shadow(color: Color.black.opacity(showDeviceFrame ? 0 : 0.12), radius: 14, x: 0, y: 6)
    }
    
    private func renderSliceView(index: Int, slice: StitchItem, displayWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            if let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
               let image = UIImage(contentsOfFile: fileURL.path) {
                
                let isMovieSubtitlesMode = (session.presetMode == .movieSubtitles)
                let displayVisibleHeight: CGFloat
                let displayOriginalHeight = slice.originalHeight / 3.0
                let displayTopCrop: CGFloat
                
                if isMovieSubtitlesMode && index > 0 {
                    // Movie Subtitles Mode: slice 1..N only show bottom 18% subtitle bar
                    displayVisibleHeight = displayOriginalHeight * 0.18
                    displayTopCrop = displayOriginalHeight * 0.82
                } else {
                    displayVisibleHeight = slice.visibleHeight / 3.0
                    displayTopCrop = slice.topCropInset / 3.0
                }
                
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: displayWidth, height: displayOriginalHeight)
                        .offset(y: -displayTopCrop)
                        .frame(width: displayWidth, height: displayVisibleHeight, alignment: .top)
                        .clipped()
                    
                    // Seam indicator line when tuner mode is active
                    if activeToolMode == .seamTuner && index > 0 {
                        Rectangle()
                            .fill(selectedSliceIndex == index ? Color.orange : Color.orange.opacity(0.5))
                            .frame(height: selectedSliceIndex == index ? 2.5 : 1)
                            .overlay(
                                Text("接缝 #\(index): \(Int(slice.effectiveOverlap))pt")
                                    .font(.caption2.bold().monospacedDigit())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .offset(y: -14)
                            )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if activeToolMode == .seamTuner && index > 0 {
                        selectedSliceIndex = index
                        HapticFeedbackManager.shared.triggerSelection()
                    }
                }
            }
        }
        .offset(y: index == 0 ? 0 : -slice.effectiveOverlap / 3.0)
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
            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            .stroke(color, style: StrokeStyle(lineWidth: item.lineWidth, lineCap: .round, lineJoin: .round))
            
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
            .stroke(color.opacity(0.4), style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
            
        case .textNote:
            if !item.textContent.isEmpty {
                Text(item.textContent)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.78))
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
            Rectangle()
                .fill(item.isBlackout ? Color.black : Color.gray.opacity(0.85))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }
    
    private func handleAnnotationDragChanged(value: DragGesture.Value, canvasSize: CGSize) {
        let normStart = CGPoint(x: value.startLocation.x / canvasSize.width, y: value.startLocation.y / canvasSize.height)
        let normCurrent = CGPoint(x: value.location.x / canvasSize.width, y: value.location.y / canvasSize.height)
        
        switch activeAnnotationKind {
        case .rectangle, .arrow, .mosaic:
            currentDrawingItem = AnnotationItem(
                kind: activeAnnotationKind,
                color: activeAnnotationColor,
                lineWidth: 3.0,
                startPoint: normStart,
                endPoint: normCurrent,
                isBlackout: (activeAnnotationKind == .mosaic && activeAnnotationColor == .midnightBlack)
            )
        case .highlighter:
            if currentDrawingItem == nil {
                currentDrawingItem = AnnotationItem(
                    kind: .highlighter,
                    color: activeAnnotationColor,
                    freehandPoints: [normStart]
                )
            } else {
                currentDrawingItem?.freehandPoints.append(normCurrent)
            }
        case .stepBadge, .textNote:
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
    
    // MARK: - Liquid Glass Bottom Control Bar
    
    private var bottomLiquidControlBar: some View {
        VStack(spacing: 8) {
            // Secondary expanded tool options panel
            switch activeToolMode {
            case .seamTuner:
                seamTunerPanel
            case .annotation:
                annotationToolsPanel
            case .socialSlicer:
                socialSlicerPanel
            case .canvasStudio:
                canvasStudioPanel
            }
            
            // Primary 4-Tab Liquid Glass Bar
            HStack(spacing: 12) {
                ForEach(EditorToolMode.allCases) { mode in
                    Button {
                        HapticFeedbackManager.shared.triggerSelection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            activeToolMode = mode
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 16, weight: activeToolMode == mode ? .bold : .medium))
                            Text(mode.rawValue)
                                .font(.system(size: 10, weight: activeToolMode == mode ? .semibold : .regular))
                        }
                        .foregroundStyle(activeToolMode == mode ? Color.accentColor : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            activeToolMode == mode
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .liquidGlassCard(cornerRadius: 24, strokeOpacity: 0.32)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // Sub-panel: Seam Tuner
    private var seamTunerPanel: some View {
        HStack(spacing: 16) {
            Button {
                adjustSliceOverlap(sliceIndex: selectedSliceIndex, delta: -3)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 2) {
                Text("接缝 #\(selectedSliceIndex) 重叠调整")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if selectedSliceIndex < session.slices.count {
                    Text("\(Int(session.slices[selectedSliceIndex].effectiveOverlap)) pt")
                        .font(.subheadline.bold().monospacedDigit())
                }
            }
            
            Button {
                adjustSliceOverlap(sliceIndex: selectedSliceIndex, delta: 3)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .liquidGlassPill()
    }
    
    // Sub-panel: Annotation Tools (Now with AI Privacy & OCR Buttons)
    private var annotationToolsPanel: some View {
        VStack(spacing: 8) {
            // Smart Action Strip
            HStack(spacing: 10) {
                Button {
                    runVisionAutoSanitization()
                } label: {
                    HStack(spacing: 4) {
                        if privacySanitizer.isDetecting {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("AI智能脱敏")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.18))
                    .foregroundStyle(Color.orange)
                    .clipShape(Capsule())
                }
                .disabled(privacySanitizer.isDetecting)
                
                Button {
                    runFullTextOCR()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.viewfinder")
                        Text("提取长图文字")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.indigo.opacity(0.18))
                    .foregroundStyle(Color.indigo)
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                Button {
                    if !annotations.isEmpty {
                        annotations.removeLast()
                        HapticFeedbackManager.shared.triggerSelection()
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .semibold))
                }
                .disabled(annotations.isEmpty)
            }
            
            Divider().opacity(0.3)
            
            HStack(spacing: 14) {
                annotationKindButton(kind: .rectangle, icon: "rectangle")
                annotationKindButton(kind: .arrow, icon: "arrow.up.right")
                annotationKindButton(kind: .stepBadge, icon: "1.circle.fill")
                annotationKindButton(kind: .highlighter, icon: "pencil.tip")
                annotationKindButton(kind: .textNote, icon: "text.bubble")
                annotationKindButton(kind: .mosaic, icon: "checkerboard.rectangle")
            }
            
            // Color Palette Selector
            HStack(spacing: 10) {
                ForEach([AnnotationColor.crimsonRed, .electricOrange, .neonYellow, .mintGreen, .deepIndigo, .midnightBlack], id: \.self) { color in
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: activeAnnotationColor == color ? 2.5 : 0)
                        )
                        .onTapGesture {
                            activeAnnotationColor = color
                            HapticFeedbackManager.shared.triggerSelection()
                        }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .liquidGlassCard(cornerRadius: 18, strokeOpacity: 0.25)
    }
    
    private func annotationKindButton(kind: AnnotationKind, icon: String) -> some View {
        Button {
            activeAnnotationKind = kind
            HapticFeedbackManager.shared.triggerSelection()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: activeAnnotationKind == kind ? .bold : .regular))
                .foregroundStyle(activeAnnotationKind == kind ? Color.accentColor : Color.secondary)
        }
    }
    
    // Sub-panel: Social Slicer (九宫格切片)
    private var socialSlicerPanel: some View {
        VStack(spacing: 8) {
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
                triggerSliceAndSave()
            } label: {
                HStack(spacing: 6) {
                    if isSlicing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.down.on.square.fill")
                    }
                    Text("智能断句并批量保存 \(selectedSlicePreset.rawValue) 张切片到相册")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .disabled(isSlicing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .liquidGlassCard(cornerRadius: 20)
    }
    
    // Sub-panel: Canvas & Mockup Studio
    private var canvasStudioPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Toggle(isOn: $showDeviceFrame.animation()) {
                    Text("3D钛金属外壳")
                        .font(.caption.bold())
                }
                .toggleStyle(.button)
                .tint(.accentColor)
                
                if showDeviceFrame {
                    Picker("机型材质", selection: $frameFinish) {
                        ForEach(DeviceFrameFinish.allCases) { finish in
                            Text(finish.rawValue).tag(finish)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                }
            }
            
            if showDeviceFrame {
                HStack(spacing: 8) {
                    ForEach(CanvasBackgroundStyle.allCases) { bg in
                        Button {
                            canvasBackground = bg
                        } label: {
                            Text(bg.rawValue)
                                .font(.system(size: 10, weight: canvasBackground == bg ? .bold : .regular))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(canvasBackground == bg ? Color.accentColor.opacity(0.2) : Color.clear)
                                .clipShape(Capsule())
                        }
                    }
                }
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .liquidGlassPill()
        .transition(.move(edge: .top).combined(with: .opacity))
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
        
        for i in 0..<session.slices.count {
            if i > 0 && i < session.slices.count - 1 {
                session.slices[i].topCropInset = newMode.defaultTopCropInset
                session.slices[i].bottomCropInset = newMode.defaultBottomCropInset
            }
        }
        HapticFeedbackManager.shared.triggerSnap()
    }
    
    private func adjustSliceOverlap(sliceIndex: Int, delta: CGFloat) {
        guard sliceIndex > 0 && sliceIndex < session.slices.count else { return }
        session.slices[sliceIndex].manualOverlapAdjustment += delta
        HapticFeedbackManager.shared.triggerSelection()
    }
    
    // AI Vision Auto Sanitization
    private func runVisionAutoSanitization() {
        Task {
            let tempOutput = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            try? TiledImageRenderer.renderStitchedImageToFile(
                session: session,
                outputURL: tempOutput,
                format: .jpeg
            )
            
            if let image = UIImage(contentsOfFile: tempOutput.path) {
                let autoMosaics = await privacySanitizer.detectSensitiveRegions(in: image)
                await MainActor.run {
                    self.annotations.append(contentsOf: autoMosaics)
                    HapticFeedbackManager.shared.triggerSnap()
                    self.toastMessage = "AI 已自动对头像与敏感数字打码脱敏！"
                    showToast()
                }
            }
        }
    }
    
    // Full-Text OCR Extraction
    private func runFullTextOCR() {
        Task {
            let tempOutput = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
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
    
    private func triggerSliceAndSave() {
        guard !session.slices.isEmpty else { return }
        isSlicing = true
        
        Task {
            let tempOutput = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            try? TiledImageRenderer.renderStitchedImageToFile(
                session: session,
                annotations: annotations,
                outputURL: tempOutput,
                format: .jpeg
            )
            
            if let image = UIImage(contentsOfFile: tempOutput.path) {
                let slices = ImageSlicer.shared.sliceImage(image: image, count: selectedSlicePreset.rawValue)
                try? await ImageSlicer.shared.saveSlicesToAlbum(slices: slices)
                await MainActor.run {
                    self.generatedSlices = slices
                    self.isSlicing = false
                    self.isShowingSlicesSavedAlert = true
                    HapticFeedbackManager.shared.triggerSnap()
                }
            } else {
                await MainActor.run { self.isSlicing = false }
            }
        }
    }
    
    private func copyDirectlyToClipboard() {
        guard quotaManager.canStitch() else {
            isShowingPaywall = true
            return
        }
        
        Task {
            let tempOutput = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            try? TiledImageRenderer.renderStitchedImageToFile(
                session: session,
                annotations: annotations,
                outputURL: tempOutput,
                format: .jpeg
            )
            
            if let image = UIImage(contentsOfFile: tempOutput.path) {
                UIPasteboard.general.image = image
                quotaManager.recordStitchUsage()
                
                await MainActor.run {
                    HapticFeedbackManager.shared.triggerSnap()
                    self.toastMessage = "已复制长截图到剪贴板，可直接粘贴"
                    showToast()
                }
            }
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
                    outputURL: outputURL,
                    format: selectedExportFormat
                )
                
                quotaManager.recordStitchUsage()
                
                await MainActor.run {
                    self.exportedFileURL = outputURL
                    self.isExporting = false
                    self.isShowingExportSheet = true
                    HapticFeedbackManager.shared.triggerSnap()
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
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                Button {
                    UIPasteboard.general.string = text
                    HapticFeedbackManager.shared.triggerSnap()
                    dismiss()
                } label: {
                    Label("复制全部文字并关闭", systemImage: "doc.on.doc.fill")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .navigationTitle("长图全文提取 (OCR)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
#endif
