import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum StudioLightingTheme: String, CaseIterable, Identifiable {
    case cupertinoSunset = "加州暖霞"
    case auroraCyan = "极光青蓝"
    case spaceObsidian = "极夜黑曜"
    case studioClean = "棚拍纯白"
    case transparentAlpha = "透明无底"
    
    public var id: String { rawValue }
    
    public var backgroundGradient: [Color] {
        switch self {
        case .cupertinoSunset:
            return [Color(red: 0.15, green: 0.08, blue: 0.22), Color(red: 0.40, green: 0.15, blue: 0.28), Color(red: 0.88, green: 0.45, blue: 0.35)]
        case .auroraCyan:
            return [Color(red: 0.04, green: 0.12, blue: 0.18), Color(red: 0.08, green: 0.32, blue: 0.35), Color(red: 0.20, green: 0.65, blue: 0.55)]
        case .spaceObsidian:
            return [Color(red: 0.08, green: 0.08, blue: 0.09), Color(red: 0.14, green: 0.14, blue: 0.16), Color(red: 0.05, green: 0.05, blue: 0.06)]
        case .studioClean:
            return [Color(red: 0.94, green: 0.95, blue: 0.97), Color(red: 0.88, green: 0.90, blue: 0.93)]
        case .transparentAlpha:
            return [Color.clear, Color.clear]
        }
    }
}

public struct StudioShowroomView: View {
    public let stitchedImage: UIImage?
    public let onSavePoster: () -> Void
    public let isSaving: Bool
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTheme: StudioLightingTheme = .cupertinoSunset
    @State private var selectedFinish: DeviceFrameFinish = .naturalTitanium
    @State private var dragRotationX: CGFloat = -14.0
    @State private var dragRotationY: CGFloat = 18.0
    @State private var showShadow: Bool = true
    
    public init(
        stitchedImage: UIImage? = nil,
        onSavePoster: @escaping () -> Void = {},
        isSaving: Bool = false
    ) {
        self.stitchedImage = stitchedImage
        self.onSavePoster = onSavePoster
        self.isSaving = isSaving
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Studio Backdrop
                LinearGradient(
                    colors: selectedTheme.backgroundGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 3D Interactive Stage
                    ZStack {
                        // Ambient Radial Spotlight Glow
                        RadialGradient(
                            colors: [Color.white.opacity(0.12), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 280
                        )
                        
                        // 3D Floating Device
                        VStack(spacing: 0) {
                            if let img = stitchedImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 460)
                            } else {
                                // Fallback mock placeholder
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 220, height: 440)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.on.rectangle.angled")
                                                .font(.largeTitle)
                                            Text("ScrollSnap 超清长图")
                                                .font(.headline)
                                        }
                                        .foregroundStyle(.white)
                                    )
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                        // Outer Titanium Bezel
                        .overlay(
                            RoundedRectangle(cornerRadius: 36, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: selectedFinish.bezelGradient,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        )
                        // Specular Rim
                        .overlay(
                            RoundedRectangle(cornerRadius: 36, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                        )
                        // Drop shadow
                        .shadow(
                            color: Color.black.opacity(showShadow ? 0.45 : 0.0),
                            radius: 30,
                            x: dragRotationY * 0.8,
                            y: 20
                        )
                        // 3D Perspective Rotation
                        .rotation3DEffect(.degrees(Double(dragRotationY)), axis: (x: 0, y: 1, z: 0))
                        .rotation3DEffect(.degrees(Double(dragRotationX)), axis: (x: 1, y: 0, z: 0))
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    dragRotationY = min(max(val.translation.width * 0.15 + 18, -35), 35)
                                    dragRotationX = min(max(-val.translation.height * 0.15 - 14, -30), 20)
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        dragRotationX = -14.0
                                        dragRotationY = 18.0
                                    }
                                }
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Bottom Customizer Tray
                    VStack(spacing: 14) {
                        // Lighting Themes
                        HStack {
                            Text("摄影棚氛围")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(StudioLightingTheme.allCases) { theme in
                                    Button {
                                        selectedTheme = theme
                                        HapticFeedbackManager.shared.triggerSelection()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(theme.backgroundGradient.first ?? Color.gray)
                                                .frame(width: 12, height: 12)
                                            Text(theme.rawValue)
                                                .font(.caption2.bold())
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule()
                                                .fill(selectedTheme == theme ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Device Bezel Finishes
                        HStack(spacing: 12) {
                            Text("边框工艺")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            ForEach(DeviceFrameFinish.allCases) { finish in
                                Button {
                                    selectedFinish = finish
                                    HapticFeedbackManager.shared.triggerSelection()
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(finish.bezelGradient.first ?? Color.gray)
                                            .frame(width: 10, height: 10)
                                        Text(finish.rawValue)
                                            .font(.caption2)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(selectedFinish == finish ? Color.white.opacity(0.2) : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                        }
                        
                        // Action Button
                        Button {
                            HapticFeedbackManager.shared.triggerSuccess()
                            SoundEffectManager.shared.playShutter()
                            StoreReviewManager.shared.recordSuccessfulExport()
                            onSavePoster()
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.headline)
                                    Text("一键导出 3D 悬浮海报")
                                        .font(.headline.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                            )
                            .foregroundStyle(Color.black)
                            .shadow(color: Color.black.opacity(0.25), radius: 10, y: 4)
                        }
                        .disabled(isSaving)
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("3D 摄影棚制图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                }
            }
        }
    }
}
