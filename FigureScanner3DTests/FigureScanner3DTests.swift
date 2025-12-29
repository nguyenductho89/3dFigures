import XCTest
@testable import FigureScanner3D

// MARK: - Scan3DModel Tests
final class Scan3DModelTests: XCTestCase {

    func testScanTypeProperties() throws {
        // Test display names
        XCTAssertEqual(ScanType.face.displayName, "Face")
        XCTAssertEqual(ScanType.body.displayName, "Body")
        XCTAssertEqual(ScanType.bust.displayName, "Bust")

        // Test icons
        XCTAssertEqual(ScanType.face.icon, "face.smiling")
        XCTAssertEqual(ScanType.body.icon, "figure.stand")
        XCTAssertEqual(ScanType.bust.icon, "person.bust")
    }

    func testScan3DModelInitialization() throws {
        let scan = Scan3DModel(
            name: "Test Scan",
            type: .face,
            vertexCount: 1000,
            faceCount: 500
        )

        XCTAssertEqual(scan.name, "Test Scan")
        XCTAssertEqual(scan.type, .face)
        XCTAssertEqual(scan.vertexCount, 1000)
        XCTAssertEqual(scan.faceCount, 500)
        XCTAssertNotNil(scan.id)
        XCTAssertNotNil(scan.createdAt)
    }

    func testScanDimensions() throws {
        let dims = ScanDimensions(width: 0.1, height: 0.2, depth: 0.15)

        XCTAssertEqual(dims.width, 0.1, accuracy: 0.001)
        XCTAssertEqual(dims.height, 0.2, accuracy: 0.001)
        XCTAssertEqual(dims.depth, 0.15, accuracy: 0.001)
    }

    func testExportRecord() throws {
        let record = ExportRecord(
            format: .stl,
            fileName: "test.stl",
            fileSize: 1024
        )

        XCTAssertEqual(record.format, .stl)
        XCTAssertEqual(record.fileName, "test.stl")
        XCTAssertEqual(record.fileSize, 1024)
        XCTAssertNotNil(record.id)
        XCTAssertNotNil(record.exportedAt)
    }

    func testFileSizeFormatted() throws {
        var scan = Scan3DModel(name: "Test", type: .face)
        scan.fileSize = 1024

        XCTAssertFalse(scan.fileSizeFormatted.isEmpty)
    }

    func testDateFormatted() throws {
        let scan = Scan3DModel(name: "Test", type: .face)

        XCTAssertFalse(scan.dateFormatted.isEmpty)
    }
}

// MARK: - ExportFormat Tests
final class ExportFormatTests: XCTestCase {

    func testExportFormatProperties() throws {
        // Test file extensions
        XCTAssertEqual(ExportFormat.stl.fileExtension, "stl")
        XCTAssertEqual(ExportFormat.obj.fileExtension, "obj")
        XCTAssertEqual(ExportFormat.ply.fileExtension, "ply")
        XCTAssertEqual(ExportFormat.usdz.fileExtension, "usdz")
    }

    func testExportFormatDisplayNames() throws {
        XCTAssertEqual(ExportFormat.stl.displayName, "STL (3D Printing)")
        XCTAssertEqual(ExportFormat.obj.displayName, "OBJ (with Texture)")
        XCTAssertEqual(ExportFormat.ply.displayName, "PLY (Point Cloud)")
        XCTAssertEqual(ExportFormat.usdz.displayName, "USDZ (AR Quick Look)")
    }

    func testSupportedFormats() throws {
        let supported = ExportFormat.supportedFormats

        XCTAssertTrue(supported.contains(.stl))
        XCTAssertTrue(supported.contains(.obj))
        XCTAssertTrue(supported.contains(.ply))
        XCTAssertFalse(supported.contains(.usdz)) // USDZ not yet supported
    }

    func testSupportsTexture() throws {
        XCTAssertFalse(ExportFormat.stl.supportsTexture)
        XCTAssertTrue(ExportFormat.obj.supportsTexture)
        XCTAssertFalse(ExportFormat.ply.supportsTexture)
        XCTAssertTrue(ExportFormat.usdz.supportsTexture)
    }

    func testExportFormatCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = ExportFormat.stl
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ExportFormat.self, from: data)

        XCTAssertEqual(original, decoded)
    }
}

// MARK: - Extensions Tests
final class ExtensionsTests: XCTestCase {

    func testDateTimeAgoString() throws {
        let date = Date()
        let result = date.timeAgoString

        XCTAssertFalse(result.isEmpty)
    }

    func testDateShortDateString() throws {
        let date = Date()
        let result = date.shortDateString

        XCTAssertFalse(result.isEmpty)
    }

    func testIntFormattedWithSeparator() throws {
        let number = 1000000
        let formatted = number.formattedWithSeparator

        XCTAssertTrue(formatted.contains(",") || formatted.contains(" ") || formatted.contains("."))
    }

