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
                // 3D Print Readiness Section (shown first if analyzing)
                if viewModel.isAnalyzing {
                    Section {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Analyzing mesh for 3D printing...")
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let report = viewModel.printReport {
                    printReadinessSection(report: report)
                }

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

                // 3D Print Preparation
                Section {
                    Toggle("Prepare for 3D Print", isOn: $viewModel.prepareForPrint)
                    if viewModel.prepareForPrint {
                        Toggle("Fill Holes", isOn: $viewModel.fillHolesForPrint)
                        Toggle("Fix Non-Manifold", isOn: $viewModel.fixNonManifold)
                    }
                } header: {
                    Text("3D Print Preparation")
                } footer: {
                    Text(viewModel.prepareForPrint ?
                         "Mesh will be repaired for 3D printing (may take longer)." :
                         "Enable to automatically fix common 3D printing issues.")
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
            .task {
                await viewModel.analyzeMesh(mesh)
            }
        }
    }

    // MARK: - Print Readiness Section
    @ViewBuilder
    private func printReadinessSection(report: PrintReadinessService.PrintReadinessReport) -> some View {
        Section {
            // Overall Score
            HStack {
                Text("Print Readiness")
                Spacer()
                PrintScoreBadge(score: report.overallScore)
            }

            // Status indicators
            HStack {
                StatusIndicator(label: "Watertight", isOK: report.isWatertight)
                Spacer()
                StatusIndicator(label: "Manifold", isOK: report.isManifold)
            }

            // Issues summary
            if report.holeCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("\(report.holeCount) holes (\(report.holeTotalVertices) vertices)")
                        .font(.subheadline)
                    Spacer()
                }
            }

            if report.nonManifoldEdgeCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("\(report.nonManifoldEdgeCount) non-manifold edges")
                        .font(.subheadline)
                    Spacer()
                }
            }

            // Volume (if watertight)
            if let volume = report.volume {
                let volumeCm3 = volume * 1_000_000  // m³ to cm³
                LabeledContent("Volume", value: String(format: "%.1f cm³", volumeCm3))
            }

            // Surface area
            let areaCm2 = report.surfaceArea * 10_000  // m² to cm²
            LabeledContent("Surface Area", value: String(format: "%.1f cm²", areaCm2))

        } header: {
            HStack {
                Text("3D Print Analysis")
                Spacer()
                if report.isPrintable {
                    Label("Ready", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("Issues Found", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        } footer: {
            Text(report.scoreDescription)
        }

        // Recommendations
        if !report.recommendations.isEmpty {
            Section("Recommendations") {
                ForEach(Array(report.recommendations.prefix(5).enumerated()), id: \.offset) { _, recommendation in
                    HStack {
                        Image(systemName: iconForSeverity(recommendation.severity))
                            .foregroundColor(colorForSeverity(recommendation.severity))
                        Text(recommendation.description)
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private func iconForSeverity(_ severity: PrintReadinessService.PrintRecommendation.Severity) -> String {
        switch severity {
        case .critical: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .suggestion: return "lightbulb.fill"
        }
    }

    private func colorForSeverity(_ severity: PrintReadinessService.PrintRecommendation.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .suggestion: return .blue
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

    // 3D Print preparation options
    let prepareForPrint: Bool
    let fillHolesForPrint: Bool
    let fixNonManifold: Bool
}

// MARK: - Print Score Badge
struct PrintScoreBadge: View {
    let score: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("\(score)")
                .font(.headline)
                .fontWeight(.bold)
            Text("/100")
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(scoreColor.opacity(0.2))
        .foregroundColor(scoreColor)
        .cornerRadius(8)
    }

    private var scoreColor: Color {
        switch score {
        case 90...100: return .green
        case 70..<90: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let label: String
    let isOK: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isOK ? .green : .red)
            Text(label)
                .font(.subheadline)
        }
    }
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

    // 3D Print preparation
    @Published var prepareForPrint = false
    @Published var fillHolesForPrint = true
    @Published var fixNonManifold = true

    // Print analysis
    @Published var isAnalyzing = false
    @Published var printReport: PrintReadinessService.PrintReadinessReport?

    private let printReadinessService = PrintReadinessService()

    var scaleFactor: Float {
        selectedUnit.scaleFromMeters
    }

    func analyzeMesh(_ mesh: CapturedMesh) async {
        isAnalyzing = true
        let report = await printReadinessService.analyze(mesh: mesh)
        isAnalyzing = false
        printReport = report

        // Auto-enable print preparation if mesh has issues
        if !report.isPrintable {
            prepareForPrint = true
        }
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
            createZipArchive: createZipArchive,
            prepareForPrint: prepareForPrint,
            fillHolesForPrint: fillHolesForPrint,
            fixNonManifold: fixNonManifold
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
