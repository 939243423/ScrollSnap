import SwiftUI

@main
struct ScrollSnapApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var storeKit = StoreKitManager.shared
    @State private var sessionToken: DarwinNotificationToken?
    
    init() {
        // Concurrency safety: Zero synchronous calls between singletons
    }
    
    var body: some Scene {
        WindowGroup {
            HomeStitchView()
                .tint(ScrollSnapTheme.Colors.brandAccent)
                .onAppear {
                    setupDarwinObservers()
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        PhotoLibraryObserver.shared.scanRecentScreenshots()
                        QuotaManager.shared.refreshQuota()
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshBroadcastSession"), object: nil)
                        Task.detached(priority: .background) {
                            AppCacheManager.shared.cleanupStaleCacheOnStartup()
                        }
                    }
                }
        }
    }
    
    private func setupDarwinObservers() {
        sessionToken = CrossProcessNotifier.observe(name: AppGroupConstants.notificationSessionCompleted) {
            Task { @MainActor in
                // Active session finished recording in ReplayKit
                PhotoLibraryObserver.shared.scanRecentScreenshots()
                NotificationCenter.default.post(name: NSNotification.Name("RefreshBroadcastSession"), object: nil)
            }
        }
    }
}