    func testInt64FileSizeFormatted() throws {
        let size: Int64 = 1024
        let formatted = size.fileSizeFormatted

        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.lowercased().contains("kb") || formatted.lowercased().contains("bytes"))
    }

    func testFloatClamped() throws {
        let value: Float = 1.5
        let clamped = value.clamped(to: 0.0...1.0)

        XCTAssertEqual(clamped, 1.0, accuracy: 0.001)
    }

    func testFloatDegreesToRadians() throws {
        let degrees: Float = 180.0
        let radians = degrees.degreesToRadians

        XCTAssertEqual(radians, .pi, accuracy: 0.001)
    }

    func testFloatRadiansToDegrees() throws {
        let radians: Float = .pi
        let degrees = radians.radiansToDegrees

        XCTAssertEqual(degrees, 180.0, accuracy: 0.001)
    }

    func testSIMD3Length() throws {
        let vector = SIMD3<Float>(3, 4, 0)
        let length = vector.length

        XCTAssertEqual(length, 5.0, accuracy: 0.001)
    }

    func testSIMD3Normalized() throws {
        let vector = SIMD3<Float>(3, 4, 0)
        let normalized = vector.normalized

        XCTAssertEqual(normalized.length, 1.0, accuracy: 0.001)
    }

    func testArrayCentroid() throws {
        let points: [SIMD3<Float>] = [
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(2, 0, 0),
            SIMD3<Float>(0, 2, 0)
        ]
        let centroid = points.centroid

        XCTAssertEqual(centroid.x, 2.0/3.0, accuracy: 0.001)
        XCTAssertEqual(centroid.y, 2.0/3.0, accuracy: 0.001)
        XCTAssertEqual(centroid.z, 0.0, accuracy: 0.001)
    }

    func testArrayBoundingBox() throws {
        let points: [SIMD3<Float>] = [
            SIMD3<Float>(-1, -2, -3),
            SIMD3<Float>(4, 5, 6)
        ]
        let bounds = points.boundingBox

        XCTAssertEqual(bounds.min.x, -1.0, accuracy: 0.001)
        XCTAssertEqual(bounds.min.y, -2.0, accuracy: 0.001)
        XCTAssertEqual(bounds.min.z, -3.0, accuracy: 0.001)
        XCTAssertEqual(bounds.max.x, 4.0, accuracy: 0.001)
        XCTAssertEqual(bounds.max.y, 5.0, accuracy: 0.001)
        XCTAssertEqual(bounds.max.z, 6.0, accuracy: 0.001)
    }

    func testStringSanitizedFileName() throws {
        let name = "Test:File/Name?.stl"
        let sanitized = name.sanitizedFileName

        XCTAssertFalse(sanitized.contains(":"))
        XCTAssertFalse(sanitized.contains("/"))
        XCTAssertFalse(sanitized.contains("?"))
    }

    func testArrayChunked() throws {
        let array = [1, 2, 3, 4, 5]
        let chunks = array.chunked(into: 2)

        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], [1, 2])
        XCTAssertEqual(chunks[1], [3, 4])
        XCTAssertEqual(chunks[2], [5])
    }
}

// MARK: - MeshProcessingService Tests
final class MeshProcessingServiceTests: XCTestCase {

    func testProcessingStepProgress() throws {
        // Verify progress values are in order
        let steps = MeshProcessingService.ProcessingStep.allCases
        var lastProgress: Float = -1

        for step in steps {
            XCTAssertGreaterThan(step.progress, lastProgress)
            lastProgress = step.progress
        }

        // Verify progress is between 0 and 1
        for step in steps {
            XCTAssertGreaterThanOrEqual(step.progress, 0.0)
            XCTAssertLessThanOrEqual(step.progress, 1.0)
        }
    }

    func testProcessingOptions() throws {
        let options = MeshProcessingService.ProcessingOptions()

        XCTAssertEqual(options.smoothingIterations, 3)
        XCTAssertEqual(options.smoothingFactor, 0.5, accuracy: 0.001)
        XCTAssertEqual(options.decimationRatio, 0.5, accuracy: 0.001)
        XCTAssertTrue(options.fillHoles)
        XCTAssertTrue(options.removeNoise)
        XCTAssertEqual(options.noiseThreshold, 0.002, accuracy: 0.0001)
    }
}

// MARK: - MeshExportService Tests
final class MeshExportServiceTests: XCTestCase {

    func testExportOptions() throws {
        let options = MeshExportService.ExportOptions()

        XCTAssertEqual(options.scale, 1.0, accuracy: 0.001)
        XCTAssertTrue(options.centerMesh)
        XCTAssertTrue(options.binary)
        XCTAssertTrue(options.includeNormals)
        XCTAssertTrue(options.includeTextureCoords)
        XCTAssertTrue(options.includeTexture)
        XCTAssertEqual(options.textureResolution, 2048)
        XCTAssertFalse(options.createZipArchive)
    }

    func testExportFormatMimeTypes() throws {
        XCTAssertEqual(ExportFormat.stl.mimeType, "model/stl")
        XCTAssertEqual(ExportFormat.obj.mimeType, "model/obj")
        XCTAssertEqual(ExportFormat.ply.mimeType, "model/ply")
        XCTAssertEqual(ExportFormat.usdz.mimeType, "model/vnd.usdz+zip")
    }
}

// MARK: - Storage Error Tests
final class StorageErrorTests: XCTestCase {

    func testErrorDescriptions() throws {
        let errors: [ScanStorageService.StorageError] = [
            .failedToSaveFile,
            .failedToLoadFile,
            .fileNotFound,
            .invalidData,
            .directoryCreationFailed("TestDir")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testDirectoryCreationFailedIncludesName() throws {
        let error = ScanStorageService.StorageError.directoryCreationFailed("Meshes")
        XCTAssertTrue(error.errorDescription!.contains("Meshes"))
    }
}
