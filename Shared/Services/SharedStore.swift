import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public final class SharedStore {
    public static let shared = SharedStore()
    
    private let suiteName = AppGroupConstants.suiteName
    private var reloadDebounceWorkItem: DispatchWorkItem?
    private let fileManager = FileManager.default
    
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
    
    private init() {
        // Strict anti-deadlock rule: zero synchronous calls to other singletons
        ensureDirectoriesExist()
    }
    
    private func ensureDirectoriesExist() {
        guard let container = AppGroupConstants.containerURL else { return }
        let sessionDir = container.appendingPathComponent("active_session", isDirectory: true)
        let completeDir = container.appendingPathComponent("completed_stitches", isDirectory: true)
        
        try? fileManager.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: completeDir, withIntermediateDirectories: true)
    }
    
    // MARK: - Active Broadcast Session Management
    
    public func resetActiveBroadcastSession() {
        guard let dir = AppGroupConstants.activeSessionDirectory else { return }
        try? fileManager.removeItem(at: dir)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        
        defaults?.removeObject(forKey: AppGroupConstants.keyActiveSessionMetadata)
    }
    
    public func writeBroadcastSlice(data: Data, index: Int) -> String? {
        guard let dir = AppGroupConstants.activeSessionDirectory else { return nil }
        let fileName = String(format: "slice_%04d.jpg", index)
        let fileURL = dir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL, options: .atomic)
            return "active_session/\(fileName)"
        } catch {
            return nil
        }
    }
    
    public func saveActiveSessionMetadata(_ session: StitchSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults?.set(data, forKey: AppGroupConstants.keyActiveSessionMetadata)
    }
    
    public func loadActiveSessionMetadata() -> StitchSession? {
        guard let data = defaults?.data(forKey: AppGroupConstants.keyActiveSessionMetadata) else { return }
        return try? JSONDecoder().decode(StitchSession.self, from: data)
    }
    
    public func listActiveBroadcastSlicePaths() -> [String] {
        guard let dir = AppGroupConstants.activeSessionDirectory,
              let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        
        let sliceFiles = files
            .filter { $0.pathExtension.lowercased() == "jpg" && $0.lastPathComponent.hasPrefix("slice_") }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        
        return sliceFiles.map { "active_session/\($0.lastPathComponent)" }
    }
    
    // MARK: - Disk File Resolution
    
    public func resolveFileURL(relativePath: String) -> URL? {
        guard let container = AppGroupConstants.containerURL else { return nil }
        return container.appendingPathComponent(relativePath)
    }
    
    // MARK: - Widget Reload Debounce (300ms)
    
    public func notifyWidgetReloadDebounced(kind: String = "RecentStitchWidget") {
        #if canImport(WidgetKit)
        reloadDebounceWorkItem?.cancel()
        let item = DispatchWorkItem {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
        reloadDebounceWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
        #endif
    }
}
