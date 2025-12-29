import Foundation
import UIKit
import Combine

/// Service for persisting and managing saved 3D scans
actor ScanStorageService {

    // MARK: - Singleton (Deprecated - use AppServices DI instead)
    @available(*, deprecated, message: "Use AppServices.storageService via EnvironmentObject instead")
    static let shared = ScanStorageService()

    // MARK: - Properties
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Directories
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var scansDirectory: URL {
        documentsDirectory.appendingPathComponent("Scans", isDirectory: true)
    }

    private var meshesDirectory: URL {
        documentsDirectory.appendingPathComponent("Meshes", isDirectory: true)
    }

    private var texturesDirectory: URL {
        documentsDirectory.appendingPathComponent("Textures", isDirectory: true)
    }

    private var thumbnailsDirectory: URL {
        documentsDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    private var exportsDirectory: URL {
        documentsDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    private var manifestURL: URL {
        scansDirectory.appendingPathComponent("manifest.json")
    }

    // MARK: - Initialization
    private init() {
        Task {
            await setupDirectories()
        }
    }

    private func setupDirectories() {
        let directories = [scansDirectory, meshesDirectory, texturesDirectory, thumbnailsDirectory, exportsDirectory]

        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - CRUD Operations

    /// Load all saved scans
    func loadAllScans() async throws -> [Scan3DModel] {
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return []
        }

        let data = try Data(contentsOf: manifestURL)
        return try decoder.decode([Scan3DModel].self, from: data)
    }

    /// Save a new scan
    func saveScan(_ scan: Scan3DModel) async throws {
        var scans = try await loadAllScans()

        // Update or append
        if let index = scans.firstIndex(where: { $0.id == scan.id }) {
            scans[index] = scan
        } else {
            scans.append(scan)
        }

        try await saveManifest(scans)
    }

    /// Delete a scan and its associated files
    func deleteScan(_ scan: Scan3DModel) async throws {
        var scans = try await loadAllScans()
        scans.removeAll { $0.id == scan.id }

        // Delete associated files
        if let meshFile = scan.meshFileName {
            try? fileManager.removeItem(at: meshesDirectory.appendingPathComponent(meshFile))
        }
        if let textureFile = scan.textureFileName {
            try? fileManager.removeItem(at: texturesDirectory.appendingPathComponent(textureFile))
        }
        if let thumbnailFile = scan.thumbnailFileName {
            try? fileManager.removeItem(at: thumbnailsDirectory.appendingPathComponent(thumbnailFile))
        }

        // Delete exports
        for export in scan.exports {
            try? fileManager.removeItem(at: exportsDirectory.appendingPathComponent(export.fileName))
        }

        try await saveManifest(scans)
    }

    /// Update scan name
    func renameScan(_ scan: Scan3DModel, newName: String) async throws {
        var updatedScan = scan
        updatedScan.name = newName
        updatedScan.updatedAt = Date()
        try await saveScan(updatedScan)
    }

    // MARK: - File Operations

    /// Save mesh data to file
    func saveMesh(_ mesh: CapturedMesh, for scan: Scan3DModel) async throws -> String {
        let fileName = "\(scan.id.uuidString)_mesh.bin"
        let fileURL = meshesDirectory.appendingPathComponent(fileName)

        // Serialize mesh data
        let meshData = try serializeMesh(mesh)
        try meshData.write(to: fileURL)

        return fileName
    }

    /// Load mesh data from file
    func loadMesh(fileName: String) async throws -> CapturedMesh {
        let fileURL = meshesDirectory.appendingPathComponent(fileName)
        let data = try Data(contentsOf: fileURL)
        return try deserializeMesh(data)
    }

    /// Save texture image
    func saveTexture(_ image: CGImage, for scan: Scan3DModel) async throws -> String {
        let fileName = "\(scan.id.uuidString)_texture.jpg"
        let fileURL = texturesDirectory.appendingPathComponent(fileName)

        guard let destination = CGImageDestinationCreateWithURL(
            fileURL as CFURL,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            throw StorageError.failedToSaveFile
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw StorageError.failedToSaveFile
        }

        return fileName
    }

    /// Save thumbnail image
    func saveThumbnail(_ image: UIImage, for scan: Scan3DModel) async throws -> String {
        let fileName = "\(scan.id.uuidString)_thumb.jpg"
        let fileURL = thumbnailsDirectory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw StorageError.failedToSaveFile
        }

        try data.write(to: fileURL)
        return fileName
    }

    /// Load thumbnail image
    func loadThumbnail(fileName: String) async -> UIImage? {
        let fileURL = thumbnailsDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    /// Get URL for exported file
    func getExportURL(for scan: Scan3DModel, format: ExportFormat) -> URL {
        let fileName = "\(scan.name.sanitizedFileName)_\(scan.id.uuidString.prefix(8)).\(format.fileExtension)"
        return exportsDirectory.appendingPathComponent(fileName)
    }

    // MARK: - Storage Info

    /// Calculate total storage used by scans
    func calculateStorageUsed() async -> Int64 {
        let directories = [scansDirectory, meshesDirectory, texturesDirectory, thumbnailsDirectory, exportsDirectory]
        var totalSize: Int64 = 0

        for directory in directories {
            if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(size)
                    }
                }
            }
        }

        return totalSize
    }

    /// Clear all cached exports
    func clearExportsCache() async throws {
        if fileManager.fileExists(atPath: exportsDirectory.path) {
            try fileManager.removeItem(at: exportsDirectory)
            try fileManager.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)
        }
    }

    /// Clear all data
    func clearAllData() async throws {
        let directories = [scansDirectory, meshesDirectory, texturesDirectory, thumbnailsDirectory, exportsDirectory]

        for directory in directories {
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
        }

        await setupDirectories()
    }

    // MARK: - Private Helpers

    private func saveManifest(_ scans: [Scan3DModel]) async throws {
        let data = try encoder.encode(scans)
        try data.write(to: manifestURL)
    }

    private func serializeMesh(_ mesh: CapturedMesh) throws -> Data {
        var data = Data()

        // Header
        var vertexCount = UInt32(mesh.vertices.count)
        var normalCount = UInt32(mesh.normals.count)
        var faceCount = UInt32(mesh.faces.count)
        var hasTexCoords: UInt8 = mesh.textureCoordinates != nil ? 1 : 0

        data.append(Data(bytes: &vertexCount, count: 4))
        data.append(Data(bytes: &normalCount, count: 4))
        data.append(Data(bytes: &faceCount, count: 4))
        data.append(Data(bytes: &hasTexCoords, count: 1))

        // Vertices
        for vertex in mesh.vertices {
            var v = vertex
            data.append(Data(bytes: &v, count: MemoryLayout<SIMD3<Float>>.size))
        }

        // Normals
        for normal in mesh.normals {
            var n = normal
            data.append(Data(bytes: &n, count: MemoryLayout<SIMD3<Float>>.size))
        }

        // Faces
        for face in mesh.faces {
            var indices = face.map { UInt32($0) }
            var count = UInt8(indices.count)
            data.append(Data(bytes: &count, count: 1))
            for i in 0..<indices.count {
                data.append(Data(bytes: &indices[i], count: 4))
            }
        }

        // Texture coordinates
        if let texCoords = mesh.textureCoordinates {
            for coord in texCoords {
                var c = coord
                data.append(Data(bytes: &c, count: MemoryLayout<SIMD2<Float>>.size))
            }
        }

        return data
    }

    private func deserializeMesh(_ data: Data) throws -> CapturedMesh {
        // Validate minimum header size (4 + 4 + 4 + 1 = 13 bytes)
        let headerSize = 13
        guard data.count >= headerSize else {
            throw StorageError.invalidData
        }

        var offset = 0

        // Read header
        let vertexCount = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
        offset += 4
        let normalCount = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
        offset += 4
        let faceCount = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
        offset += 4
        let hasTexCoords = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt8.self) }
        offset += 1

        // Validate data size before reading
        // Each vertex: 12 bytes (SIMD3<Float>), Each normal: 12 bytes
        // Faces: variable (1 byte count + 4 bytes per index)
        // Texture coords: 8 bytes each (SIMD2<Float>)
        let vertexDataSize = Int(vertexCount) * MemoryLayout<SIMD3<Float>>.size
        let normalDataSize = Int(normalCount) * MemoryLayout<SIMD3<Float>>.size
        let minExpectedSize = headerSize + vertexDataSize + normalDataSize

        guard data.count >= minExpectedSize else {
            throw StorageError.invalidData
        }

        // Validate counts are reasonable (prevent memory issues)
        let maxVertices: UInt32 = 10_000_000
        guard vertexCount <= maxVertices && normalCount <= maxVertices && faceCount <= maxVertices else {
            throw StorageError.invalidData
        }

        // Read vertices with bounds checking
        var vertices: [SIMD3<Float>] = []
        vertices.reserveCapacity(Int(vertexCount))
        for _ in 0..<vertexCount {
            guard offset + MemoryLayout<SIMD3<Float>>.size <= data.count else {
                throw StorageError.invalidData
            }
            let vertex = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: SIMD3<Float>.self) }
            vertices.append(vertex)
            offset += MemoryLayout<SIMD3<Float>>.size
        }

        // Read normals with bounds checking
        var normals: [SIMD3<Float>] = []
        normals.reserveCapacity(Int(normalCount))
        for _ in 0..<normalCount {
            guard offset + MemoryLayout<SIMD3<Float>>.size <= data.count else {
                throw StorageError.invalidData
            }
            let normal = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: SIMD3<Float>.self) }
            normals.append(normal)
            offset += MemoryLayout<SIMD3<Float>>.size
        }

        // Read faces with bounds checking
        var faces: [[Int]] = []
        faces.reserveCapacity(Int(faceCount))
        for _ in 0..<faceCount {
            guard offset + 1 <= data.count else {
                throw StorageError.invalidData
            }
            let count = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt8.self) }
            offset += 1

            guard offset + Int(count) * 4 <= data.count else {
                throw StorageError.invalidData
            }
            var indices: [Int] = []
            indices.reserveCapacity(Int(count))
            for _ in 0..<count {
                let index = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
                indices.append(Int(index))
                offset += 4
            }
            faces.append(indices)
        }

        // Read texture coordinates with bounds checking
        var texCoords: [SIMD2<Float>]? = nil
        if hasTexCoords == 1 {
            let texCoordsSize = Int(vertexCount) * MemoryLayout<SIMD2<Float>>.size
            guard offset + texCoordsSize <= data.count else {
                throw StorageError.invalidData
            }
            texCoords = []
            texCoords?.reserveCapacity(Int(vertexCount))
            for _ in 0..<vertexCount {
                let coord = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: SIMD2<Float>.self) }
                texCoords?.append(coord)
                offset += MemoryLayout<SIMD2<Float>>.size
            }
        }

        return CapturedMesh(
            vertices: vertices,
            normals: normals,
            faces: faces,
            textureCoordinates: texCoords,
            textureData: nil,
            scanMode: .face,
            captureDate: Date()
        )
    }

    // MARK: - Errors
    enum StorageError: Error, LocalizedError {
        case failedToSaveFile
        case failedToLoadFile
        case fileNotFound
        case invalidData

        var errorDescription: String? {
            switch self {
            case .failedToSaveFile: return "Failed to save file"
            case .failedToLoadFile: return "Failed to load file"
            case .fileNotFound: return "File not found"
            case .invalidData: return "Invalid data format"
            }
        }
    }
}

// MARK: - String Extension for File Names
extension String {
    var sanitizedFileName: String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}
