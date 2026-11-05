import WidgetKit
import SwiftUI
import AppIntents

public struct RecentStitchEntry: TimelineEntry {
    public let date: Date
    public let latestStitchTitle: String
    public let sliceCount: Int
    public let thumbnailPath: String?
}

public struct RecentStitchProvider: TimelineProvider {
    public func placeholder(in context: Context) -> RecentStitchEntry {
        RecentStitchEntry(date: Date(), latestStitchTitle: "长截图预览", sliceCount: 6, thumbnailPath: nil)
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (RecentStitchEntry) -> Void) {
        completion(fetchLatestEntry())
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<RecentStitchEntry>) -> Void) {
        let entry = fetchLatestEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchLatestEntry() -> RecentStitchEntry {
        let dir = AppGroupConstants.completedStitchesDirectory
        if let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]),
           let latest = items.sorted(by: { $0.path > $1.path }).first {
            return RecentStitchEntry(
                date: Date(),
                latestStitchTitle: latest.lastPathComponent,
                sliceCount: 1,
                thumbnailPath: latest.path
            )
        }
        return RecentStitchEntry(date: Date(), latestStitchTitle: "暂无长截图", sliceCount: 0, thumbnailPath: nil)
    }
}

public struct RecentStitchWidgetView: View {
    public let entry: RecentStitchEntry
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "photo.stack.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .font(.subheadline)
                
                Text("最新长截图")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            if let path = entry.thumbnailPath, let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .frame(maxHeight: 70)
                    
                    Text("无最近截图")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            HStack {
                Button(intent: CopyRecentStitchIntent()) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 11))
                        Text("复制")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(uiColor: .secondarySystemGroupedBackground)
        }
    }
}

public struct RecentStitchWidget: Widget {
    public let kind: String = "RecentStitchWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentStitchProvider()) { entry in
            RecentStitchWidgetView(entry: entry)
        }
        .configurationDisplayName("最新长截图")
        .description("快速查看或复制最近拼接的长截图。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
