import SwiftUI

struct GalleryView: View {
    @StateObject private var viewModel = GalleryViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.scans.isEmpty {
                    emptyState
                } else {
                    scanGrid
                }
            }
            .navigationTitle("Gallery")
            .searchable(text: $searchText, prompt: "Search scans")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Date", action: { viewModel.sortBy(.date) })
                        Button("Name", action: { viewModel.sortBy(.name) })
                        Button("Type", action: { viewModel.sortBy(.type) })
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
    }

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

    private var scanGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(viewModel.filteredScans(searchText)) { scan in
                    ScanCard(scan: scan)
                }
            }
            .padding()
        }
    }
}

// MARK: - Scan Card
struct ScanCard: View {
    let scan: Scan3D

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

                Text(scan.dateFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - View Model
@MainActor
class GalleryViewModel: ObservableObject {
    enum SortOption {
        case date, name, type
    }

    @Published var scans: [Scan3D] = []
    @Published var sortOption: SortOption = .date

    func sortBy(_ option: SortOption) {
        sortOption = option
        switch option {
        case .date:
            scans.sort { $0.createdAt > $1.createdAt }
        case .name:
            scans.sort { $0.name < $1.name }
        case .type:
            scans.sort { $0.type.rawValue < $1.type.rawValue }
        }
    }

    func filteredScans(_ searchText: String) -> [Scan3D] {
        if searchText.isEmpty {
            return scans
        }
        return scans.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - Models
struct Scan3D: Identifiable {
    let id = UUID()
    var name: String
    let type: ScanType
    let createdAt: Date
    var thumbnailData: Data?
    var meshURL: URL?

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

enum ScanType: String {
    case face, body, bust

    var icon: String {
        switch self {
        case .face: return "face.smiling"
        case .body: return "figure.stand"
        case .bust: return "person.bust"
        }
    }

    var color: Color {
        switch self {
        case .face: return .blue
        case .body: return .green
        case .bust: return .purple
        }
    }
}

#Preview {
    GalleryView()
}
