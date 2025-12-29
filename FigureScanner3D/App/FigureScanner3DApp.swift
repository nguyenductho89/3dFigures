import SwiftUI
import ARKit

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
        // Check for LiDAR support using ARKit
        hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        isDeviceSupported = hasLiDAR
    }
}
