import SwiftUI
import SceneKit

/// 3D Preview view for captured meshes using SceneKit
struct MeshPreviewView: View {
    let mesh: CapturedMesh
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MeshPreviewViewModel

    init(mesh: CapturedMesh) {
        self.mesh = mesh
        _viewModel = StateObject(wrappedValue: MeshPreviewViewModel(mesh: mesh))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 3D Scene View
                SceneKitView(viewModel: viewModel)
                    .ignoresSafeArea()

                // Overlay controls
                VStack {
                    Spacer()
                    controlsOverlay
                }

                // Export progress overlay
                if viewModel.isExporting {
                    exportingOverlay
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Quick export options
                        Section("Quick Export") {
                            Button(action: { viewModel.exportMesh(format: .stl) }) {
                                Label("Export STL", systemImage: "cube")
                            }
                            Button(action: { viewModel.exportMesh(format: .obj) }) {
                                Label("Export OBJ", systemImage: "cube.transparent")
                            }
                            Button(action: { viewModel.exportMesh(format: .ply) }) {
                                Label("Export PLY", systemImage: "point.3.filled.connected.trianglepath.dotted")
                            }
                        }

                        Divider()

                        // Advanced export
                        Button(action: { viewModel.showExportOptions = true }) {
                            Label("Export Options...", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(viewModel.isExporting)
                }
            }
            .sheet(isPresented: $viewModel.showExportOptions) {
                ExportOptionsView(mesh: mesh) { config in
                    viewModel.exportWithConfiguration(config)
                }
            }
            .sheet(isPresented: $viewModel.showShareExport) {
                if let url = viewModel.exportedFileURL {
                    ShareExportView(
                        fileURL: url,
                        fileName: url.deletingPathExtension().lastPathComponent
                    )
                }
            }
            .sheet(isPresented: $viewModel.showExportSheet) {
                if let url = viewModel.exportedFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Export Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    // MARK: - Exporting Overlay
    private var exportingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Exporting...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }

    private var controlsOverlay: some View {
        VStack(spacing: 16) {
            // Mesh info
            HStack(spacing: 20) {
                InfoBadge(title: "Vertices", value: viewModel.vertexCount.formattedWithSeparator)
                InfoBadge(title: "Faces", value: viewModel.faceCount.formattedWithSeparator)
                if let dims = viewModel.dimensions {
                    InfoBadge(title: "Size", value: dims)
                }
            }
            .padding(.horizontal)

            // Display mode controls
            HStack(spacing: 12) {
                ForEach(MeshPreviewViewModel.DisplayMode.allCases, id: \.self) { mode in
                    Button(action: { viewModel.displayMode = mode }) {
                        VStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.title3)
                            Text(mode.title)
                                .font(.caption2)
                        }
                        .foregroundColor(viewModel.displayMode == mode ? .white : .secondary)
                        .frame(width: 60, height: 50)
                        .background(viewModel.displayMode == mode ? Color.blue : Color.clear)
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
        .padding()
    }
}

// MARK: - Info Badge
struct InfoBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

// MARK: - View Model
@MainActor
class MeshPreviewViewModel: ObservableObject {
    enum DisplayMode: String, CaseIterable {
        case solid
        case wireframe
        case points
        case textured

        var title: String {
            switch self {
            case .solid: return "Solid"
            case .wireframe: return "Wire"
            case .points: return "Points"
            case .textured: return "Texture"
            }
        }

        var icon: String {
            switch self {
            case .solid: return "cube.fill"
            case .wireframe: return "cube"
            case .points: return "circle.grid.3x3"
            case .textured: return "photo"
            }
        }
    }

    let mesh: CapturedMesh
    let scene: SCNScene
    private var meshNode: SCNNode?

    @Published var displayMode: DisplayMode = .solid {
        didSet { updateDisplayMode() }
    }
    @Published var showExportSheet = false
    @Published var showExportOptions = false
    @Published var showShareExport = false
    @Published var showError = false
    @Published var isExporting = false
    @Published var exportedFileURL: URL?
    @Published var errorMessage: String?

    var vertexCount: Int { mesh.vertexCount }
    var faceCount: Int { mesh.faceCount }
    var dimensions: String? {
        let dims = mesh.dimensions
        return String(format: "%.1f×%.1f×%.1fcm", dims.x * 100, dims.y * 100, dims.z * 100)
    }

    init(mesh: CapturedMesh) {
        self.mesh = mesh
        self.scene = SCNScene()
        setupScene()
    }

    private func setupScene() {
        // Create mesh geometry
        let geometry = createGeometry()
        meshNode = SCNNode(geometry: geometry)

        // Center the mesh
        let boundingBox = mesh.boundingBox
        let center = (boundingBox.min + boundingBox.max) / 2
        meshNode?.position = SCNVector3(-center.x, -center.y, -center.z)

        if let node = meshNode {
            scene.rootNode.addChildNode(node)
        }

        // Add lighting
        setupLighting()

        // Add camera
        setupCamera()
    }

    private func createGeometry() -> SCNGeometry {
        // Vertices
        let vertexData = Data(bytes: mesh.vertices, count: mesh.vertices.count * MemoryLayout<SIMD3<Float>>.stride)
        let vertexSource = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: mesh.vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.stride
        )

        // Normals
        let normalData = Data(bytes: mesh.normals, count: mesh.normals.count * MemoryLayout<SIMD3<Float>>.stride)
        let normalSource = SCNGeometrySource(
            data: normalData,
            semantic: .normal,
            vectorCount: mesh.normals.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.stride
        )

        // Indices
        var indices: [UInt32] = []
        for face in mesh.faces {
            for index in face {
                indices.append(UInt32(index))
            }
        }

        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: mesh.faceCount,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )

        var sources = [vertexSource, normalSource]

        // Texture coordinates if available
        if let texCoords = mesh.textureCoordinates {
            let texCoordData = Data(bytes: texCoords, count: texCoords.count * MemoryLayout<SIMD2<Float>>.stride)
            let texCoordSource = SCNGeometrySource(
                data: texCoordData,
                semantic: .texcoord,
                vectorCount: texCoords.count,
                usesFloatComponents: true,
                componentsPerVector: 2,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<SIMD2<Float>>.stride
            )
            sources.append(texCoordSource)
        }

        let geometry = SCNGeometry(sources: sources, elements: [element])

        // Default material
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemBlue
        material.specular.contents = UIColor.white
        material.shininess = 0.3
        material.isDoubleSided = true

        // Apply texture if available
        if let textureData = mesh.textureData, let atlasImage = textureData.atlasImage {
            material.diffuse.contents = atlasImage
        }

        geometry.materials = [material]

        return geometry
    }

    private func setupLighting() {
        // Ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(white: 0.3, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Directional light 1
        let directionalLight1 = SCNLight()
        directionalLight1.type = .directional
        directionalLight1.color = UIColor.white
        directionalLight1.intensity = 800
        let directionalNode1 = SCNNode()
        directionalNode1.light = directionalLight1
        directionalNode1.position = SCNVector3(5, 5, 5)
        directionalNode1.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalNode1)

        // Directional light 2 (fill)
        let directionalLight2 = SCNLight()
        directionalLight2.type = .directional
        directionalLight2.color = UIColor.white
        directionalLight2.intensity = 400
        let directionalNode2 = SCNNode()
        directionalNode2.light = directionalLight2
        directionalNode2.position = SCNVector3(-3, 2, -3)
        directionalNode2.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalNode2)
    }

