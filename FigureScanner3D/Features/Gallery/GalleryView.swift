import SwiftUI

struct GalleryView: View {
    @StateObject private var viewModel = GalleryViewModel()
    @State private var searchText = ""
    @State private var selectedScan: Scan3DModel?
    @State private var showDeleteConfirmation = false
    @State private var scanToDelete: Scan3DModel?
    @State private var showRenameDialog = false
    @State private var renameText = ""
    @State private var scanToRename: Scan3DModel?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.scans.isEmpty {
                    emptyState
                } else {
                    scanGrid
                }
            }
            .navigationTitle("Gallery")
            .searchable(text: $searchText, prompt: "Search scans")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        // View mode toggle
                        Button(action: { viewModel.toggleViewMode() }) {
                            Image(systemName: viewModel.viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                        }

                        // Sort menu
                        Menu {
                            ForEach(GalleryViewModel.SortOption.allCases, id: \.self) { option in
                                Button(action: { viewModel.sortBy(option) }) {
                                    HStack {
                                        Text(option.displayName)
                                        if viewModel.sortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadScans()
            }
            .sheet(item: $selectedScan) { scan in
                ScanDetailSheet(scan: scan, viewModel: viewModel)
            }
            .alert("Delete Scan", isPresented: $showDeleteConfirmation, presenting: scanToDelete) { scan in
                Button("Delete", role: .destructive) {
                    Task { await viewModel.deleteScan(scan) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { scan in
                Text("Are you sure you want to delete '\(scan.name)'? This cannot be undone.")
            }
            .alert("Rename Scan", isPresented: $showRenameDialog) {
                TextField("New name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    if let scan = scanToRename {
                        Task { await viewModel.renameScan(scan, newName: renameText) }
                    }
                }
            } message: {
                Text("Enter a new name for this scan")
            }
            .task {
                await viewModel.loadScans()
            }
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let url = viewModel.exportedFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .overlay {
                if viewModel.isExporting {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Exporting...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(30)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                }
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading scans...")
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Scans Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your 3D scans will appear here.\nStart by creating your first scan!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            NavigationLink(destination: HomeView()) {
                Label("Start Scanning", systemImage: "viewfinder")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }

    // MARK: - Scan Grid/List
    private var scanGrid: some View {
        ScrollView {
            if viewModel.viewMode == .grid {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(viewModel.filteredScans(searchText)) { scan in
                        ScanGridCard(scan: scan)
                            .onTapGesture { selectedScan = scan }
                            .contextMenu { scanContextMenu(for: scan) }
                    }
                }
                .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredScans(searchText)) { scan in
                        ScanListRow(scan: scan)
                            .onTapGesture { selectedScan = scan }
                            .contextMenu { scanContextMenu(for: scan) }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Context Menu
    @ViewBuilder
    private func scanContextMenu(for scan: Scan3DModel) -> some View {
        Button {
            selectedScan = scan
        } label: {
            Label("View Details", systemImage: "info.circle")
        }

        Button {
            scanToRename = scan
            renameText = scan.name
            showRenameDialog = true
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Menu {
            Button {
                Task { await viewModel.exportScan(scan, format: .stl) }
            } label: {
                Label("Export STL", systemImage: "cube")
            }

            Button {
                Task { await viewModel.exportScan(scan, format: .obj) }
            } label: {
                Label("Export OBJ", systemImage: "cube.transparent")
            }

            Button {
                Task { await viewModel.exportScan(scan, format: .ply) }
            } label: {
                Label("Export PLY", systemImage: "point.3.filled.connected.trianglepath.dotted")
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(role: .destructive) {
            scanToDelete = scan
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Scan Grid Card
struct ScanGridCard: View {
    let scan: Scan3DModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .aspectRatio(1, contentMode: .fit)

                Image(systemName: scan.type.icon)
                    .font(.system(size: 40))
                    .foregroundColor(scan.type.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(scan.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Image(systemName: scan.type.icon)
                        .font(.caption2)
                    Text(scan.type.displayName)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)

                Text(scan.dateFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Scan List Row
struct ScanListRow: View {
    let scan: Scan3DModel

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(scan.type.color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: scan.type.icon)
                    .font(.title2)
                    .foregroundColor(scan.type.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(scan.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(scan.type.displayName)
                    Text("•")
                    Text(scan.fileSizeFormatted)
                    Text("•")
                    Text(scan.dateFormatted)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Scan Detail Sheet
struct ScanDetailSheet: View {
    let scan: Scan3DModel
    @ObservedObject var viewModel: GalleryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Preview Section
                Section {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray5))
                            .frame(height: 200)

                        VStack {
                            Image(systemName: scan.type.icon)
                                .font(.system(size: 60))
                                .foregroundColor(scan.type.color)

                            Text("3D Preview")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Info Section
                Section("Details") {
                    LabeledContent("Name", value: scan.name)
                    LabeledContent("Type", value: scan.type.displayName)
                    LabeledContent("Created", value: scan.dateFormatted)
                    LabeledContent("Vertices", value: scan.vertexCount.formattedWithSeparator)
                    LabeledContent("Faces", value: scan.faceCount.formattedWithSeparator)
                    LabeledContent("File Size", value: scan.fileSizeFormatted)
                    if let dims = scan.dimensionsFormatted {
                        LabeledContent("Dimensions", value: dims)
                    }
                }

                // Export Section
                Section("Export") {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button {
                            Task {
                                await viewModel.exportScan(scan, format: format)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text(format.displayName)
                                Spacer()
                                if format.supportsTexture && scan.vertexCount > 0 {
                                    Text("+ Texture")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Export History
                if !scan.exports.isEmpty {
                    Section("Export History") {
                        ForEach(scan.exports) { export in
                            HStack {
                                Text(export.format.rawValue)
                                    .font(.headline)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(export.exportedAt.timeAgoString)
                                    Text(export.fileSize.fileSizeFormatted)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteScan(scan)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Scan")
                        }
                    }
                }
            }
            .navigationTitle(scan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - View Model
@MainActor
class GalleryViewModel: ObservableObject {
    enum SortOption: String, CaseIterable {
        case dateNewest, dateOldest, name, type, size

        var displayName: String {
            switch self {
            case .dateNewest: return "Newest First"
            case .dateOldest: return "Oldest First"
            case .name: return "Name"
            case .type: return "Type"
            case .size: return "Size"
            }
        }
    }

    enum ViewMode {
        case grid, list
    }

    @Published var scans: [Scan3DModel] = []
    @Published var sortOption: SortOption = .dateNewest
    @Published var viewMode: ViewMode = .grid
    @Published var isLoading = false
    @Published var isExporting = false
    @Published var errorMessage: String?
    @Published var storageUsed: String = "Calculating..."
    @Published var showShareSheet = false
    @Published var exportedFileURL: URL?

    private let storageService = ScanStorageService.shared
    private let exportService = MeshExportService()

    func loadScans() async {
        isLoading = true
        do {
            scans = try await storageService.loadAllScans()
            applySorting()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func sortBy(_ option: SortOption) {
        sortOption = option
        applySorting()
    }

    func toggleViewMode() {
        viewMode = viewMode == .grid ? .list : .grid
    }

    func filteredScans(_ searchText: String) -> [Scan3DModel] {
        if searchText.isEmpty {
            return scans
        }
        return scans.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.type.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    func deleteScan(_ scan: Scan3DModel) async {
        do {
            try await storageService.deleteScan(scan)
            scans.removeAll { $0.id == scan.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameScan(_ scan: Scan3DModel, newName: String) async {
        guard !newName.isEmpty else { return }
        do {
            try await storageService.renameScan(scan, newName: newName)
            if let index = scans.firstIndex(where: { $0.id == scan.id }) {
                scans[index].name = newName
                scans[index].updatedAt = Date()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadStorageInfo() async {
        let bytes = await storageService.calculateStorageUsed()
        await MainActor.run {
            storageUsed = bytes.fileSizeFormatted
        }
    }

    func exportScan(_ scan: Scan3DModel, format: ExportFormat) async {
        // Check if mesh file exists
        guard let meshFileName = scan.meshFileName else {
            errorMessage = "No mesh file found for this scan"
            return
        }

        isExporting = true
        defer { isExporting = false }

        do {
            // Load the mesh from storage
            let mesh = try await storageService.loadMesh(fileName: meshFileName)

            // Export the mesh to the selected format
            let result = try await exportService.export(
                mesh: mesh,
                format: format,
                fileName: scan.name.sanitizedFileName
            )

            // Create export record with actual file info
            var updatedScan = scan
            let record = ExportRecord(
                format: format,
                fileName: result.fileURL.lastPathComponent,
                fileSize: result.fileSize
            )
            updatedScan.exports.append(record)
            updatedScan.updatedAt = Date()

            // Save updated scan metadata
            try await storageService.saveScan(updatedScan)

            // Update local state
            if let index = scans.firstIndex(where: { $0.id == scan.id }) {
                scans[index] = updatedScan
            }

            // Show share sheet with exported file
            exportedFileURL = result.fileURL
            showShareSheet = true

        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func applySorting() {
        switch sortOption {
        case .dateNewest:
            scans.sort { $0.createdAt > $1.createdAt }
        case .dateOldest:
            scans.sort { $0.createdAt < $1.createdAt }
        case .name:
            scans.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .type:
            scans.sort { $0.type.rawValue < $1.type.rawValue }
        case .size:
            scans.sort { $0.fileSize > $1.fileSize }
        }
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
    GalleryView()
}
