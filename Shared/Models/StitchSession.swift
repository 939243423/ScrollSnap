import Foundation
import CoreGraphics

public enum StitchCaptureSource: String, Codable {
    case photoLibrary
    case replayKitBroadcast
    case webViewFullPage
}

public struct StitchSession: Codable, Identifiable {
    public var id: UUID
    public var createdAt: Date
    public var source: StitchCaptureSource
    public var slices: [StitchItem]
    public var title: String
    public var deviceScreenWidth: CGFloat
    public var deviceScreenScale: CGFloat
    public var hasAppliedDeviceFrame: Bool
    
    public var totalEstimatedHeight: CGFloat {
        guard let first = slices.first else { return 0 }
        var height = first.originalHeight
        for slice in slices.dropFirst() {
            height += (slice.originalHeight - slice.effectiveOverlap)
        }
        return height
    }
    
    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        source: StitchCaptureSource = .photoLibrary,
        slices: [StitchItem] = [],
        title: String = "Stitched Screenshot",
        deviceScreenWidth: CGFloat = 393,
        deviceScreenScale: CGFloat = 3.0,
        hasAppliedDeviceFrame: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.slices = slices
        self.title = title
        self.deviceScreenWidth = deviceScreenWidth
        self.deviceScreenScale = deviceScreenScale
        self.hasAppliedDeviceFrame = hasAppliedDeviceFrame
    }
}
