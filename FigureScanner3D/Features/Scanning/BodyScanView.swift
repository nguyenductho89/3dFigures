import SwiftUI
import ARKit
import RealityKit

struct BodyScanView: View {
    @StateObject private var viewModel = BodyScanViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // AR View
            BodyARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()

            // Overlay UI
            VStack {
                topBar
                Spacer()
                guidanceOverlay
                Spacer()
                bottomControls
            }
        }
        .navigationBarHidden(true)
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

            // Distance indicator
            HStack(spacing: 8) {
                Image(systemName: "ruler")
                Text(viewModel.distanceText)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .padding()
    }

    private var guidanceOverlay: some View {
        VStack(spacing: 20) {
            if viewModel.scanState == .ready {
                // Body outline guide
                Image(systemName: "figure.stand")
                    .font(.system(size: 200))
                    .foregroundColor(.white.opacity(0.5))

                Text("Position subject in frame")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            if viewModel.scanState == .scanning {
                // Circular progress for 360° scan
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 8)
                        .frame(width: 150, height: 150)

                    Circle()
                        .trim(from: 0, to: viewModel.scanProgress)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))

                    VStack {
                        Text("\(Int(viewModel.scanProgress * 100))%")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(viewModel.currentAngleText)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                Text(viewModel.guidanceText)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 20)
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Scan mode selector
            if viewModel.scanState == .ready {
                Picker("Scan Mode", selection: $viewModel.scanMode) {
                    Text("Auto 360°").tag(BodyScanViewModel.ScanMode.auto)
                    Text("Manual").tag(BodyScanViewModel.ScanMode.manual)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
            }

            // Main action button
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
        }
        .padding()
        .padding(.bottom, 20)
        .background(.ultraThinMaterial)
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

    @Published var scanState: ScanState = .ready
    @Published var scanMode: ScanMode = .auto
    @Published var scanProgress: Double = 0.0
    @Published var distanceText: String = "2.5m"
    @Published var guidanceText: String = "Walk slowly around the subject"
    @Published var currentAngleText: String = "0°"

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
        simulateScanProgress()
    }

    func stopScan() {
        scanState = .processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.scanState = .completed
        }
    }

    private func simulateScanProgress() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            Task { @MainActor in
                if self.scanProgress < 1.0 && self.scanState == .scanning {
                    self.scanProgress += 0.01
                    let angle = Int(self.scanProgress * 360)
                    self.currentAngleText = "\(angle)°"
                } else {
                    timer.invalidate()
                    if self.scanProgress >= 1.0 {
                        self.stopScan()
                    }
                }
            }
        }
    }
}

// MARK: - AR View Container
struct BodyARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: BodyScanViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure for body/world scanning with LiDAR
        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        configuration.frameSemantics.insert(.personSegmentation)
        arView.session.run(configuration)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

#Preview {
    BodyScanView()
}
