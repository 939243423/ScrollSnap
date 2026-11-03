import Foundation
import Photos
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class PhotoLibraryObserver: NSObject, ObservableObject {
    public static let shared = PhotoLibraryObserver()
    
    @Published public private(set) var recentScreenshotAssets: [PHAsset] = []
    @Published public private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    private var isObserverRegistered = false
    
    private override init() {
        super.init()
        checkAuthorization()
    }
    
    deinit {
        if isObserverRegistered {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }
    
    public func checkAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        self.authorizationStatus = status
        if status == .authorized || status == .limited {
            registerObserverIfNeeded()
            scanRecentScreenshots()
        }
    }
    
    public func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.authorizationStatus = status
        if status == .authorized || status == .limited {
            registerObserverIfNeeded()
            scanRecentScreenshots()
        }
    }
    
    private func registerObserverIfNeeded() {
        guard !isObserverRegistered else { return }
        PHPhotoLibrary.shared().register(self)
        isObserverRegistered = true
    }
    
    public func scanRecentScreenshots(windowMinutes: Double = 5.0) {
        let fetchOptions = PHFetchOptions()
        let cutoffDate = Date().addingTimeInterval(-windowMinutes * 60)
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@ AND (mediaSubtypes & %d) != 0",
            PHAssetMediaType.image.rawValue,
            cutoffDate as NSDate,
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let results = PHAsset.fetchAssets(with: fetchOptions)
        var detected: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in
            detected.append(asset)
        }
        self.recentScreenshotAssets = detected
    }
}

extension PhotoLibraryObserver: PHPhotoLibraryChangeObserver {
    public nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            self.scanRecentScreenshots()
        }
    }
}
