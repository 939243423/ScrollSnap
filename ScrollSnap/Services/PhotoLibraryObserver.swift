import Foundation
import Photos
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class PhotoLibraryObserver: NSObject, ObservableObject {
    public static let shared = PhotoLibraryObserver()
    
    @Published public private(set) var recentScreenshotAssets: [PHAsset] = []
    @Published public private(set) var recentScreenRecordingAsset: PHAsset?
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
        } else if status == .notDetermined {
            Task {
                await requestAuthorization()
            }
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
    
    public func scanRecentScreenshots(windowMinutes: Double = 60.0) {
        let cutoffDate = Date().addingTimeInterval(-windowMinutes * 60)
        
        // 1. Scan image screenshots (within past hour)
        let imageOptions = PHFetchOptions()
        imageOptions.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@ AND (mediaSubtypes & %d) != 0",
            PHAssetMediaType.image.rawValue,
            cutoffDate as NSDate,
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        imageOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let results = PHAsset.fetchAssets(with: imageOptions)
        var detected: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in
            detected.append(asset)
        }
        self.recentScreenshotAssets = detected
        
        // 2. Scan recent short screen recording video (duration between 1s and 180s within past hour)
        let videoOptions = PHFetchOptions()
        videoOptions.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@ AND duration >= 1.0 AND duration <= 180.0",
            PHAssetMediaType.video.rawValue,
            cutoffDate as NSDate
        )
        videoOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        videoOptions.fetchLimit = 1
        
        let videoResults = PHAsset.fetchAssets(with: videoOptions)
        self.recentScreenRecordingAsset = videoResults.firstObject
    }
}

extension PhotoLibraryObserver: PHPhotoLibraryChangeObserver {
    public nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            self.scanRecentScreenshots()
        }
    }
}
