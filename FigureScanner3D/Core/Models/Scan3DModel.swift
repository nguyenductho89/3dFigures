import Foundation
import SwiftUI

/// Represents a saved 3D scan
struct Scan3DModel: Identifiable, Codable {
    let id: UUID
    var name: String
    let type: ScanType
    let createdAt: Date
    var updatedAt: Date

    // File references (stored as relative paths)
    var meshFileName: String?
    var textureFileName: String?
    var thumbnailFileName: String?

    // Mesh metadata
    var vertexCount: Int
    var faceCount: Int
    var fileSize: Int64
    var dimensions: ScanDimensions?

    // Export history
    var exports: [ExportRecord]

    init(
        id: UUID = UUID(),
        name: String,
        type: ScanType,
        createdAt: Date = Date(),
        vertexCount: Int = 0,
        faceCount: Int = 0,
        fileSize: Int64 = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.vertexCount = vertexCount
        self.faceCount = faceCount
        self.fileSize = fileSize
        self.exports = []
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var dimensionsFormatted: String? {
        guard let dims = dimensions else { return nil }
        return String(format: "%.1f × %.1f × %.1f cm",
                      dims.width * 100, dims.height * 100, dims.depth * 100)
    }
}

// MARK: - Scan Type
enum ScanType: String, Codable, CaseIterable {
    case face
    case body
    case bust

    var displayName: String {
        switch self {
        case .face: return "Face Scan"
        case .body: return "Body Scan"
        case .bust: return "Bust Scan"
        }
    }

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

    var scanMode: LiDARScanningService.ScanMode {
        switch self {
        case .face: return .face
        case .body: return .body
        case .bust: return .bust
        }
    }
}

// MARK: - Scan Dimensions
struct ScanDimensions: Codable {
    let width: Float   // meters
    let height: Float  // meters
    let depth: Float   // meters

    init(from simd: SIMD3<Float>) {
        self.width = simd.x
        self.height = simd.y
        self.depth = simd.z
    }

    init(width: Float, height: Float, depth: Float) {
        self.width = width
        self.height = height
        self.depth = depth
    }
}

// MARK: - Export Record
struct ExportRecord: Identifiable, Codable {
    let id: UUID
    let format: ExportFormat
    let exportedAt: Date
    let fileName: String
    let fileSize: Int64

    init(format: ExportFormat, fileName: String, fileSize: Int64) {
        self.id = UUID()
        self.format = format
        self.exportedAt = Date()
        self.fileName = fileName
        self.fileSize = fileSize
    }
}

// MARK: - Export Format
/// Type alias to use the unified ExportFormat from MeshExportService
typealias ExportFormat = MeshExportService.ExportFormat

// MARK: - Scan Status
enum ScanStatus {
    case ready
    case scanning
    case processing
    case completed
    case failed(Error)

    var isActive: Bool {
        switch self {
        case .scanning, .processing:
            return true
        default:
            return false
        }
    }
}
