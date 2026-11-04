import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public final class SharedStore {
    public static let shared = SharedStore()
    
    private let suiteName = AppGroupConstants.suiteName
    private var reloadDebounceWorkItem: DispatchWorkItem?
    private let fileManager = FileManager.default
    
    private init() {
        // Concurrency safety: Zero synchronous singleton calls in init()
        ensureDirectoriesExist()
    }
    
    private func ensureDirectoriesExist() {
        let container = AppGroupConstants.containerURL
        let sessionDir = container.appendingPathComponent("active_session", isDirectory: true)
        let completeDir = container.appendingPathComponent("completed_stitches", isDirectory: true)
        
        try? fileManager.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: completeDir, withIntermediateDirectories: true)
    }
    
    // MARK: - Active Broadcast Slices Management
    
    public func resetActiveBroadcastSession() {
        let dir = AppGroupConstants.activeSessionDirectory
        try? fileManager.removeItem(at: dir)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    
    public func writeBroadcastSlice(data: Data, index: Int) -> String? {
        let dir = AppGroupConstants.activeSessionDirectory
        let fileName = String(format: "slice_%04d.jpg", index)
        let fileURL = dir.appendingPathComponent(fileName)
        
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            return "active_session/\(fileName)"
        } catch {
            print("[SharedStore] writeBroadcastSlice failed: \(error)")
            return nil
        }
    }
    
    public func listActiveBroadcastSlicePaths() -> [String] {
        let dir = AppGroupConstants.activeSessionDirectory
        guard let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        
        let sliceFiles = files
            .filter { $0.pathExtension.lowercased() == "jpg" && $0.lastPathComponent.hasPrefix("slice_") }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        
        return sliceFiles.map { "active_session/\($0.lastPathComponent)" }
    }
    
    // MARK: - Disk File Resolution
    
    public func resolveFileURL(relativePath: String) -> URL? {
        let container = AppGroupConstants.containerURL
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
