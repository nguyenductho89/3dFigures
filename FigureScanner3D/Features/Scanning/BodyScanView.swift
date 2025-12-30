import SwiftUI
import ARKit
import RealityKit
import Combine

struct BodyScanView: View {
    @StateObject private var viewModel = BodyScanViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Check device support
            if !viewModel.isDeviceSupported {
                unsupportedDeviceView
            } else {
                // AR View
                BodyARViewContainer(viewModel: viewModel)
                    .ignoresSafeArea()

                // Overlay UI
                VStack {
                    topBar
                    Spacer()

                    if viewModel.scanState == .processing {
                        processingOverlay
                    } else {
                        guidanceOverlay
                    }

                    Spacer()
                    bottomControls
                }
            }

            // Error banner
            if let error = viewModel.errorMessage {
                errorBanner(message: error)
            }
        }
        .navigationBarHidden(true)
        .alert("Scan Complete", isPresented: $viewModel.showCompletionAlert) {
            Button("View Model") {
                viewModel.navigateToPreview = true
            }
            Button("Export STL") {
                Task { await viewModel.exportMesh(format: .stl) }
            }
            Button("Scan Again", role: .cancel) {
                viewModel.resetScan()
            }
        } message: {
            Text("Captured \(viewModel.vertexCount) vertices")
        }
        .sheet(isPresented: $viewModel.showExportSheet) {
            if let url = viewModel.exportedFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .fullScreenCover(isPresented: $viewModel.navigateToPreview) {
            if let mesh = viewModel.capturedMesh {
                MeshPreviewView(mesh: mesh)
            }
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            // Status indicators
            HStack(spacing: 12) {
                // Body detected indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.bodyDetected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.bodyDetected ? "Body" : "No Body")
                        .font(.caption2)
                }

                // Lighting quality
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.lightingQualityColor)
                        .frame(width: 8, height: 8)
                    Text(viewModel.lightingQualityText)
                        .font(.caption2)
                }

                // Distance indicator
                if viewModel.bodyDetected {
                    Text(String(format: "%.1fm", viewModel.distanceToBody))
                        .font(.caption2)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .padding()
    }

    // MARK: - Guidance Overlay
    private var guidanceOverlay: some View {
        VStack(spacing: 20) {
            if viewModel.scanState == .ready {
                // Body outline guide
                Image(systemName: "figure.stand")
                    .font(.system(size: 180))
                    .foregroundColor(viewModel.bodyDetected ? .green.opacity(0.6) : .white.opacity(0.4))

                if !viewModel.bodyDetected {
                    Text("Position subject in frame")
                        .font(.headline)
                        .foregroundColor(.white)
                } else if !viewModel.isDistanceOptimal {
                    Text(viewModel.distanceGuidance)
                        .font(.headline)
                        .foregroundColor(.yellow)
                } else {
                    Text("Ready to scan")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }

            if viewModel.scanState == .scanning {
                HStack(spacing: 30) {
                    // Vertical coverage indicator (left side)
                    VerticalCoverageIndicator(coverage: viewModel.verticalCoverage)

                    // Circular progress for 360° scan (center)
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 8)
                            .frame(width: 150, height: 150)

                        Circle()
                            .trim(from: 0, to: CGFloat(viewModel.scanProgress))
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))

                        VStack {
                            Text("\(Int(viewModel.scanProgress * 100))%")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("\(viewModel.capturedAnglesCount)/\(viewModel.requiredAngles) angles")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    // Vertical guidance (right side)
                    VerticalScanGuide(direction: viewModel.verticalGuidanceDirection)
                }

                Text(viewModel.guidanceText)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 20)

                // Vertical guidance text
                if viewModel.needsVerticalAdjustment {
                    Text(viewModel.verticalGuidanceText)
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Processing Overlay
    private var processingOverlay: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2)
                .tint(.white)

            Text("Processing mesh...")
                .font(.headline)
                .foregroundColor(.white)

            Text("This may take a moment for body scans")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.6))
    }

    // MARK: - Unsupported Device
    private var unsupportedDeviceView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("LiDAR Not Available")
                .font(.title2)
                .fontWeight(.bold)

            Text("This device does not have a LiDAR sensor.\nBody scanning requires iPhone 12 Pro or later.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Go Back") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Quality and Scan mode selectors
            if viewModel.scanState == .ready {
                VStack(spacing: 12) {
                    // Quality mode selector
                    VStack(spacing: 4) {
                        HStack {
                            Text("Quality")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                        }
                        Picker("Quality", selection: $viewModel.qualityMode) {
                            ForEach(BodyScanViewModel.QualityMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack {
                            Text(viewModel.qualityMode.description)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 40)

                    // Scan mode selector
                    Picker("Scan Mode", selection: $viewModel.scanMode) {
                        Text("Auto 360°").tag(BodyScanViewModel.ScanMode.auto)
                        Text("Manual").tag(BodyScanViewModel.ScanMode.manual)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 40)
                }
            }

            // Progress bar
            if viewModel.scanState == .scanning {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.scanProgress)
                        .progressViewStyle(.linear)
                        .tint(.green)

                    HStack {
                        Text("Vertices: \(viewModel.vertexCount)")
                        Spacer()
                        Text("\(Int(viewModel.scanProgress * 100))%")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 40)
            }

            // Main action button
            Button(action: { viewModel.toggleScan() }) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .fill(buttonColor)
                        .frame(width: 65, height: 65)

                    if viewModel.scanState == .scanning {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                            .cornerRadius(4)
                    }
                }
            }
            .disabled(!viewModel.canStartScan && viewModel.scanState == .ready)
            .opacity(viewModel.canStartScan || viewModel.scanState != .ready ? 1.0 : 0.5)
        }
        .padding()
        .padding(.bottom, 20)
        .background(.ultraThinMaterial)
    }

    private var buttonColor: Color {
        switch viewModel.scanState {
        case .ready:
            return viewModel.canStartScan ? .white : .gray
        case .scanning:
            return .red
        case .processing, .completed:
            return .gray
        }
    }

    // MARK: - Error Banner
    private func errorBanner(message: String) -> some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                Text(message)
                    .font(.subheadline)
                Spacer()
                Button("Dismiss") {
                    viewModel.dismissError()
                }
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.red)
            .cornerRadius(8)
            .padding()

            Spacer()
        }
    }
}

