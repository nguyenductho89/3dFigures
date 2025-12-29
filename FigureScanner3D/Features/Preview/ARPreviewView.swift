import SwiftUI
import RealityKit
import ARKit

/// AR Preview view for viewing 3D models in augmented reality
struct ARPreviewView: View {
    let mesh: CapturedMesh
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ARPreviewViewModel

    init(mesh: CapturedMesh) {
        self.mesh = mesh
        _viewModel = StateObject(wrappedValue: ARPreviewViewModel(mesh: mesh))
    }

    var body: some View {
        ZStack {
            // AR View
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()

            // Overlay UI
            VStack {
                // Top bar
                topBar

                Spacer()

                // Placement instruction
                if !viewModel.isModelPlaced {
                    placementInstructions
                }

                // Bottom controls
                if viewModel.isModelPlaced {
                    modelControls
                }
            }
        }
        .alert("AR Not Available", isPresented: $viewModel.showARError) {
            Button("OK") { dismiss() }
        } message: {
            Text("AR features require a device with ARKit support.")
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

            // AR Status
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.trackingState == .normal ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(viewModel.trackingStateText)
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

    // MARK: - Placement Instructions
    private var placementInstructions: some View {
        VStack(spacing: 16) {
            // Crosshair
            if viewModel.canPlaceModel {
                Image(systemName: "plus.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }

            VStack(spacing: 8) {
                Text(viewModel.canPlaceModel ? "Tap to place model" : "Point at a flat surface")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Move your device to detect surfaces")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)

            // Place button
            if viewModel.canPlaceModel {
                Button {
                    viewModel.placeModel()
                } label: {
                    Label("Place Model", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
        .padding(.bottom, 100)
    }

    // MARK: - Model Controls
    private var modelControls: some View {
        VStack(spacing: 16) {
            // Scale slider
            VStack(spacing: 8) {
                Text("Scale: \(String(format: "%.1fx", viewModel.modelScale))")
                    .font(.caption)
                    .foregroundColor(.white)

                Slider(value: $viewModel.modelScale, in: 0.1...3.0, step: 0.1)
                    .tint(.blue)
                    .onChange(of: viewModel.modelScale) { newValue in
                        viewModel.updateModelScale(newValue)
                    }
            }
            .padding(.horizontal, 40)

            // Action buttons
            HStack(spacing: 20) {
                // Reset position
                Button {
                    viewModel.resetModelPosition()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                        Text("Reset")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 60)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }

                // Remove model
                Button {
                    viewModel.removeModel()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("Remove")
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                    .frame(width: 70, height: 60)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }

                // Take photo
                Button {
                    viewModel.captureSnapshot()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("Photo")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 60)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
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
class ARPreviewViewModel: ObservableObject {
    enum TrackingState {
        case initializing
        case normal
        case limited
        case notAvailable
    }

    let mesh: CapturedMesh
    private var arView: ARView?
    private var modelEntity: ModelEntity?
    private var anchorEntity: AnchorEntity?

    @Published var trackingState: TrackingState = .initializing
    @Published var canPlaceModel = false
    @Published var isModelPlaced = false
    @Published var modelScale: Float = 1.0
    @Published var showARError = false

    var trackingStateText: String {
        switch trackingState {
        case .initializing: return "Initializing..."
        case .normal: return "Tracking"
        case .limited: return "Limited"
        case .notAvailable: return "Not Available"
        }
    }

    init(mesh: CapturedMesh) {
        self.mesh = mesh
    }

    func setupARView(_ arView: ARView) {
        self.arView = arView

        // Check AR availability
        guard ARWorldTrackingConfiguration.isSupported else {
            showARError = true
            return
        }

        // Configure AR session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        arView.session.run(config)

        // Add coaching overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coachingOverlay)

        // Create model entity from mesh
        createModelEntity()
    }

    private func createModelEntity() {
        // Create mesh descriptor
        var meshDescriptor = MeshDescriptor(name: "ScanMesh")

        // Convert vertices
        meshDescriptor.positions = MeshBuffers.Positions(mesh.vertices)

        // Convert faces to triangle indices
        var indices: [UInt32] = []
        for face in mesh.faces {
            if face.count >= 3 {
                // Triangulate face
                for i in 1..<(face.count - 1) {
                    indices.append(UInt32(face[0]))
                    indices.append(UInt32(face[i]))
                    indices.append(UInt32(face[i + 1]))
                }
            }
        }
        meshDescriptor.primitives = .triangles(indices)

        // Add normals if available
        if !mesh.normals.isEmpty {
            meshDescriptor.normals = MeshBuffers.Normals(mesh.normals)
        }

        do {
            let meshResource = try MeshResource.generate(from: [meshDescriptor])

            // Create material
            var material = SimpleMaterial()
            material.color = .init(tint: .white.withAlphaComponent(0.9), texture: nil)
            material.metallic = .init(floatLiteral: 0.1)
            material.roughness = .init(floatLiteral: 0.7)

            modelEntity = ModelEntity(mesh: meshResource, materials: [material])

            // Enable gestures
            modelEntity?.generateCollisionShapes(recursive: true)

        } catch {
            print("Failed to create mesh: \(error)")
        }
    }

    func updateTrackingState(_ state: ARCamera.TrackingState) {
        switch state {
        case .notAvailable:
            trackingState = .notAvailable
            canPlaceModel = false
        case .limited:
            trackingState = .limited
            canPlaceModel = false
        case .normal:
            trackingState = .normal
            canPlaceModel = true
        }
    }

    func placeModel() {
        guard let arView = arView,
              let modelEntity = modelEntity else { return }

        // Raycast to find placement position
        let center = arView.center
        if let result = arView.raycast(from: center, allowing: .estimatedPlane, alignment: .any).first {
            // Create anchor at hit location
            let anchor = AnchorEntity(world: result.worldTransform)
            anchor.addChild(modelEntity)

            arView.scene.addAnchor(anchor)
            self.anchorEntity = anchor

            isModelPlaced = true

            // Enable gestures on model
            arView.installGestures([.translation, .rotation, .scale], for: modelEntity)
        }
    }

    func updateModelScale(_ scale: Float) {
        modelEntity?.scale = SIMD3<Float>(repeating: scale)
    }

    func resetModelPosition() {
        guard let anchorEntity = anchorEntity else { return }
        modelEntity?.position = .zero
        modelEntity?.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        modelEntity?.scale = SIMD3<Float>(repeating: modelScale)
    }

    func removeModel() {
        anchorEntity?.removeFromParent()
        anchorEntity = nil
        isModelPlaced = false
    }

    func captureSnapshot() {
        guard let arView = arView else { return }

        arView.snapshot(saveToHDR: false) { image in
            guard let image = image else { return }

            // Save to photos
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

// MARK: - AR View Container
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: ARPreviewViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false

        context.coordinator.arView = arView
        viewModel.setupARView(arView)

        // Set delegate for tracking state updates
        arView.session.delegate = context.coordinator

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        var arView: ARView?
        let viewModel: ARPreviewViewModel

        init(viewModel: ARPreviewViewModel) {
            self.viewModel = viewModel
        }

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            Task { @MainActor in
                viewModel.updateTrackingState(camera.trackingState)
            }
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Update can place model based on detected planes
            Task { @MainActor in
                if viewModel.trackingState == .normal && !viewModel.isModelPlaced {
                    // Check if we have any planes
                    let hasPlanes = frame.anchors.contains { $0 is ARPlaneAnchor }
                    viewModel.canPlaceModel = hasPlanes
                }
            }
        }
    }
}

#Preview {
    ARPreviewView(
        mesh: CapturedMesh(
            vertices: [],
            normals: [],
            faces: [],
            textureCoordinates: nil,
            textureData: nil,
            scanMode: .face,
            captureDate: Date()
        )
    )
}
