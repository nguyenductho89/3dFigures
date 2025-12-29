import SwiftUI
import ARKit
import RealityKit
import Combine

struct BustScanView: View {
    @StateObject private var viewModel = BustScanViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Check device support
            if !viewModel.isDeviceSupported {
                unsupportedDeviceView
            } else {
                // AR View
                BustARViewContainer(viewModel: viewModel)
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
                // Subject detected indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.subjectDetected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.subjectDetected ? "Ready" : "Position")
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
                if viewModel.subjectDetected {
                    Text(String(format: "%.0fcm", viewModel.distanceToSubject * 100))
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
        ZStack {
            if viewModel.scanState == .ready || viewModel.scanState == .scanning {
                // Bust outline guide
                BustGuideShape()
                    .stroke(
                        viewModel.subjectDetected ? Color.green : Color.white,
                        style: StrokeStyle(lineWidth: 3, dash: viewModel.scanState == .scanning ? [] : [10])
                    )
                    .frame(width: 280, height: 350)

                // Guidance text
                VStack(spacing: 8) {
                    if viewModel.scanState == .ready {
                        if !viewModel.subjectDetected {
                            Text("Position head and shoulders in frame")
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
                            ForEach(0..<7) { index in
                                Circle()
                                    .fill(index < viewModel.capturedAnglesCount ? Color.green : Color.white.opacity(0.3))
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .foregroundColor(.white)
                .padding(.top, 400)
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

            Text("This may take a few seconds")
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

            Text("This device does not have a LiDAR sensor.\nBust scanning requires iPhone 12 Pro or later.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Go Back") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
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
                        .tint(.purple)

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
            return viewModel.canStartScan ? .purple : .gray
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

// MARK: - Bust Guide Shape
struct BustGuideShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        // Head (oval at top)
        let headCenterY = height * 0.18
        let headWidth = width * 0.45
        let headHeight = height * 0.28

        path.addEllipse(in: CGRect(
            x: (width - headWidth) / 2,
            y: headCenterY - headHeight / 2,
            width: headWidth,
            height: headHeight
        ))

        // Neck
        let neckTop = headCenterY + headHeight / 2 - 5
        let neckWidth = width * 0.22

        path.move(to: CGPoint(x: (width - neckWidth) / 2, y: neckTop))
        path.addLine(to: CGPoint(x: (width - neckWidth) / 2, y: height * 0.42))

        path.move(to: CGPoint(x: (width + neckWidth) / 2, y: neckTop))
        path.addLine(to: CGPoint(x: (width + neckWidth) / 2, y: height * 0.42))

        // Shoulders curve
        let shoulderY = height * 0.42
        let shoulderWidth = width * 0.95

        path.move(to: CGPoint(x: (width - neckWidth) / 2, y: shoulderY))
        path.addQuadCurve(
            to: CGPoint(x: (width - shoulderWidth) / 2, y: height * 0.55),
            control: CGPoint(x: width * 0.15, y: shoulderY + 10)
        )
        path.addLine(to: CGPoint(x: (width - shoulderWidth) / 2, y: height * 0.95))

        path.move(to: CGPoint(x: (width + neckWidth) / 2, y: shoulderY))
        path.addQuadCurve(
            to: CGPoint(x: (width + shoulderWidth) / 2, y: height * 0.55),
            control: CGPoint(x: width * 0.85, y: shoulderY + 10)
        )
        path.addLine(to: CGPoint(x: (width + shoulderWidth) / 2, y: height * 0.95))

        // Bottom curve
        path.move(to: CGPoint(x: (width - shoulderWidth) / 2, y: height * 0.95))
        path.addQuadCurve(
            to: CGPoint(x: (width + shoulderWidth) / 2, y: height * 0.95),
            control: CGPoint(x: width / 2, y: height * 1.05)
        )

        return path
    }
}

// MARK: - View Model
@MainActor
class BustScanViewModel: ObservableObject {
    enum ScanState {
        case ready, scanning, processing, completed
    }

    // MARK: - Published Properties
    @Published var scanState: ScanState = .ready
    @Published var scanProgress: Float = 0.0
    @Published var subjectDetected = false
    @Published var distanceToSubject: Float = 0.0
    @Published var lightingQuality: LiDARScanningService.LightingQuality = .good
    @Published var guidanceText = "Slowly rotate around subject"
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
        subjectDetected && isDistanceOptimal && lightingQuality != .poor
    }

    var isDistanceOptimal: Bool {
        distanceToSubject >= 0.4 && distanceToSubject <= 0.8
    }

    var distanceGuidance: String {
        if distanceToSubject < 0.4 {
            return "Move further away"
        } else if distanceToSubject > 0.8 {
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
        Int(scanProgress * 7)
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
        scanningService.$faceDetected
            .receive(on: DispatchQueue.main)
            .assign(to: &$subjectDetected)

        scanningService.$distanceToFace
            .receive(on: DispatchQueue.main)
            .assign(to: &$distanceToSubject)

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

        Task {
            do {
                if let mesh = scanningService.capturedMesh {
                    let options = MeshProcessingService.ProcessingOptions(
                        smoothingIterations: 4,
                        decimationRatio: 0.4
                    )
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
                fileName: "bust_scan_\(Date().timeIntervalSince1970)"
            )
            exportedFileURL = result.fileURL
            showExportSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateGuidance(progress: Float) {
        switch progress {
        case 0..<0.15:
            guidanceText = "Front view"
        case 0.15..<0.3:
            guidanceText = "Turn slightly left"
        case 0.3..<0.45:
            guidanceText = "Left profile"
        case 0.45..<0.55:
            guidanceText = "Return to center"
        case 0.55..<0.7:
            guidanceText = "Turn slightly right"
        case 0.7..<0.85:
            guidanceText = "Right profile"
        case 0.85..<1.0:
            guidanceText = "Return to center"
        default:
            guidanceText = "Scan complete!"
        }
    }
}

// MARK: - AR View Container
struct BustARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: BustScanViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false

        // Configure scanning service for bust mode
        viewModel.scanningService.configure(arView: arView, mode: .bust)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

#Preview {
    BustScanView()
}