// MARK: - View Model
@MainActor
class BodyScanViewModel: ObservableObject {
    enum ScanState {
        case ready, scanning, processing, completed
    }

    enum ScanMode {
        case auto, manual
    }

    enum QualityMode: String, CaseIterable {
        case standard = "Standard"
        case highDetail = "High Detail"

        var description: String {
            switch self {
            case .standard: return "Faster scan, smaller file"
            case .highDetail: return "Full clothing details, larger file"
            }
        }

        var processingOptions: MeshProcessingService.ProcessingOptions {
            switch self {
            case .standard:
                return MeshProcessingService.ProcessingOptions(
                    smoothingIterations: 3,
                    smoothingFactor: 0.5,
                    decimationRatio: 0.5,
                    fillHoles: true,
                    removeNoise: true,
                    noiseThreshold: 0.002
                )
            case .highDetail:
                // Preserve all mesh details for clothing patterns, buttons, folds
                return MeshProcessingService.ProcessingOptions(
                    smoothingIterations: 1,        // Minimal smoothing
                    smoothingFactor: 0.3,          // Gentle smoothing
                    decimationRatio: 0.85,         // Keep 85% of vertices
                    fillHoles: true,
                    removeNoise: true,
                    noiseThreshold: 0.001          // More aggressive noise removal
                )
            }
        }

        var scanConfiguration: ScanConfiguration {
            switch self {
            case .standard:
                return .default
            case .highDetail:
                // Higher capture rate for better texture coverage
                return ScanConfiguration(
                    requiredAngles: 12,            // More angles for complete coverage
                    textureCaptureInterval: 0.1,   // Faster capture (10 fps)
                    maxTextureFrames: 60,          // More frames for 360° coverage
                    faceScanBounds: ScanConfiguration.default.faceScanBounds,
                    lightingThresholds: ScanConfiguration.LightingThresholds.default,
                    meshDensityTarget: 20,         // Higher mesh density
                    angleBucketSize: 30            // Finer angle tracking
                )
            }
        }
    }

