import Foundation
import ActivityKit

public struct StitchActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var frameCount: Int
        public var capturedHeightPx: Int
        public var statusText: String
        public var isProcessing: Bool
        public var elapsedSeconds: Int
        
        public init(
            frameCount: Int,
            capturedHeightPx: Int,
            statusText: String,
            isProcessing: Bool,
            elapsedSeconds: Int
        ) {
            self.frameCount = frameCount
            self.capturedHeightPx = capturedHeightPx
            self.statusText = statusText
            self.isProcessing = isProcessing
            self.elapsedSeconds = elapsedSeconds
        }
    }
    
    public var sessionId: UUID
    public var captureTitle: String
    public var startTime: Date
    
    public init(sessionId: UUID, captureTitle: String, startTime: Date = Date()) {
        self.sessionId = sessionId
        self.captureTitle = captureTitle
        self.startTime = startTime
    }
}
