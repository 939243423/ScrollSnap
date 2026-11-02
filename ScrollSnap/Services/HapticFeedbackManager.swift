import Foundation
#if canImport(UIKit)
import UIKit
#endif

public final class HapticFeedbackManager {
    public static let shared = HapticFeedbackManager()
    
    #if canImport(UIKit)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private var lastHapticTimestamp: TimeInterval = 0
    private let debounceThreshold: TimeInterval = 0.07 // 70ms hardware debounce threshold
    #endif
    
    private init() {
        #if canImport(UIKit)
        impactLight.prepare()
        impactMedium.prepare()
        notificationGenerator.prepare()
        #endif
    }
    
    public func triggerSelection() {
        #if canImport(UIKit)
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastHapticTimestamp >= debounceThreshold else { return }
        lastHapticTimestamp = now
        impactLight.impactOccurred()
        #endif
    }
    
    public func triggerSnap() {
        #if canImport(UIKit)
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastHapticTimestamp >= debounceThreshold else { return }
        lastHapticTimestamp = now
        impactMedium.impactOccurred()
        #endif
    }
    
    public func triggerSuccess() {
        #if canImport(UIKit)
        notificationGenerator.notificationOccurred(.success)
        #endif
    }
    
    public func triggerWarning() {
        #if canImport(UIKit)
        notificationGenerator.notificationOccurred(.warning)
        #endif
    }
}
