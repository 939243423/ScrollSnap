import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Viral growth engine: Minimalist, Apple-styled export watermark footer.
/// Free users have this subtle, high-end signature appended to exported stitches,
/// driving organic word-of-mouth discovery on social platforms (Xiaohongshu, Weibo, WeChat).
/// Pro lifetime users can toggle this off in Settings.
public final class ExportWatermarkManager {
    public static let shared = ExportWatermarkManager()
    
    private let keyIsWatermarkEnabled = "ScrollSnap_Export_IsWatermarkEnabled"
    
    public var isWatermarkEnabled: Bool {
        get {
            // Default to true if not set
            if UserDefaults.standard.object(forKey: keyIsWatermarkEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: keyIsWatermarkEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: keyIsWatermarkEnabled)
        }
    }
    
    private init() {}
    
    #if canImport(UIKit)
    /// Appends an ultra-refined, minimalist watermark footer to a stitched image.
    /// If watermark is disabled or user is Pro and opted out, returns original image.
    public func appendWatermarkIfNeeded(to image: UIImage, isProUser: Bool) -> UIImage {
        // If Pro user has turned it off, return original image intact
        if isProUser && !isWatermarkEnabled {
            return image
        }
        
        let footerHeight: CGFloat = 54.0
        let originalWidth = image.size.width
        let originalHeight = image.size.height
        let targetSize = CGSize(width: originalWidth, height: originalHeight + footerHeight)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, true, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return image
        }
        
        // 1. Draw base image
        image.draw(in: CGRect(origin: .zero, size: image.size))
        
        // 2. Draw minimalist footer background (matches dark or light background subtly)
        let footerRect = CGRect(x: 0, y: originalHeight, width: originalWidth, height: footerHeight)
        context.setFillColor(UIColor.systemBackground.cgColor)
        context.fill(footerRect)
        
        // 3. Hairline top border
        let hairlineRect = CGRect(x: 24, y: originalHeight, width: originalWidth - 48, height: 0.5)
        context.setFillColor(UIColor.separator.cgColor)
        context.fill(hairlineRect)
        
        // 4. Subtle typography: "Captured with ScrollSnap · 滚动画布"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraphStyle
        ]
        
        let watermarkText = "Captured with ScrollSnap · 滚动画布"
        let textRect = CGRect(x: 0, y: originalHeight + 18, width: originalWidth, height: 20)
        (watermarkText as NSString).draw(in: textRect, withAttributes: attributes)
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return finalImage
    }
    #endif
}
