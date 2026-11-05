import Foundation
import CoreGraphics

public enum CanvasInteractionMode: String, CaseIterable, Identifiable, Sendable {
    case draw = "绘制"
    case browse = "浏览与调整"
    
    public var id: String { rawValue }
}

public enum RedactionShapeMode: String, CaseIterable, Identifiable, Sendable {
    case box = "框选"
    case brush = "涂抹"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .box: return "square.dashed"
        case .brush: return "paintbrush.pointed"
        }
    }
}

public enum RedactionBrushType: String, Codable, CaseIterable, Identifiable, Sendable {
    case frostedGlass = "模糊"
    case pixelateMosaic = "马赛克"
    case confidentialInk = "涂黑"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .frostedGlass: return "drop.fill"
        case .pixelateMosaic: return "square.grid.2x2"
        case .confidentialInk: return "pencil.tip"
        }
    }
}

public enum RedactionStyleChoice: String, CaseIterable, Identifiable, Sendable {
    case mosaic = "马赛克"
    case blur = "模糊"
    case blackout = "涂黑"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .mosaic: return "square.grid.2x2"
        case .blur: return "drop.fill"
        case .blackout: return "pencil.tip"
        }
    }
    
    public var regionStyle: RedactionRegion.RedactionStyle {
        switch self {
        case .mosaic: return .pixelatedMosaic
        case .blur: return .frostedBlur
        case .blackout: return .blackout
        }
    }
    
    public var brushType: RedactionBrushType {
        switch self {
        case .mosaic: return .pixelateMosaic
        case .blur: return .frostedGlass
        case .blackout: return .confidentialInk
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

