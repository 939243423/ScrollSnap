import Foundation

public enum AppGroupConstants {
    public static let suiteName = "group.com.scrollsnap"
    
    public static let notificationSessionUpdated = "com.scrollsnap.broadcast.sessionUpdated"
    public static let notificationSessionCompleted = "com.scrollsnap.broadcast.sessionCompleted"
    
    public static var containerURL: URL? {
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            return appGroupURL
        }
        // Graceful fallback for local debug, unit testing, and SwiftUI Previews
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("AppGroup_ScrollSnap", isDirectory: true)
    }
    
    public static var activeSessionDirectory: URL? {
        containerURL?.appendingPathComponent("active_session", isDirectory: true)
    }
    
    public static var completedStitchesDirectory: URL? {
        containerURL?.appendingPathComponent("completed_stitches", isDirectory: true)
    }
}
