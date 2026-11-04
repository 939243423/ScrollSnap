import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct SocialGridStageView: View {
    public let slices: [UIImage]
    public let onSaveToAlbum: () -> Void
    public let onReset: (() -> Void)?
    public let isSaving: Bool
    
    @State private var hoveredCardIndex: Int? = nil
    
    public init(
        slices: [UIImage],
        onSaveToAlbum: @escaping () -> Void,
        onReset: (() -> Void)? = nil,
        isSaving: Bool = false
    ) {
        self.slices = slices
        self.onSaveToAlbum = onSaveToAlbum
        self.onReset = onReset
        self.isSaving = isSaving
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    public var body: some View {
        VStack(spacing: 14) {
            // Header stats
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.fill")
                        .foregroundStyle(Color.pink)
                    Text("小红书 3:4 黄金画幅切片")
                        .font(.caption.bold())
                }
                Spacer()
                Text("\(slices.count) 屏高清分块")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            
            // 3x3 Interactive Cards Grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                    ZStack(alignment: .bottomTrailing) {
                        Image(uiImage: slice)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 100)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        hoveredCardIndex == index ? Color.pink : Color.white.opacity(0.18),
                                        lineWidth: hoveredCardIndex == index ? 2 : 0.8
                                    )
                            )
                        
                        // Card sequence index badge
                        Text("#\(index + 1)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.75))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .padding(4)
                    }
                    .scaleEffect(hoveredCardIndex == index ? 1.05 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.7), value: hoveredCardIndex)
                    .onTapGesture {
                        HapticFeedbackManager.shared.triggerSelection()
                        hoveredCardIndex = (hoveredCardIndex == index ? nil : index)
                    }
                }
            }
            .padding(ScrollSnapTheme.Spacing.sm + 2)
            .scrollSnapCard(radius: ScrollSnapTheme.Radius.lg, strokeColor: Color.pink.opacity(0.25))
            
            // Actions Row
            HStack(spacing: 10) {
                if let onReset = onReset {
                    Button {
                        HapticFeedbackManager.shared.triggerSelection()
                        onReset()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("重设分块")
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ScrollSnapButtonStyle.bouncy)
                }
                
                // Batch Save Button
                Button {
                    HapticFeedbackManager.shared.triggerSnap()
                    onSaveToAlbum()
                } label: {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down.on.square.fill")
                        }
                        Text("一键存 \(slices.count) 张切片")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(ScrollSnapButtonStyle.heroPrimary(gradient: ScrollSnapTheme.Colors.studioGradient))
                .disabled(isSaving || slices.isEmpty)
            }
        }
    }
}
