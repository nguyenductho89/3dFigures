import SwiftUI

/// Export options view with unit selection and format configuration
struct ExportOptionsView: View {
    let mesh: CapturedMesh
    let onExport: (ExportConfiguration) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ExportOptionsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // Format Selection
                Section("Export Format") {
                    Picker("Format", selection: $viewModel.selectedFormat) {
                        ForEach(MeshExportService.ExportFormat.supportedFormats, id: \.self) { format in
                            HStack {
                                Image(systemName: format.icon)
                                Text(format.displayName)
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // Unit Selection
                Section {
                    Picker("Units", selection: $viewModel.selectedUnit) {
                        ForEach(ExportUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Scale preview
                    HStack {
                        Text("Scale Factor")
                        Spacer()
                        Text(String(format: "%.4f", viewModel.scaleFactor))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Units")
                } footer: {
                    Text("Original mesh is in meters. Select your target unit for 3D printing or modeling software.")
                }

                // Format-specific options
                if viewModel.selectedFormat == .stl {
                    stlOptions
                } else if viewModel.selectedFormat == .obj {
                    objOptions
                } else if viewModel.selectedFormat == .ply {
                    plyOptions
                }

                // Mesh Processing
                Section {
                    Toggle("Center Mesh", isOn: $viewModel.centerMesh)
                    Toggle("Include Normals", isOn: $viewModel.includeNormals)
                } header: {
                    Text("Processing")
                } footer: {
                    Text("Center mesh places the model at origin (0,0,0).")
                }

                // File Info Preview
                Section("Preview") {
                    LabeledContent("Vertices", value: mesh.vertexCount.formattedWithSeparator)
                    LabeledContent("Faces", value: mesh.faceCount.formattedWithSeparator)
                    LabeledContent("Est. File Size", value: viewModel.estimatedFileSize(for: mesh))

                    if let dims = viewModel.scaledDimensions(for: mesh) {
                        LabeledContent("Dimensions", value: dims)
                    }
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        let config = viewModel.buildConfiguration()
                        onExport(config)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - STL Options
    private var stlOptions: some View {
        Section("STL Options") {
            Picker("File Type", selection: $viewModel.binaryFormat) {
                Text("Binary (Smaller)").tag(true)
                Text("ASCII (Readable)").tag(false)
            }
        }
    }

    // MARK: - OBJ Options
    private var objOptions: some View {
        Section {
            Toggle("Include Texture", isOn: $viewModel.includeTexture)

            if viewModel.includeTexture {
                Picker("Texture Resolution", selection: $viewModel.textureResolution) {
                    ForEach(TextureResolution.allCases, id: \.self) { res in
                        Text(res.displayName).tag(res)
                    }
                }

                Toggle("Create ZIP Archive", isOn: $viewModel.createZipArchive)
            }

            Toggle("Include Texture Coords", isOn: $viewModel.includeTextureCoords)
        } header: {
            Text("OBJ Options")
        } footer: {
            if viewModel.createZipArchive {
                Text("ZIP archive will include OBJ, MTL, and texture files.")
            }
        }
    }

    // MARK: - PLY Options
    private var plyOptions: some View {
        Section("PLY Options") {
            Picker("File Type", selection: $viewModel.binaryFormat) {
                Text("Binary (Smaller)").tag(true)
                Text("ASCII (Readable)").tag(false)
            }
        }
    }
}

// MARK: - Export Unit
enum ExportUnit: String, CaseIterable {
    case millimeters = "mm"
    case centimeters = "cm"
    case meters = "m"
    case inches = "in"

    var displayName: String {
        switch self {
        case .millimeters: return "mm"
        case .centimeters: return "cm"
        case .meters: return "m"
        case .inches: return "in"
        }
    }

    /// Scale factor to convert from meters
    var scaleFromMeters: Float {
        switch self {
        case .millimeters: return 1000.0
        case .centimeters: return 100.0
        case .meters: return 1.0
        case .inches: return 39.3701
        }
    }
}

// MARK: - Texture Resolution
enum TextureResolution: String, CaseIterable {
    case low = "1024"
    case medium = "2048"
    case high = "4096"

    var displayName: String {
        switch self {
        case .low: return "1024 × 1024"
        case .medium: return "2048 × 2048"
        case .high: return "4096 × 4096"
        }
    }

    var size: Int {
        switch self {
        case .low: return 1024
        case .medium: return 2048
        case .high: return 4096
        }
    }
}

// MARK: - Export Configuration
struct ExportConfiguration {
    let format: MeshExportService.ExportFormat
    let unit: ExportUnit
    let scale: Float
    let centerMesh: Bool
    let includeNormals: Bool
    let binaryFormat: Bool
    let includeTexture: Bool
    let includeTextureCoords: Bool
    let textureResolution: TextureResolution
    let createZipArchive: Bool
}

// MARK: - View Model
@MainActor
class ExportOptionsViewModel: ObservableObject {
    @Published var selectedFormat: MeshExportService.ExportFormat = .stl
    @Published var selectedUnit: ExportUnit = .millimeters
    @Published var centerMesh = true
    @Published var includeNormals = true
    @Published var binaryFormat = true
    @Published var includeTexture = true
    @Published var includeTextureCoords = true
    @Published var textureResolution: TextureResolution = .medium
    @Published var createZipArchive = true

    var scaleFactor: Float {
        selectedUnit.scaleFromMeters
    }

    func estimatedFileSize(for mesh: CapturedMesh) -> String {
        let vertexCount = mesh.vertexCount
        let faceCount = mesh.faceCount

        var bytes: Int64 = 0

        switch selectedFormat {
        case .stl:
            if binaryFormat {
                // 80 header + 4 count + 50 bytes per triangle
                bytes = Int64(80 + 4 + faceCount * 50)
            } else {
                // Approximate ASCII size
                bytes = Int64(faceCount * 250)
            }
        case .obj:
            // Approximate: vertices + normals + faces
            bytes = Int64(vertexCount * 40 + vertexCount * 40 + faceCount * 30)
            if includeTexture {
                bytes += Int64(textureResolution.size * textureResolution.size / 10) // JPEG compressed
            }
        case .ply:
            if binaryFormat {
                bytes = Int64(vertexCount * 24 + faceCount * 16)
            } else {
                bytes = Int64(vertexCount * 50 + faceCount * 20)
            }
        case .usdz:
            bytes = Int64(vertexCount * 30 + faceCount * 20)
        }

        return bytes.fileSizeFormatted
    }

    func scaledDimensions(for mesh: CapturedMesh) -> String? {
        let dims = mesh.dimensions
        let scale = scaleFactor

        let w = dims.x * scale
        let h = dims.y * scale
        let d = dims.z * scale

        let unit = selectedUnit.displayName

        if scale >= 100 {
            return String(format: "%.1f × %.1f × %.1f %@", w, h, d, unit)
        } else {
            return String(format: "%.2f × %.2f × %.2f %@", w, h, d, unit)
        }
    }

    func buildConfiguration() -> ExportConfiguration {
        ExportConfiguration(
            format: selectedFormat,
            unit: selectedUnit,
            scale: scaleFactor,
            centerMesh: centerMesh,
            includeNormals: includeNormals,
            binaryFormat: binaryFormat,
            includeTexture: includeTexture,
            includeTextureCoords: includeTextureCoords,
            textureResolution: textureResolution,
            createZipArchive: createZipArchive
        )
    }
}

// MARK: - Export Format Extension
extension MeshExportService.ExportFormat {
    var icon: String {
        switch self {
        case .stl: return "cube"
        case .obj: return "cube.transparent"
        case .ply: return "point.3.filled.connected.trianglepath.dotted"
        case .usdz: return "arkit"
        }
    }
}

#Preview {
    ExportOptionsView(
        mesh: CapturedMesh(
            vertices: [],
            normals: [],
            faces: [],
            textureCoordinates: nil,
            textureData: nil,
            scanMode: .face,
            captureDate: Date()
        )
    ) { config in
        print("Export with config: \(config)")
    }
}
