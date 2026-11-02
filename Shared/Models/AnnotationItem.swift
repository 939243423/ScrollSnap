import Foundation
import CoreGraphics
import SwiftUI

public enum AnnotationColor: String, CaseIterable, Codable, Sendable {
    case crimsonRed = "#FF3B30"
    case electricOrange = "#FF9500"
    case neonYellow = "#FFCC00"
    case mintGreen = "#34C759"
    case deepIndigo = "#5856D6"
    case midnightBlack = "#000000"
    case pureWhite = "#FFFFFF"
    
    public var swiftUIColor: Color {
        switch self {
        case .crimsonRed: return Color(red: 1.0, green: 0.23, blue: 0.19)
        case .electricOrange: return Color(red: 1.0, green: 0.58, blue: 0.0)
        case .neonYellow: return Color(red: 1.0, green: 0.8, blue: 0.0)
        case .mintGreen: return Color(red: 0.2, green: 0.78, blue: 0.35)
        case .deepIndigo: return Color(red: 0.35, green: 0.34, blue: 0.84)
        case .midnightBlack: return Color.black
        case .pureWhite: return Color.white
        }
    }
}

public enum AnnotationKind: String, Codable, Sendable {
    case rectangle
    case arrow
    case stepBadge
    case highlighter
    case textNote
    case mosaic
}

public struct AnnotationItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public var kind: AnnotationKind
    public var color: AnnotationColor
    public var lineWidth: CGFloat
    
    // Geometric coordinates normalized to (0...1) relative to canvas size
    public var startPoint: CGPoint
    public var endPoint: CGPoint
    public var freehandPoints: [CGPoint]
    public var stepNumber: Int
    public var textContent: String
    public var isBlackout: Bool
    
    public init(
        id: UUID = UUID(),
        kind: AnnotationKind,
        color: AnnotationColor = .crimsonRed,
        lineWidth: CGFloat = 3.0,
        startPoint: CGPoint = .zero,
        endPoint: CGPoint = .zero,
        freehandPoints: [CGPoint] = [],
        stepNumber: Int = 1,
        textContent: String = "",
        isBlackout: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.color = color
        self.lineWidth = lineWidth
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.freehandPoints = freehandPoints
        self.stepNumber = stepNumber
        self.textContent = textContent
        self.isBlackout = isBlackout
    }
    
    public var boundingBox: CGRect {
        let minX = min(startPoint.x, endPoint.x)
        let minY = min(startPoint.y, endPoint.y)
        let width = abs(endPoint.x - startPoint.x)
        let height = abs(endPoint.y - startPoint.y)
        return CGRect(x: minX, y: minY, width: max(0.01, width), height: max(0.01, height))
    }
}
