import Foundation
import CoreGraphics

public struct RedactionRegion: Codable, Identifiable, Hashable {
    public var id: UUID
    public var relativeRect: CGRect // Normalized 0.0 - 1.0 within slice coordinates
    public var style: RedactionStyle
    
    public enum RedactionStyle: String, Codable {
        case pixelatedMosaic
        case blackout
        case frostedBlur
    }
    
    public init(id: UUID = UUID(), relativeRect: CGRect, style: RedactionStyle = .pixelatedMosaic) {
        self.id = id
        self.relativeRect = relativeRect
        self.style = style
    }
}

public struct StitchItem: Codable, Identifiable, Hashable {
    public var id: UUID
    public var relativeFilePath: String // Relative to AppGroup container
    public var originalWidth: CGFloat
    public var originalHeight: CGFloat
    public var calculatedOverlapWithPrevious: CGFloat // Overlap offset in points
    public var manualOffsetAdjustment: CGFloat // User fine-tuning delta
    public var optimalSeamLineY: CGFloat // Seam cutline relative to slice top
    public var redactions: [RedactionRegion]
    public var timestamp: Date
    
    public var effectiveOverlap: CGFloat {
        max(0, calculatedOverlapWithPrevious + manualOffsetAdjustment)
    }
    
    public init(
        id: UUID = UUID(),
        relativeFilePath: String,
        originalWidth: CGFloat,
        originalHeight: CGFloat,
        calculatedOverlapWithPrevious: CGFloat = 0,
        manualOffsetAdjustment: CGFloat = 0,
        optimalSeamLineY: CGFloat = 0,
        redactions: [RedactionRegion] = [],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.relativeFilePath = relativeFilePath
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
        self.calculatedOverlapWithPrevious = calculatedOverlapWithPrevious
        self.manualOffsetAdjustment = manualOffsetAdjustment
        self.optimalSeamLineY = optimalSeamLineY
        self.redactions = redactions
        self.timestamp = timestamp
    }
}
