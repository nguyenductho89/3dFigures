import SwiftUI
import UniformTypeIdentifiers

/// Enhanced share/export view with multiple destination options
struct ShareExportView: View {
    let fileURL: URL
    let fileName: String

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var showFilePicker = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var savedLocation = ""

    var body: some View {
        NavigationStack {
            List {
                // File Info Section
                Section("File") {
                    HStack {
                        fileIcon
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fileName)
                                .font(.headline)
                            Text(fileURL.pathExtension.uppercased())
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let size = fileSize {
                                Text(size)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Quick Actions
                Section("Share To") {
                    // AirDrop & Share Sheet
                    Button {
                        showShareSheet = true
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Share")
                                Text("AirDrop, Messages, Mail, and more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                        }
                    }
                    .foregroundColor(.primary)

                    // Save to Files
                    Button {
                        showFilePicker = true
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Save to Files")
                                Text("iCloud Drive, On My iPhone, or other locations")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "folder")
                                .foregroundColor(.blue)
                        }
                    }
                    .foregroundColor(.primary)

                    // Copy to Clipboard (for file path)
                    Button {
                        copyFilePathToClipboard()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Copy File Path")
                                Text("Copy the file location to clipboard")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.blue)
                        }
                    }
                    .foregroundColor(.primary)
                }

                // Cloud Services
                Section {
                    cloudServiceRow(
                        name: "iCloud Drive",
                        icon: "icloud",
                        color: .blue
                    ) {
                        saveToICloudDrive()
                    }
                } header: {
                    Text("Cloud Storage")
                } footer: {
                    Text("Save directly to your cloud storage for easy access on other devices.")
                }
            }
            .navigationTitle("Export Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [fileURL])
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentExportPicker(fileURL: fileURL) { result in
                    switch result {
                    case .success(let url):
                        savedLocation = url.lastPathComponent
                        showSuccessAlert = true
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                }
            }
            .alert("Saved Successfully", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("File saved to \(savedLocation)")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - File Icon
    private var fileIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
                .frame(width: 50, height: 50)

            Image(systemName: iconForExtension)
                .font(.title2)
                .foregroundColor(.blue)
        }
    }

    private var iconForExtension: String {
        switch fileURL.pathExtension.lowercased() {
        case "stl": return "cube"
        case "obj": return "cube.transparent"
        case "ply": return "point.3.filled.connected.trianglepath.dotted"
        case "usdz": return "arkit"
        case "zip": return "doc.zipper"
        default: return "doc"
        }
    }

    private var fileSize: String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return size.fileSizeFormatted
    }

    // MARK: - Cloud Service Row
    private func cloudServiceRow(
        name: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(name)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(color)
            }
        }
        .foregroundColor(.primary)
    }

    // MARK: - Actions
    private func copyFilePathToClipboard() {
        UIPasteboard.general.string = fileURL.path
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func saveToICloudDrive() {
        // Trigger the file picker with iCloud as default
        showFilePicker = true
    }
}

// MARK: - Document Export Picker
struct DocumentExportPicker: UIViewControllerRepresentable {
    let fileURL: URL
    let completion: (Result<URL, Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (Result<URL, Error>) -> Void

        init(completion: @escaping (Result<URL, Error>) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                completion(.success(url))
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // User cancelled - no action needed
        }
    }
}

// MARK: - Document Import Picker (for future use)
struct DocumentImportPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let completion: (Result<URL, Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (Result<URL, Error>) -> Void

        init(completion: @escaping (Result<URL, Error>) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                completion(.failure(DocumentPickerError.accessDenied))
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            completion(.success(url))
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // User cancelled
        }
    }

    enum DocumentPickerError: LocalizedError {
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .accessDenied: return "Could not access the selected file"
            }
        }
    }
}

#Preview {
    ShareExportView(
        fileURL: URL(fileURLWithPath: "/tmp/test.stl"),
        fileName: "FaceScan_2024"
    )
}
