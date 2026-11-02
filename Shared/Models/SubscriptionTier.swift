import Foundation

public enum SubscriptionTier: String, CaseIterable, Identifiable {
    case freeTier
    case lifetimePro
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .freeTier:
            return "免费体验"
        case .lifetimePro:
            return "永久会员"
        }
    }
    
    public var priceDisplayText: String {
        switch self {
        case .freeTier:
            return "每天免费 2 次"
        case .lifetimePro:
            return "¥1.00 永久买断"
        }
    }
    
    public var dailyFreeLimit: Int {
        switch self {
        case .freeTier:
            return 2
        case .lifetimePro:
            return Int.max
        }
    }
    
    public var allowsFullAnnotationSuite: Bool {
        switch self {
        case .freeTier:
            return true // Basic annotations free
        case .lifetimePro:
            return true
        }
    }
    
    public var allowsSocialNineGridSlicing: Bool {
        switch self {
        case .freeTier:
            return true
        case .lifetimePro:
            return true
        }
    }
    
    public var allowsPDFAndLosslessExport: Bool {
        switch self {
        case .freeTier:
            return false // Premium export requires ¥1 lifetime unlock
        case .lifetimePro:
            return true
        }
    }
}
