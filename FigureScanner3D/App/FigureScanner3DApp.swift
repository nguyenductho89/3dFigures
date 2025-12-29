import SwiftUI
import ARKit

@main
struct FigureScanner3DApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(services)
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

// MARK: - App Services (Dependency Injection Container)
/// Central container for all app services, injected via EnvironmentObject
@MainActor
class AppServices: ObservableObject {
    let storageService: ScanStorageService
    let processingService: MeshProcessingService
    let exportService: MeshExportService

    init() {
        self.storageService = ScanStorageService()
        self.processingService = MeshProcessingService()
        self.exportService = MeshExportService()
    }
}
