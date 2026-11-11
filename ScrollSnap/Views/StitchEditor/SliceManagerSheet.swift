import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Clean, intuitive sheet for reordering or deleting original screenshot slices
public struct SliceManagerSheet: View {
    @Binding public var session: StitchSession
    @Environment(\.dismiss) private var dismiss
    
    @State private var itemPendingDeletionIndex: Int? = nil
    @State private var isShowingDeleteAlert: Bool = false
    
    public init(session: Binding<StitchSession>) {
        self._session = session
    }
    
    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("可调整截图前后顺序或删除多选的重复截图，调整后系统将自动重新对齐接缝。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                }
                
                Section("截图列表 (共 \(session.slices.count) 张)") {
                    ForEach(Array(session.slices.enumerated()), id: \.element.id) { index, slice in
                        HStack(spacing: 12) {
                            // Thumbnail Preview
                            sliceThumbnail(for: slice)
                                .frame(width: 52, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                            
                            // Slice Metadata
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("第 \(index + 1) 张")
                                        .font(.system(size: 14, weight: .bold))
                                    
                                    if index == 0 {
                                        Text("顶部首图")
                                            .font(.system(size: 10, weight: .semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                                            .foregroundStyle(Color.accentColor)
                                    } else if index == session.slices.count - 1 {
                                        Text("底部尾图")
                                            .font(.system(size: 10, weight: .semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.12), in: Capsule())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Text("\(Int(slice.originalWidth)) × \(Int(slice.originalHeight)) 像素")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                if index > 0 {
                                    HStack(spacing: 4) {
                                        Text("重合 \(Int(slice.effectiveOverlap)) 像素")
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(slice.confidence < 0.4 ? Color.orange : Color.secondary)
                                        
                                        if slice.confidence < 0.4 {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.system(size: 9))
                                                .foregroundStyle(Color.orange)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Reorder and Delete Controls
                            HStack(spacing: 6) {
                                Button {
                                    moveSliceUp(from: index)
                                } label: {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 12, weight: .bold))
                                        .frame(width: 32, height: 32)
                                        .background(Color.primary.opacity(0.06), in: Circle())
                                }
                                .disabled(index == 0)
                                .buttonStyle(.plain)
                                .accessibilityLabel("上移")
                                
                                Button {
                                    moveSliceDown(from: index)
                                } label: {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .frame(width: 32, height: 32)
                                        .background(Color.primary.opacity(0.06), in: Circle())
                                }
                                .disabled(index == session.slices.count - 1)
                                .buttonStyle(.plain)
                                .accessibilityLabel("下移")
                                
                                Button(role: .destructive) {
                                    itemPendingDeletionIndex = index
                                    isShowingDeleteAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(session.slices.count > 2 ? Color.red : Color.secondary.opacity(0.4))
                                        .frame(width: 32, height: 32)
                                        .background(session.slices.count > 2 ? Color.red.opacity(0.1) : Color.primary.opacity(0.04), in: Circle())
                                }
                                .disabled(session.slices.count <= 2)
                                .buttonStyle(.plain)
                                .accessibilityLabel("删除")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("原截图管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.body.weight(.bold))
                }
            }
            .alert("确认删除此截图？", isPresented: $isShowingDeleteAlert) {
                Button("删除", role: .destructive) {
                    if let idx = itemPendingDeletionIndex {
                        deleteSlice(at: idx)
                    }
                    itemPendingDeletionIndex = nil
                }
                Button("取消", role: .cancel) {
                    itemPendingDeletionIndex = nil
                }
            } message: {
                Text("删除后将使用剩余的 \(session.slices.count - 1) 张截图重新自动对齐长图。")
            }
        }
    }
    
    // MARK: - Actions
    
    private func moveSliceUp(from index: Int) {
        guard index > 0 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            session.slices.swapAt(index, index - 1)
            StitchEngine.recomputeSlices(in: &session)
        }
        HapticFeedbackManager.shared.triggerSelection()
    }
    
    private func moveSliceDown(from index: Int) {
        guard index < session.slices.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            session.slices.swapAt(index, index + 1)
            StitchEngine.recomputeSlices(in: &session)
        }
        HapticFeedbackManager.shared.triggerSelection()
    }
    
    private func deleteSlice(at index: Int) {
        guard session.slices.count > 2, index < session.slices.count else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            session.slices.remove(at: index)
            StitchEngine.recomputeSlices(in: &session)
        }
        HapticFeedbackManager.shared.triggerSnap()
    }
    
    // MARK: - Thumbnail Builder
    
    @ViewBuilder
    private func sliceThumbnail(for slice: StitchItem) -> some View {
        if let fileURL = SharedStore.shared.resolveFileURL(relativePath: slice.relativeFilePath),
           let image = UIImage(contentsOfFile: fileURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .overlay(
                    Image(systemName: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                )
        }
    }
}
