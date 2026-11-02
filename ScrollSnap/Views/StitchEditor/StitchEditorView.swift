import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct StitchEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var session: StitchSession
    
    @State private var selectedSliceIndex: Int = 0
    @State private var isFineTuningSeam = false
    @State private var isAddingRedaction = false
    @State private var currentRedactionStyle: RedactionRegion.RedactionStyle = .pixelatedMosaic
    @State private var isShowingExportSheet = false
    @State private var exportedFileURL: URL?
    @State private var isExporting = false
    @State private var showDeviceFrame = false
    
    public init(session: StitchSession) {
        self._session = State(initialValue: session)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main Long Scroll Canvas
                canvasScrollView
                
                // Bottom Floating Control Bar
                bottomFloatingToolbar
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("长截图调优与导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportFullStitch()
                    } label: {
                        if isExporting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("导出", systemImage: "square.and.arrow.up")
                                .font(.system(.body, design: .rounded).weight(.semibold))
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .sheet(isPresented: $isShowingExportSheet) {
                if let url = exportedFileURL {
                    ShareSheetView(activityItems: [url])
                }
            }
        }
    }
    
    // MARK: - Canvas View
    
    private var canvasScrollView: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(spacing: 0) {
                if showDeviceFrame {
                    DeviceFrameMockupView {
                        slicesStackContent
                    }
                } else {
                    slicesStackContent
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
        }
    }
    
    private var slicesStackContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(session.slices.enumerated()), id: \.element.id) { index, slice in
                VStack(spacing: 0) {
                    if let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
                       let image = UIImage(contentsOfFile: fileURL.path) {
                        
                        let displayHeight = slice.originalHeight / 3.0 // Scaled down for retina display preview
                        let displayWidth = slice.originalWidth / 3.0
                        
                        ZStack(alignment: .topLeading) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: displayWidth, height: displayHeight)
                            
                            // Render Redaction Overlays
                            ForEach(slice.redactions) { redaction in
                                Rectangle()
                                    .fill(redaction.style == .blackout ? Color.black : Color.gray.opacity(0.85))
                                    .frame(
                                        width: redaction.relativeRect.width * displayWidth,
                                        height: redaction.relativeRect.height * displayHeight
                                    )
                                    .offset(
                                        x: redaction.relativeRect.minX * displayWidth,
                                        y: redaction.relativeRect.minY * displayHeight
                                    )
                            }
                            
                            // Seam indicator line
                            if isFineTuningSeam && index > 0 {
                                Rectangle()
                                    .fill(Color.orange)
                                    .frame(height: 2)
                                    .overlay(
                                        Text("接缝对齐线: \(Int(slice.effectiveOverlap))pt")
                                            .font(.caption2.monospacedDigit())
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
                        .onTapGesture { location in
                            if isAddingRedaction {
                                addRedactionAt(index: index, location: location, containerSize: CGSize(width: displayWidth, height: displayHeight))
                            } else {
                                selectedSliceIndex = index
                                HapticFeedbackManager.shared.triggerSelection()
                            }
                        }
                    }
                }
                .offset(y: index == 0 ? 0 : -slice.effectiveOverlap / 3.0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: showDeviceFrame ? 0 : 8, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Floating Toolbar
    
    private var bottomFloatingToolbar: some View {
        VStack(spacing: 8) {
            if isFineTuningSeam && selectedSliceIndex > 0 {
                seamFineTuneBar
            }
            
            HStack(spacing: 16) {
                // Seam Tuning Toggle
                Button {
                    HapticFeedbackManager.shared.triggerSelection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isFineTuningSeam.toggle()
                        isAddingRedaction = false
                    }
                } label: {
                    Label("接缝微调", systemImage: "arrow.up.and.down.and.sparkles")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(isFineTuningSeam ? Color.accentColor : Color.primary)
                }
                
                Divider().frame(height: 18)
                
                // Redaction Mosaic Toggle
                Button {
                    HapticFeedbackManager.shared.triggerSelection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isAddingRedaction.toggle()
                        isFineTuningSeam = false
                    }
                } label: {
                    Label("打码脱敏", systemImage: "checkerboard.rectangle")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(isAddingRedaction ? Color.accentColor : Color.primary)
                }
                
                Divider().frame(height: 18)
                
                // Device Mockup Toggle
                Button {
                    HapticFeedbackManager.shared.triggerSnap()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showDeviceFrame.toggle()
                    }
                } label: {
                    Label("3D带壳", systemImage: "iphone")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(showDeviceFrame ? Color.accentColor : Color.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
        }
        .padding(.bottom, 20)
    }
    
    private var seamFineTuneBar: some View {
        HStack(spacing: 20) {
            Button {
                adjustSelectedSliceOverlap(-4)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
            }
            
            Text("切片 \(selectedSliceIndex) 重叠: \(Int(session.slices[selectedSliceIndex].effectiveOverlap)) pt")
                .font(.system(.caption, design: .rounded).weight(.semibold).monospacedDigit())
            
            Button {
                adjustSelectedSliceOverlap(+4)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }
    
    // MARK: - Actions
    
    private func adjustSelectedSliceOverlap(_ delta: CGFloat) {
        guard selectedSliceIndex < session.slices.count else { return }
        HapticFeedbackManager.shared.triggerSelection()
        session.slices[selectedSliceIndex].manualOffsetAdjustment += delta
    }
    
    private func addRedactionAt(index: Int, location: CGPoint, containerSize: CGSize) {
        guard index < session.slices.count else { return }
        HapticFeedbackManager.shared.triggerSnap()
        
        let boxWidth: CGFloat = 80
        let boxHeight: CGFloat = 28
        let relX = max(0, min(1.0 - boxWidth / containerSize.width, (location.x - boxWidth / 2) / containerSize.width))
        let relY = max(0, min(1.0 - boxHeight / containerSize.height, (location.y - boxHeight / 2) / containerSize.height))
        let relW = boxWidth / containerSize.width
        let relH = boxHeight / containerSize.height
        
        let newRedaction = RedactionRegion(
            relativeRect: CGRect(x: relX, y: relY, width: relW, height: relH),
            style: currentRedactionStyle
        )
        session.slices[index].redactions.append(newRedaction)
    }
    
    private func exportFullStitch() {
        isExporting = true
        HapticFeedbackManager.shared.triggerSnap()
        
        Task.detached(priority: .userInitiated) {
            guard let dir = AppGroupConstants.completedStitchesDirectory else { return }
            let fileName = "Stitch_\(Int(Date().timeIntervalSince1970)).jpg"
            let outputURL = dir.appendingPathComponent(fileName)
            
            do {
                try TiledImageRenderer.renderStitchedImageToFile(session: self.session, outputURL: outputURL)
                await MainActor.run {
                    self.exportedFileURL = outputURL
                    self.isExporting = false
                    self.isShowingExportSheet = true
                    HapticFeedbackManager.shared.triggerSuccess()
                    SharedStore.shared.notifyWidgetReloadDebounced()
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    HapticFeedbackManager.shared.triggerWarning()
                }
            }
        }
    }
}

// MARK: - UIActivityViewController Bridge

private struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
