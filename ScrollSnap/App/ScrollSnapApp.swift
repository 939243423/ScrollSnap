import SwiftUI

@main
struct ScrollSnapApp: App {
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