    private func setupCamera() {
        let camera = SCNCamera()
        camera.automaticallyAdjustsZRange = true

        let cameraNode = SCNNode()
        cameraNode.camera = camera

        // Position camera based on mesh size
        let dims = mesh.dimensions
        let maxDim = max(dims.x, max(dims.y, dims.z))
        cameraNode.position = SCNVector3(0, 0, maxDim * 2)
        cameraNode.look(at: SCNVector3(0, 0, 0))

        scene.rootNode.addChildNode(cameraNode)
    }

    private func updateDisplayMode() {
        guard let geometry = meshNode?.geometry else { return }

        switch displayMode {
        case .solid:
            geometry.materials.first?.fillMode = .fill
            geometry.materials.first?.diffuse.contents = mesh.textureData?.atlasImage ?? UIColor.systemBlue
            meshNode?.isHidden = false

        case .wireframe:
            geometry.materials.first?.fillMode = .lines
            geometry.materials.first?.diffuse.contents = UIColor.systemGreen
            meshNode?.isHidden = false

        case .points:
            // For points, we'd need to create a separate point cloud geometry
            geometry.materials.first?.fillMode = .fill
            geometry.materials.first?.diffuse.contents = UIColor.systemOrange
            meshNode?.isHidden = false

        case .textured:
            geometry.materials.first?.fillMode = .fill
            if let textureData = mesh.textureData, let atlasImage = textureData.atlasImage {
                geometry.materials.first?.diffuse.contents = atlasImage
            } else {
                geometry.materials.first?.diffuse.contents = UIColor.systemGray
            }
            meshNode?.isHidden = false
        }
    }

    func exportMesh(format: MeshExportService.ExportFormat) {
        Task {
            isExporting = true
            defer { isExporting = false }

            do {
                let exportService = MeshExportService()
                let result = try await exportService.export(
                    mesh: mesh,
                    format: format,
                    fileName: "scan_\(Date().timeIntervalSince1970)"
                )
                exportedFileURL = result.fileURL
                showExportSheet = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    func exportWithConfiguration(_ config: ExportConfiguration) {
        Task {
            isExporting = true
            defer { isExporting = false }

            do {
                let exportService = MeshExportService()
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileName = "scan_\(timestamp)"

                let result = try await exportService.export(
                    mesh: mesh,
                    configuration: config,
                    fileName: fileName
                )
                exportedFileURL = result.fileURL
                showShareExport = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - SceneKit View
struct SceneKitView: UIViewRepresentable {
    @ObservedObject var viewModel: MeshPreviewViewModel

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = viewModel.scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor.systemBackground

        // Enable gestures
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.inertiaEnabled = true

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Scene updates handled by viewModel
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    MeshPreviewView(mesh: CapturedMesh(
        vertices: [
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(0.5, 1, 0)
        ],
        normals: [
            SIMD3<Float>(0, 0, 1),
            SIMD3<Float>(0, 0, 1),
            SIMD3<Float>(0, 0, 1)
        ],
        faces: [[0, 1, 2]],
        textureCoordinates: nil,
        textureData: nil,
        scanMode: .face,
        captureDate: Date()
    ))
}
