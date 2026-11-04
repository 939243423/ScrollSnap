import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum DeviceFrameFinish: String, CaseIterable, Identifiable, Codable {
    case desertTitanium = "沙漠钛金属"
    case naturalTitanium = "原色钛金属"
    case spaceBlack = "深空黑钛"
    case silverWhite = "银白钛金属"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .desertTitanium: return "沙漠钛"
        case .naturalTitanium: return "原色钛"
        case .spaceBlack: return "深空黑"
        case .silverWhite: return "银白色"
        }
    }
    
    public var bezelGradient: [Color] {
        switch self {
        case .desertTitanium:
            return [
                Color(red: 0.78, green: 0.68, blue: 0.58),
                Color(red: 0.56, green: 0.46, blue: 0.38),
                Color(red: 0.84, green: 0.74, blue: 0.65)
            ]
        case .naturalTitanium:
            return [
                Color(red: 0.58, green: 0.56, blue: 0.52),
                Color(red: 0.40, green: 0.38, blue: 0.35),
                Color(red: 0.65, green: 0.63, blue: 0.60)
            ]
        case .spaceBlack:
            return [
                Color(red: 0.18, green: 0.18, blue: 0.19),
                Color(red: 0.08, green: 0.08, blue: 0.09),
                Color(red: 0.22, green: 0.22, blue: 0.24)
            ]
        case .silverWhite:
            return [
                Color(red: 0.90, green: 0.90, blue: 0.92),
                Color(red: 0.72, green: 0.72, blue: 0.75),
                Color(red: 0.95, green: 0.95, blue: 0.98)
            ]
        }
    }
    
    #if canImport(UIKit)
    public var uiColors: [UIColor] {
        switch self {
        case .desertTitanium:
            return [
                UIColor(red: 0.78, green: 0.68, blue: 0.58, alpha: 1.0),
                UIColor(red: 0.56, green: 0.46, blue: 0.38, alpha: 1.0),
                UIColor(red: 0.84, green: 0.74, blue: 0.65, alpha: 1.0)
            ]
        case .naturalTitanium:
            return [
                UIColor(red: 0.58, green: 0.56, blue: 0.52, alpha: 1.0),
                UIColor(red: 0.40, green: 0.38, blue: 0.35, alpha: 1.0),
                UIColor(red: 0.65, green: 0.63, blue: 0.60, alpha: 1.0)
            ]
        case .spaceBlack:
            return [
                UIColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1.0),
                UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0),
                UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1.0)
            ]
        case .silverWhite:
            return [
                UIColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1.0),
                UIColor(red: 0.72, green: 0.72, blue: 0.75, alpha: 1.0),
                UIColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
            ]
        }
    }
    #endif
}

public enum CanvasBackgroundStyle: String, CaseIterable, Identifiable, Codable {
    case transparent = "透明无底"
    case adaptiveBlur = "自适应磨砂玻璃"
    case appleGradient = "晨曦蓝紫"
    case studioDark = "极夜深灰"
    case cleanWhite = "极简冷白"
    
    public var id: String { rawValue }
}
