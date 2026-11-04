import Foundation
import CoreGraphics

public enum RedactionBrushType: String, Codable, CaseIterable, Identifiable, Sendable {
    case frostedGlass = "毛玻璃"
    case pixelateMosaic = "马赛克"
    case confidentialInk = "涂抹笔"
    
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
