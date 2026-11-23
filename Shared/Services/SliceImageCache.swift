import Foundation
#if canImport(UIKit)
import UIKit
import ImageIO
#endif

/// Thread-safe in-memory cache for slice images and downsampled thumbnails.
/// Prevents heavy disk I/O lag (up to 1,800 reads/sec) during interactive seam tuning
/// and avoids multi-hundred-megabyte RAM spikes when browsing slices in list sheets.
public final class SliceImageCache: @unchecked Sendable {
    public static let shared = SliceImageCache()
    
    #if canImport(UIKit)
    private let fullImageCache = NSCache<NSString, UIImage>()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    #endif
    
    private init() {
        #if canImport(UIKit)
        fullImageCache.countLimit = 40
        fullImageCache.totalCostLimit = 160 * 1024 * 1024 // 160 MB limit
        
        thumbnailCache.countLimit = 120
        thumbnailCache.totalCostLimit = 24 * 1024 * 1024 // 24 MB limit
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.removeAll()
        }
        #endif
    }
    
    #if canImport(UIKit)
    /// Fetches full resolution slice image from cache, or reads from disk once and caches
    public func image(for relativePath: String) -> UIImage? {
        let key = relativePath as NSString
        if let cached = fullImageCache.object(forKey: key) {
            return cached
        }
        guard let url = SharedStore.shared.resolveFileURL(relativePath: relativePath),
              let img = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        let cost = Int(img.size.width * img.size.height * 4)
        fullImageCache.setObject(img, forKey: key, cost: cost)
        return img
    }
    
    /// Returns a memory-efficient downsampled thumbnail using ImageIO
    /// Bypasses full bitmap decoding in memory (decodes only at specified thumbnail dimension)
    public func thumbnail(for relativePath: String, maxPixelSize: CGFloat = 200) -> UIImage? {
        let key = "\(relativePath)_\(Int(maxPixelSize))" as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        guard let url = SharedStore.shared.resolveFileURL(relativePath: relativePath) as CFURL? else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        
        guard let imageSource = CGImageSourceCreateWithURL(url, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        let thumb = UIImage(cgImage: cgImage)
        let cost = Int(thumb.size.width * thumb.size.height * 4)
        thumbnailCache.setObject(thumb, forKey: key, cost: cost)
        return thumb
    }
    
    /// Clears both caches to free up memory immediately (e.g. on editor dismiss or memory warning)
    public func removeAll() {
        fullImageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
    }
    #endif
}
