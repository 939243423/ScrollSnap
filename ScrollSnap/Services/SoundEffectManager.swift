import Foundation
#if canImport(AudioToolbox)
import AudioToolbox
#endif

/// Tactile acoustic feedback manager.
/// Pairs subtle system acoustic clicks with tactile haptics for a luxury mechanical watch feel.
public final class SoundEffectManager {
    public static let shared = SoundEffectManager()
    
    private let keyIsSoundEnabled = "ScrollSnap_Settings_IsSoundEnabled"
    
    public var isSoundEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: keyIsSoundEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: keyIsSoundEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: keyIsSoundEnabled)
        }
    }
    
    private init() {}
    
    /// Plays subtle mechanical ratchet tick (Sound ID 1104)
    public func playRatchetTick() {
        guard isSoundEnabled else { return }
        #if canImport(AudioToolbox)
        AudioServicesPlaySystemSound(1104)
        #endif
    }
    
    /// Plays crisp magnetic snap detent (Sound ID 1057)
    public func playMagneticSnap() {
        guard isSoundEnabled else { return }
        #if canImport(AudioToolbox)
        AudioServicesPlaySystemSound(1057)
        #endif
    }
    
    /// Plays camera shutter sound on successful photo save (Sound ID 1108)
    public func playShutter() {
        guard isSoundEnabled else { return }
        #if canImport(AudioToolbox)
        AudioServicesPlaySystemSound(1108)
        #endif
    }
    
    /// Plays celebratory success chime on stitch completion (Sound ID 1025)
    public func playCelebrationChime() {
        guard isSoundEnabled else { return }
        #if canImport(AudioToolbox)
        AudioServicesPlaySystemSound(1025)
        #endif
    }
}
