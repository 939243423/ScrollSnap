import Foundation

public enum AppGroupConstants {
    public static let suiteName = "group.com.scrollsnap"
    
    public static let notificationSessionUpdated = "com.scrollsnap.broadcast.sessionUpdated"
    public static let notificationSessionCompleted = "com.scrollsnap.broadcast.sessionCompleted"
    
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }
    
    public static var activeSessionDirectory: URL? {
        containerURL?.appendingPathComponent("active_session", isDirectory: true)
    }
    
    public static var completedStitchesDirectory: URL? {
        containerURL?.appendingPathComponent("completed_stitches", isDirectory: true)
    }
}
