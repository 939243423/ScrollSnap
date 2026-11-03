import Foundation
#if canImport(StoreKit)
import StoreKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Smart rating and user sentiment growth engine.
/// Strictly adheres to Apple App Store Review Guidelines (Guideline 5.6.1).
/// Only prompts at peak "Aha!" moments of delight (e.g. after flawless stitch exports)
/// and respects cooldown thresholds to never interrupt or annoy users.
@MainActor
public final class StoreReviewManager: ObservableObject {
    public static let shared = StoreReviewManager()
    
    // UserDefaults Keys
    private let keySuccessfulStitchCount = "ScrollSnap_Review_SuccessfulStitchCount"
    private let keyLastPromptDate = "ScrollSnap_Review_LastPromptDate"
    private let keyLastPromptVersion = "ScrollSnap_Review_LastPromptVersion"
    private let keyHasRated = "ScrollSnap_Review_HasRated"
    
    // App Store Configuration
    public static let appStoreAppId = "6499887700"
    public static let developerEmail = "ruohui49@gmail.com"
    
    // Thresholds
    private let minimumStitchesBeforePrompt = 2
    private let promptMilestones: Set<Int> = [2, 6, 15, 30]
    private let cooldownDays: Double = 45.0
    
    @Published public private(set) var successfulStitchCount: Int = 0
    @Published public var isShowingGentleFeedbackDialog: Bool = false
    
    private init() {
        self.successfulStitchCount = UserDefaults.standard.integer(forKey: keySuccessfulStitchCount)
    }
    
    /// Records a flawless stitch export or save action.
    public func recordSuccessfulExport() {
        successfulStitchCount += 1
        UserDefaults.standard.set(successfulStitchCount, forKey: keySuccessfulStitchCount)
        
        if shouldRequestReview() {
            triggerReviewPrompt()
        }
    }
    
    /// Determines whether the user has reached an appropriate milestone for review.
    public func shouldRequestReview() -> Bool {
        let defaults = UserDefaults.standard
        
        // 1. Must not have already rated
        if defaults.bool(forKey: keyHasRated) {
            return false
        }
        
        // 2. Must meet milestone count
        guard promptMilestones.contains(successfulStitchCount) ||
              (successfulStitchCount > minimumStitchesBeforePrompt && successfulStitchCount % 10 == 0) else {
            return false
        }
        
        // 3. Must not have prompted in current app version
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let lastVersion = defaults.string(forKey: keyLastPromptVersion)
        if lastVersion == currentVersion {
            return false
        }
        
        // 4. Must satisfy minimum cooldown interval
        if let lastDate = defaults.object(forKey: keyLastPromptDate) as? Date {
            let elapsedDays = Date().timeIntervalSince(lastDate) / (60 * 60 * 24)
            if elapsedDays < cooldownDays {
                return false
            }
        }
        
        return true
    }
    
    /// Triggers the native StoreKit review prompt safely.
    public func triggerReviewPrompt() {
        let defaults = UserDefaults.standard
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        defaults.set(Date(), forKey: keyLastPromptDate)
        defaults.set(currentVersion, forKey: keyLastPromptVersion)
        
        #if canImport(UIKit)
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
        #endif
    }
    
    /// Opens the App Store product review page directly.
    public func openAppStoreReviewPage() {
        UserDefaults.standard.set(true, forKey: keyHasRated)
        
        #if canImport(UIKit)
        let reviewURLString = "itms-apps://itunes.apple.com/app/id\(Self.appStoreAppId)?action=write-review"
        if let url = URL(string: reviewURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else if let webURL = URL(string: "https://apps.apple.com/app/id\(Self.appStoreAppId)?action=write-review") {
            UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
        }
        #endif
    }
    
    /// Generates pre-populated email feedback link for constructive issue reporting.
    public func sendFeedbackEmail() {
        #if canImport(UIKit)
        let systemVersion = UIDevice.current.systemVersion
        let model = UIDevice.current.model
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        
        let subject = "ScrollSnap 建议与问题反馈 (v\(appVersion))"
        let body = """
        
        
        -----------------------------------
        请在此行上方输入您的宝贵建议或遇到的问题。
        应用版本: \(appVersion) (\(buildNumber))
        系统版本: iOS \(systemVersion)
        设备机型: \(model)
        拼接引擎: CoreGraphics NCC + Metal
        -----------------------------------
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let mailtoURLString = "mailto:\(Self.developerEmail)?subject=\(encodedSubject)&body=\(encodedBody)"
        if let url = URL(string: mailtoURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #endif
    }
}