    // MARK: - Published Properties
    @Published var scanState: ScanState = .ready
    @Published var scanMode: ScanMode = .auto
    @Published var qualityMode: QualityMode = .highDetail  // Default to high detail for clothing
    @Published var scanProgress: Float = 0.0
    @Published var bodyDetected = false
    @Published var distanceToBody: Float = 2.0
    @Published var lightingQuality: LiDARScanningService.LightingQuality = .good
    @Published var guidanceText = "Walk slowly around the subject"
    @Published var showCompletionAlert = false
    @Published var navigateToPreview = false
    @Published var errorMessage: String?
    @Published var showExportSheet = false
    @Published var exportedFileURL: URL?

    // MARK: - Services
    let scanningService = LiDARScanningService()
    private let processingService = MeshProcessingService()
    private let exportService = MeshExportService()

    // MARK: - Computed Properties
    var isDeviceSupported: Bool {
        LiDARScanningService.isLiDARAvailable
    }

    var canStartScan: Bool {
        bodyDetected && isDistanceOptimal && lightingQuality != .poor
    }

    var isDistanceOptimal: Bool {
        distanceToBody >= 1.5 && distanceToBody <= 3.0
    }

    var distanceGuidance: String {
        if distanceToBody < 1.5 {
            return "Move further away"
        } else if distanceToBody > 3.0 {
            return "Move closer"
        }
        return "Good distance"
    }

    var lightingQualityColor: Color {
        switch lightingQuality {
        case .poor: return .red
        case .fair: return .orange
        case .good: return .yellow
        case .excellent: return .green
        }
    }

    var lightingQualityText: String {
        lightingQuality.description
    }

    var vertexCount: Int {
        capturedMesh?.vertexCount ?? 0
    }

    var capturedAnglesCount: Int {
        Int(scanProgress * Float(requiredAngles))
    }

    var requiredAngles: Int {
        qualityMode.scanConfiguration.requiredAngles
    }

    var capturedMesh: CapturedMesh? {
        scanningService.capturedMesh
    }

    // MARK: - Vertical Coverage
    var verticalCoverage: VerticalCoverage {
        // Simulated vertical coverage based on scan progress
        let headCovered = scanProgress > 0.1
        let torsoCovered = scanProgress > 0.3
        let legsCovered = scanProgress > 0.5
        let feetCovered = scanProgress > 0.7
        return VerticalCoverage(head: headCovered, torso: torsoCovered, legs: legsCovered, feet: feetCovered)
    }

    var needsVerticalAdjustment: Bool {
        // Check if user needs to adjust camera height
        scanProgress > 0.2 && !verticalCoverage.isComplete
    }

    var verticalGuidanceText: String {
        if !verticalCoverage.head {
            return "Tilt up to capture head"
        } else if !verticalCoverage.feet {
            return "Tilt down to capture feet"
        }
        return ""
    }

