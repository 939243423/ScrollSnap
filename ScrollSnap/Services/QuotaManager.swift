import Foundation
import Combine

@MainActor
public final class QuotaManager: ObservableObject {
    public static let shared = QuotaManager()
    
    private let keyUsageDate = "ScrollSnap_UsageDate"
    private let keyDailyStitchCount = "ScrollSnap_DailyStitchCount"
    public static let defaultDailyLimit = 2
    
    @Published public private(set) var dailyStitchesUsed: Int = 0
    @Published public private(set) var remainingDailyFreeStitches: Int = defaultDailyLimit
    
    private init() {
        refreshQuota()
    }
    
    public var isQuotaExhausted: Bool {
        if StoreKitManager.shared.isProUser {
            return false
        }
        return remainingDailyFreeStitches <= 0
    }
    
    public func refreshQuota() {
        let defaults = UserDefaults.standard
        let todayString = currentDateString()
        let lastRecordedDate = defaults.string(forKey: keyUsageDate) ?? ""
        
        if lastRecordedDate != todayString {
            // New calendar day: reset quota to full
            defaults.set(todayString, forKey: keyUsageDate)
            defaults.set(0, forKey: keyDailyStitchCount)
            self.dailyStitchesUsed = 0
            self.remainingDailyFreeStitches = Self.defaultDailyLimit
        } else {
            let used = defaults.integer(forKey: keyDailyStitchCount)
            self.dailyStitchesUsed = used
            self.remainingDailyFreeStitches = max(0, Self.defaultDailyLimit - used)
        }
    }
    
    public func canStitch() -> Bool {
        if StoreKitManager.shared.isProUser {
            return true
        }
        refreshQuota()
        return remainingDailyFreeStitches > 0
    }
    
    public func recordStitchUsage() {
        guard !StoreKitManager.shared.isProUser else { return }
        
        refreshQuota()
        let defaults = UserDefaults.standard
        let newCount = dailyStitchesUsed + 1
        defaults.set(newCount, forKey: keyDailyStitchCount)
        
        self.dailyStitchesUsed = newCount
        self.remainingDailyFreeStitches = max(0, Self.defaultDailyLimit - newCount)
    }
    
    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
}
