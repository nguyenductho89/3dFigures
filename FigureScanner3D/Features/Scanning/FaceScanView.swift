import SwiftUI
import ARKit
import RealityKit

struct FaceScanView: View {
    @StateObject private var viewModel = FaceScanViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // AR View Container
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()

            // Overlay UI
            VStack {
                // Top Bar
                topBar

                Spacer()

                // Guidance Frame
                if viewModel.scanState == .ready || viewModel.scanState == .scanning {
                    guidanceFrame
                }

                Spacer()

                // Bottom Controls
                bottomControls
            }
        }
        .navigationBarHidden(true)
        .alert("Scan Complete", isPresented: $viewModel.showCompletionAlert) {
            Button("View Model") {
                viewModel.navigateToPreview = true
            }
            Button("Scan Again") {
                viewModel.resetScan()
            }
        }
    }

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

            // Scan quality indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.scanQuality.color)
                    .frame(width: 10, height: 10)
                Text(viewModel.scanQuality.description)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .padding()
    }

    private var guidanceFrame: some View {
        ZStack {
            // Face outline guide
            RoundedRectangle(cornerRadius: 120)
                .stroke(viewModel.scanState == .scanning ? Color.green : Color.white, lineWidth: 3)
                .frame(width: 250, height: 320)

            if viewModel.scanState == .ready {
                Text("Position your face here")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 350)
            }

            if viewModel.scanState == .scanning {
                // Progress indicator
                VStack {
                    Text("Scanning...")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(viewModel.guidanceText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 350)
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Progress bar
            if viewModel.scanState == .scanning {
                ProgressView(value: viewModel.scanProgress)
                    .progressViewStyle(.linear)
                    .tint(.green)
                    .padding(.horizontal, 40)
            }

            // Capture button
            Button(action: { viewModel.toggleScan() }) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .fill(viewModel.scanState == .scanning ? Color.red : Color.white)
                        .frame(width: 65, height: 65)

                    if viewModel.scanState == .scanning {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .padding()
        .background(.ultraThinMaterial)
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

    enum ScanQuality {
        case poor, fair, good, excellent

        var color: Color {
            switch self {
            case .poor: return .red
            case .fair: return .orange
            case .good: return .yellow
            case .excellent: return .green
            }
        }

        var description: String {
            switch self {
            case .poor: return "Poor lighting"
            case .fair: return "Fair"
            case .good: return "Good"
            case .excellent: return "Excellent"
            }
        }
    }

    @Published var scanState: ScanState = .ready
    @Published var scanProgress: Double = 0.0
    @Published var scanQuality: ScanQuality = .good
    @Published var guidanceText: String = "Slowly turn your head left"
    @Published var showCompletionAlert: Bool = false
    @Published var navigateToPreview: Bool = false

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
        scanState = .scanning
        // Simulate scanning progress
        simulateScanProgress()
    }

    func stopScan() {
        scanState = .processing
        // Process the scan
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.scanState = .completed
            self.showCompletionAlert = true
        }
    }

    func resetScan() {
        scanState = .ready
        scanProgress = 0.0
    }

    private func simulateScanProgress() {
        // Simulation for demo purposes
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            Task { @MainActor in
                if self.scanProgress < 1.0 && self.scanState == .scanning {
                    self.scanProgress += 0.02
                    self.updateGuidance()
                } else {
                    timer.invalidate()
                    if self.scanProgress >= 1.0 {
                        self.stopScan()
                    }
                }
            }
        }
    }

    private func updateGuidance() {
        if scanProgress < 0.33 {
            guidanceText = "Slowly turn your head left"
        } else if scanProgress < 0.66 {
            guidanceText = "Now turn to center"
        } else {
            guidanceText = "Turn your head right"
        }
    }
}

// MARK: - AR View Container
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: FaceScanViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR session for face scanning
        let configuration = ARFaceTrackingConfiguration()
        if ARFaceTrackingConfiguration.isSupported {
            arView.session.run(configuration)
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Update AR view based on view model state
    }
}

#Preview {
    FaceScanView()
}
