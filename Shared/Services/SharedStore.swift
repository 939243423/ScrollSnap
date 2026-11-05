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
        let sessionsDir = container.appendingPathComponent("sessions", isDirectory: true)
        
        try? fileManager.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: completeDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
    }
    
    // MARK: - Active Broadcast Slices Management
    
    public func resetActiveBroadcastSession() {
        let dir = AppGroupConstants.activeSessionDirectory
        try? fileManager.removeItem(at: dir)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    
    /// Copies temporary slice files into a persistent session-specific directory so they aren't deleted when active_session is reset
    public func persistSessionSlices(fromRelativePaths paths: [String], sessionId: UUID) -> [String] {
        let container = AppGroupConstants.containerURL
        let sessionDirName = "sessions/\(sessionId.uuidString)"
        let targetDir = container.appendingPathComponent(sessionDirName, isDirectory: true)
        try? fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        var persistedPaths: [String] = []
        for (idx, relPath) in paths.enumerated() {
            guard let srcURL = resolveFileURL(relativePath: relPath) else { continue }
            let ext = srcURL.pathExtension.isEmpty ? "jpg" : srcURL.pathExtension
            let destFileName = String(format: "slice_%04d.%@", idx, ext)
            let destURL = targetDir.appendingPathComponent(destFileName)
            
            try? fileManager.removeItem(at: destURL)
            if (try? fileManager.copyItem(at: srcURL, to: destURL)) != nil {
                persistedPaths.append("\(sessionDirName)/\(destFileName)")
            } else if fileManager.fileExists(atPath: srcURL.path) {
                persistedPaths.append(relPath)
            }
        }
        return persistedPaths
    }
    
    /// Prunes session directories older than 3 days to preserve disk storage
    public func cleanupOldSessions(maxAge: TimeInterval = 86400 * 3) {
        let container = AppGroupConstants.containerURL
        let sessionsDir = container.appendingPathComponent("sessions", isDirectory: true)
        guard let subdirs = try? fileManager.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let now = Date()
        for dir in subdirs {
            if let values = try? dir.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               now.timeIntervalSince(modDate) > maxAge {
                try? fileManager.removeItem(at: dir)
            }
        }
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
