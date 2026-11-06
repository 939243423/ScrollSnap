import Foundation

public struct CacheBreakdown: Equatable {
    public let temporaryCacheBytes: Int64
    public let recentSavesBytes: Int64
    
    public var totalCacheBytes: Int64 {
        temporaryCacheBytes + recentSavesBytes
    }
    
    public init(temporaryCacheBytes: Int64, recentSavesBytes: Int64) {
        self.temporaryCacheBytes = temporaryCacheBytes
        self.recentSavesBytes = recentSavesBytes
    }
}

public final class AppCacheManager {
    public static let shared = AppCacheManager()
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Cache Calculation
    
    /// Computes accurate disk storage usage across all cache categories:
    /// - Temporary files (imported videos, intermediate full-canvas renders, slice extraction)
    /// - System caches (URLSession, WebKit, image cache)
    /// - Active ReplayKit broadcast sessions & temporary session directories
    /// - Completed stitch history ("最近保存")
    public func calculateCacheBreakdown() -> CacheBreakdown {
        var tempBytes: Int64 = 0
        var recentBytes: Int64 = 0
        
        // 1. System Temporary Directory (imported videos, full canvas render exports)
        tempBytes += directorySize(at: fileManager.temporaryDirectory)
        
        // 2. System Caches Directory
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            tempBytes += directorySize(at: cachesURL)
        }
        
        // 3. App Group / App Data: active_session & sessions
        let container = AppGroupConstants.containerURL
        let activeSessionDir = container.appendingPathComponent("active_session", isDirectory: true)
        tempBytes += directorySize(at: activeSessionDir)
        
        let sessionsDir = container.appendingPathComponent("sessions", isDirectory: true)
        tempBytes += directorySize(at: sessionsDir)
        
        // 4. App Group: completed_stitches (Recent Saves history)
        let completeDir = container.appendingPathComponent("completed_stitches", isDirectory: true)
        recentBytes += directorySize(at: completeDir)
        
        return CacheBreakdown(temporaryCacheBytes: tempBytes, recentSavesBytes: recentBytes)
    }
    
    // MARK: - Cache Pruning & Cleanup
    
    /// Cleans all temporary working files:
    /// - Temporary videos (imported .mov files from photos picker or file transfer)
    /// - Intermediate rendered JPG/PNG files in tmp/
    /// - System caches directory
    /// - App Group active_session and sessions slice folders
    ///
    /// Preserves "最近保存" (completed_stitches) history.
    public func clearTemporaryCache() {
        // 1. Clean temporaryDirectory
        let tempDir = fileManager.temporaryDirectory
        if let files = try? fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
        
        // 2. Clean cachesDirectory
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
           let files = try? fileManager.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
        
        // 3. Clean active_session & sessions in App Group
        let container = AppGroupConstants.containerURL
        let activeSessionDir = container.appendingPathComponent("active_session", isDirectory: true)
        try? fileManager.removeItem(at: activeSessionDir)
        try? fileManager.createDirectory(at: activeSessionDir, withIntermediateDirectories: true)
        
        let sessionsDir = container.appendingPathComponent("sessions", isDirectory: true)
        try? fileManager.removeItem(at: sessionsDir)
        try? fileManager.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
    }
    
    /// Cleans recent saved stitches history ("最近保存")
    public func clearRecentSaves() {
        let completeDir = AppGroupConstants.completedStitchesDirectory
        if let files = try? fileManager.contentsOfDirectory(at: completeDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    /// Wipes all application cache and recent save history
    public func clearAllCache() {
        clearTemporaryCache()
        clearRecentSaves()
    }
    
    /// Removes a specific session's slice directory when editor finishes or is dismissed
    public func cleanupSession(sessionId: UUID) {
        let container = AppGroupConstants.containerURL
        let targetDir = container.appendingPathComponent("sessions/\(sessionId.uuidString)", isDirectory: true)
        try? fileManager.removeItem(at: targetDir)
    }
    
    /// Prunes stale temporary files on application startup (e.g. from previous force quits or crashes)
    /// Only deletes files modified more than 10 minutes ago to avoid interfering with ongoing operations.
    public func cleanupStaleCacheOnStartup(minAgeSeconds: TimeInterval = 600) {
        let now = Date()
        let tempDir = fileManager.temporaryDirectory
        if let files = try? fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for file in files {
                if let vals = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modDate = vals.contentModificationDate,
                   now.timeIntervalSince(modDate) > minAgeSeconds {
                    try? fileManager.removeItem(at: file)
                }
            }
        }
        
        let container = AppGroupConstants.containerURL
        let sessionsDir = container.appendingPathComponent("sessions", isDirectory: true)
        if let subdirs = try? fileManager.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for dir in subdirs {
                if let vals = try? dir.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modDate = vals.contentModificationDate,
                   now.timeIntervalSince(modDate) > minAgeSeconds {
                    try? fileManager.removeItem(at: dir)
                }
            }
        }
    }
    
    // MARK: - Directory Size Calculation
    
    /// Recursively counts all regular files under a directory and sums their byte sizes
    public func directorySize(at url: URL) -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else { return 0 }
        var total: Int64 = 0
        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) {
            for case let fileURL as URL in enumerator {
                if let resource = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                   resource.isRegularFile == true,
                   let size = resource.fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }
}
