import SwiftUI
import ARKit
import RealityKit
import Combine

struct FaceScanView: View {
    @StateObject private var viewModel = FaceScanViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // AR View Container
            LiDARScanARView(viewModel: viewModel)
                .ignoresSafeArea()

            // Overlay UI
            VStack {
                topBar
                Spacer()

                if !viewModel.isDeviceSupported {
                    unsupportedDeviceOverlay
                } else {
                    if viewModel.scanState == .ready || viewModel.scanState == .scanning {
                        guidanceFrame
                    }

                    if viewModel.scanState == .processing {
                        processingOverlay
                    }
                }

                Spacer()
                bottomControls
            }

            // Error alert
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
                // Face detection indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.faceDetected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.faceDetected ? "Face" : "No Face")
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
                if viewModel.faceDetected {
                    Text(String(format: "%.0fcm", viewModel.distanceToFace * 100))
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

    // MARK: - Guidance Frame
    private var guidanceFrame: some View {
        ZStack {
            // Face outline guide
            FaceGuideShape()
                .stroke(
                    viewModel.faceDetected ? Color.green : Color.white,
                    style: StrokeStyle(lineWidth: 3, dash: viewModel.scanState == .scanning ? [] : [10])
                )
                .frame(width: 250, height: 320)

            // Guidance text
            VStack(spacing: 8) {
                if viewModel.scanState == .ready {
                    if !viewModel.faceDetected {
                        Text("Position your face in the frame")
                            .font(.headline)
                    } else if !viewModel.isDistanceOptimal {
                        Text(viewModel.distanceGuidance)
                            .font(.headline)
                    } else {
                        Text("Ready to scan")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }

                if viewModel.scanState == .scanning {
                    Text(viewModel.guidanceText)
                        .font(.headline)

                    // Capture progress indicator
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Circle()
                                .fill(index < viewModel.capturedAnglesCount ? Color.green : Color.white.opacity(0.3))
                                .frame(width: 12, height: 12)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .foregroundColor(.white)
            .padding(.top, 360)
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

            Text("This may take a few seconds")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.6))
    }

    // MARK: - Unsupported Device Overlay
    private var unsupportedDeviceOverlay: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("LiDAR Not Available")
                .font(.title2)
                .fontWeight(.bold)

            Text("This device does not have a LiDAR sensor.\nFace scanning requires iPhone 12 Pro or later.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .foregroundColor(.white)
        .padding()
    }

    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 20) {
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

            // Capture button
            Button(action: { viewModel.toggleScan() }) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .fill(buttonColor)
                        .frame(width: 65, height: 65)

                    if viewModel.scanState == .scanning {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .disabled(!viewModel.canStartScan && viewModel.scanState == .ready)
            .opacity(viewModel.canStartScan || viewModel.scanState != .ready ? 1.0 : 0.5)
            .padding(.bottom, 30)
        }
        .padding()
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

// MARK: - Face Guide Shape
struct FaceGuideShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        let cornerRadius: CGFloat = 120

        // Top curve (forehead)
        path.move(to: CGPoint(x: width * 0.1, y: height * 0.35))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.9, y: height * 0.35),
            control: CGPoint(x: width * 0.5, y: -height * 0.05)
        )

        // Right side
        path.addQuadCurve(
            to: CGPoint(x: width * 0.85, y: height * 0.75),
            control: CGPoint(x: width * 1.05, y: height * 0.55)
        )

        // Chin curve
        path.addQuadCurve(
            to: CGPoint(x: width * 0.15, y: height * 0.75),
            control: CGPoint(x: width * 0.5, y: height * 1.1)
        )

        // Left side
        path.addQuadCurve(
            to: CGPoint(x: width * 0.1, y: height * 0.35),
            control: CGPoint(x: -width * 0.05, y: height * 0.55)
        )

        return path
    }
}

// MARK: - View Model
@MainActor
class FaceScanViewModel: ObservableObject {
    enum ScanState {
        case ready
        case scanning
        case processing
        case completed
    }

    // MARK: - Published Properties
    @Published var scanState: ScanState = .ready
    @Published var scanProgress: Float = 0.0
    @Published var faceDetected = false
    @Published var distanceToFace: Float = 0.0
    @Published var lightingQuality: LiDARScanningService.LightingQuality = .good
    @Published var guidanceText = "Slowly turn your head left"
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
        faceDetected && isDistanceOptimal && lightingQuality != .poor
    }

    var isDistanceOptimal: Bool {
        distanceToFace >= 0.25 && distanceToFace <= 0.50
    }

    var distanceGuidance: String {
        if distanceToFace < 0.25 {
            return "Move further away"
        } else if distanceToFace > 0.50 {
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
        Int(scanProgress * 5)
    }

    var capturedMesh: CapturedMesh? {
        scanningService.capturedMesh
    }

    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Bind scanning service properties
        scanningService.$faceDetected
            .receive(on: DispatchQueue.main)
            .assign(to: &$faceDetected)

        scanningService.$distanceToFace
            .receive(on: DispatchQueue.main)
            .assign(to: &$distanceToFace)

        scanningService.$lightingQuality
            .receive(on: DispatchQueue.main)
            .assign(to: &$lightingQuality)

        scanningService.$scanProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.scanProgress = progress
                self?.updateGuidance(progress: progress)
            }
            .store(in: &cancellables)

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

        scanState = .scanning
        scanningService.startScanning()
    }

    func stopScan() {
        scanState = .processing
        scanningService.stopScanning()

        // Process the mesh
        Task {
            do {
                if let mesh = scanningService.capturedMesh {
                    let _ = try await processingService.process(mesh)
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
                fileName: "face_scan_\(Date().timeIntervalSince1970)"
            )
            exportedFileURL = result.fileURL
            showExportSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateGuidance(progress: Float) {
        switch progress {
        case 0..<0.2:
            guidanceText = "Look straight ahead"
        case 0.2..<0.4:
            guidanceText = "Slowly turn left"
        case 0.4..<0.6:
            guidanceText = "Return to center"
        case 0.6..<0.8:
            guidanceText = "Slowly turn right"
        case 0.8..<1.0:
            guidanceText = "Return to center"
        default:
            guidanceText = "Scan complete!"
        }
    }
}

// MARK: - LiDAR AR View
struct LiDARScanARView: UIViewRepresentable {
    @ObservedObject var viewModel: FaceScanViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false

        // Configure scanning service
        viewModel.scanningService.configure(arView: arView, mode: .face)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Update based on scan state if needed
    }
}

#Preview {
    FaceScanView()
}
