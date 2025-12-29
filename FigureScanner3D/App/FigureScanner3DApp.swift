import SwiftUI

@main
struct FigureScanner3DApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var isDeviceSupported: Bool = false
    @Published var hasLiDAR: Bool = false

    init() {
        checkDeviceCapabilities()
    }

    private func checkDeviceCapabilities() {
        // Check for LiDAR support
        if #available(iOS 16.0, *) {
            // ARWorldTrackingConfiguration.supportsSceneReconstruction will be checked
            // when ARKit is properly imported
            hasLiDAR = true // Placeholder - will be replaced with actual check
            isDeviceSupported = true
        }
    }
}
