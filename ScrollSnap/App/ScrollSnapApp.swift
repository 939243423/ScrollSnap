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
                .tint(Color(red: 0.29, green: 0.33, blue: 0.41))
                .onAppear {
                    setupDarwinObservers()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        PhotoLibraryObserver.shared.scanRecentScreenshots()
                        QuotaManager.shared.refreshQuota()
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshBroadcastSession"), object: nil)
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
