import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = StoreKitManager.shared
    @State private var isShowingProPaywall = false
    @State private var cacheSizeBytes: Int = 0
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Subscription Section
                Section {
                    Button {
                        isShowingProPaywall = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "crown.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.accentColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(storeKit.isProUser ? "✨ 已激活 ¥1 永久特权" : "纯粹效率 · 1元永久买断")
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(storeKit.isProUser ? "享有无限制拼图、AI脱敏与9宫格切片" : "每日免费 2 次 · ¥1.00 永久买断")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                // Cache & Storage Section
                Section("缓存与存储") {
                    HStack {
                        Text("长截图临时缓存")
                        Spacer()
                        Text(formatBytes(cacheSizeBytes))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("清理全部切片缓存", role: .destructive) {
                        clearCache()
                    }
                }
                
                // Privacy & Architecture
                Section("隐私与架构安全") {
                    HStack {
                        Text("端侧离线计算")
                        Spacer()
                        Text("100% 本地运算")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("隐私上报")
                        Spacer()
                        Text("零数据收集")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("算法内核")
                        Spacer()
                        Text("CoreGraphics NCC")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Legal & About Section
                Section("法律协议与关于") {
                    Link(destination: URL(string: "https://939243423.github.io/protocol__ScrollSnap/privacy.html")!) {
                        HStack {
                            Text("隐私政策 (Privacy Policy)")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://939243423.github.io/protocol__ScrollSnap/terms.html")!) {
                        HStack {
                            Text("用户服务协议与 EULA (Terms)")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://939243423.github.io/protocol__ScrollSnap/")!) {
                        HStack {
                            Text("合规与政策中心")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0 (Build 2026.11)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingProPaywall) {
                ProSubscriptionView()
            }
            .onAppear {
                calculateCacheSize()
            }
        }
    }
    
    private func calculateCacheSize() {
        guard let container = AppGroupConstants.containerURL else { return }
        var total = 0
        if let enumerator = FileManager.default.enumerator(at: container, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resource = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let size = resource.fileSize {
                    total += size
                }
            }
        }
        self.cacheSizeBytes = total
    }
    
    private func clearCache() {
        SharedStore.shared.resetActiveBroadcastSession()
        calculateCacheSize()
        HapticFeedbackManager.shared.triggerSuccess()
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
