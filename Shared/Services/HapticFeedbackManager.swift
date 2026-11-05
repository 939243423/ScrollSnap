import Foundation
#if canImport(UIKit)
import UIKit
#endif

public final class HapticFeedbackManager {
    public static let shared = HapticFeedbackManager()
    
    #if canImport(UIKit)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private var lastHapticTimestamp: TimeInterval = 0
    private let debounceThreshold: TimeInterval = 0.04 // 40ms responsive debounce threshold
    #endif
    
    private init() {
        #if canImport(UIKit)
        impactLight.prepare()
        impactMedium.prepare()
        impactRigid.prepare()
        impactHeavy.prepare()
        selectionGenerator.prepare()
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
    
    public func triggerDialDetent() {
        #if canImport(UIKit)
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastHapticTimestamp >= 0.025 else { return }
        lastHapticTimestamp = now
        selectionGenerator.selectionChanged()
        #endif
    }
    
    public func triggerMagneticLock() {
        #if canImport(UIKit)
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastHapticTimestamp >= debounceThreshold else { return }
        lastHapticTimestamp = now
        impactRigid.impactOccurred(intensity: 1.0)
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
