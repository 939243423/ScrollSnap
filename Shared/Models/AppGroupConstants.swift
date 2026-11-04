import Foundation

public enum AppGroupConstants {
    public static let primarySuiteName = "group.com.ruohui.scrollsnap"
    public static let fallbackSuiteName = "group.com.scrollsnap"
    public static let suiteName = primarySuiteName
    
    public static let notificationSessionUpdated = "com.scrollsnap.broadcast.sessionUpdated"
    public static let notificationSessionCompleted = "com.scrollsnap.broadcast.sessionCompleted"
    
    public static var containerURL: URL {
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: primarySuiteName) {
            return appGroupURL
        }
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: fallbackSuiteName) {
            return appGroupURL
        }
        // Persistent Document directory fallback (guaranteed to exist, never purged by iOS cache manager)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let appGroupDir = docs.appendingPathComponent("ScrollSnapData", isDirectory: true)
        try? FileManager.default.createDirectory(at: appGroupDir, withIntermediateDirectories: true)
        return appGroupDir
    }
    
    public static var activeSessionDirectory: URL {
        let dir = containerURL.appendingPathComponent("active_session", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public static var completedStitchesDirectory: URL {
        let dir = containerURL.appendingPathComponent("completed_stitches", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