    var verticalGuidanceDirection: VerticalScanGuide.Direction {
        if !verticalCoverage.head { return .up }
        if !verticalCoverage.feet { return .down }
        return .center
    }

    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        setupBindings()
    }

    private func setupBindings() {
        scanningService.$scanProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.scanProgress = progress
                self?.updateGuidance(progress: progress)
            }
            .store(in: &cancellables)

        scanningService.$lightingQuality
            .receive(on: DispatchQueue.main)
            .assign(to: &$lightingQuality)

        scanningService.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
    }

    // MARK: - Actions
    func toggleScan() {
        switch scanState {
        case .ready:
            startScan()
        case .scanning:
            stopScan()
        default:
            break
        }
    }

    func startScan() {
        guard canStartScan else { return }

        // Apply scan configuration based on quality mode
        scanningService.updateConfiguration(qualityMode.scanConfiguration)

        scanState = .scanning
        scanningService.startScanning()
    }

    func stopScan() {
        scanState = .processing
        scanningService.stopScanning()

        // Process the mesh with quality-based options
        Task {
            do {
                if let mesh = scanningService.capturedMesh {
                    // Use processing options based on quality mode
                    let options = qualityMode.processingOptions
                    print("[BodyScan] Processing with \(qualityMode.rawValue) mode")
                    print("[BodyScan] Decimation: \(Int(options.decimationRatio * 100))%, Smoothing: \(options.smoothingIterations) iterations")
                    let _ = try await processingService.process(mesh, options: options)
                }
                scanState = .completed
                showCompletionAlert = true
            } catch {
                errorMessage = error.localizedDescription
                scanState = .ready
            }
        }
    }

    func resetScan() {
        scanState = .ready
        scanProgress = 0.0
        scanningService.resetScan()
        errorMessage = nil
    }

    func dismissError() {
        errorMessage = nil
    }

    func exportMesh(format: MeshExportService.ExportFormat) async {
        guard let mesh = capturedMesh else { return }

        do {
            let result = try await exportService.export(
                mesh: mesh,
                format: format,
                fileName: "body_scan_\(Date().timeIntervalSince1970)"
            )
            exportedFileURL = result.fileURL
            showExportSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateGuidance(progress: Float) {
        let angle = Int(progress * 360)
        switch progress {
        case 0..<0.125:
            guidanceText = "Front view - Stay still"
        case 0.125..<0.25:
            guidanceText = "Move to front-right (\(angle)°)"
        case 0.25..<0.375:
            guidanceText = "Move to right side (\(angle)°)"
        case 0.375..<0.5:
            guidanceText = "Move to back-right (\(angle)°)"
        case 0.5..<0.625:
            guidanceText = "Move to back view (\(angle)°)"
        case 0.625..<0.75:
            guidanceText = "Move to back-left (\(angle)°)"
        case 0.75..<0.875:
            guidanceText = "Move to left side (\(angle)°)"
        case 0.875..<1.0:
            guidanceText = "Complete the circle (\(angle)°)"
        default:
            guidanceText = "Scan complete!"
        }
    }

    func updateBodyDetection(_ detected: Bool, distance: Float) {
        bodyDetected = detected
        distanceToBody = distance
    }
}

// MARK: - Vertical Coverage Model
struct VerticalCoverage {
    let head: Bool
    let torso: Bool
    let legs: Bool
    let feet: Bool

    var isComplete: Bool {
        head && torso && legs && feet
    }

    var completionPercentage: Float {
        let parts = [head, torso, legs, feet]
        let completed = parts.filter { $0 }.count
        return Float(completed) / Float(parts.count)
    }
}

// MARK: - Vertical Coverage Indicator
struct VerticalCoverageIndicator: View {
    let coverage: VerticalCoverage

    var body: some View {
        VStack(spacing: 4) {
            // Head
            BodyPartIndicator(name: "Head", isCovered: coverage.head, icon: "circle.fill")
            // Torso
            BodyPartIndicator(name: "Torso", isCovered: coverage.torso, icon: "rectangle.fill")
            // Legs
            BodyPartIndicator(name: "Legs", isCovered: coverage.legs, icon: "rectangle.fill")
            // Feet
            BodyPartIndicator(name: "Feet", isCovered: coverage.feet, icon: "rectangle.fill")
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct BodyPartIndicator: View {
    let name: String
    let isCovered: Bool
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isCovered ? Color.green : Color.white.opacity(0.3))
                .frame(width: 8, height: heightForPart)

            Text(name)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var heightForPart: CGFloat {
        switch name {
        case "Head": return 12
        case "Torso": return 20
        case "Legs": return 24
        case "Feet": return 8
        default: return 12
        }
    }
}

// MARK: - Vertical Scan Guide
struct VerticalScanGuide: View {
    enum Direction {
        case up, down, center
    }

    let direction: Direction
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 4) {
            if direction == .up {
                Image(systemName: "chevron.up")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.yellow)
                    .offset(y: isAnimating ? -5 : 0)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    .onAppear { isAnimating = true }
            }

            // Body silhouette
            Image(systemName: "figure.stand")
                .font(.system(size: 40))
                .foregroundColor(direction == .center ? .green : .white.opacity(0.5))

            if direction == .down {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.yellow)
                    .offset(y: isAnimating ? 5 : 0)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    .onAppear { isAnimating = true }
            }
        }
    }
}

// MARK: - AR View Container
struct BodyARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: BodyScanViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false

        // Configure scanning service for body mode
        viewModel.scanningService.configure(arView: arView, mode: .body)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

#Preview {
    BodyScanView()
}
