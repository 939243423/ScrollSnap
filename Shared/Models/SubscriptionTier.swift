import Foundation

public enum SubscriptionTier: String, CaseIterable, Identifiable {
    case freeTier
    case proVip
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .freeTier:
            return "Standard"
        case .proVip:
            return "Pro VIP"
        }
    }
    
    public var maxSlicesAllowed: Int {
        switch self {
        case .freeTier:
            return 8
        case .proVip:
            return Int.max
        }
    }
    
    public var allowsLosslessRetinaExport: Bool {
        switch self {
        case .freeTier:
            return false
        case .proVip:
            return true
        }
    }
    
    public var allowsDeviceFrameMockups: Bool {
        switch self {
        case .freeTier:
            return false
        case .proVip:
            return true
        }
    }
    
    public var allowsSmartPrivacyAutoBlur: Bool {
        switch self {
        case .freeTier:
            return false
        case .proVip:
            return true
        }
    }
}
