import Foundation
import CoreGraphics

public enum RedactionBrushType: String, Codable, CaseIterable, Identifiable, Sendable {
    case frostedGlass = "极光毛玻璃"
    case pixelateMosaic = "像素马赛克"
    case confidentialInk = "机密墨水笔"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .frostedGlass: return "drop.fill"
        case .pixelateMosaic: return "checkerboard.rectangle"
        case .confidentialInk: return "paintbrush.pointed.fill"
        }
    }
}

public struct RedactionStroke: Codable, Identifiable, Sendable {
    public var id: UUID
    public var points: [CGPoint]
    public var brushType: RedactionBrushType
    public var lineWidth: CGFloat
    
    public init(
        id: UUID = UUID(),
        points: [CGPoint] = [],
        brushType: RedactionBrushType = .frostedGlass,
        lineWidth: CGFloat = 24.0
    ) {
        self.id = id
        self.points = points
        self.brushType = brushType
        self.lineWidth = lineWidth
    }
}
