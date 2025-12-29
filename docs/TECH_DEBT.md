# Technical Debt Backlog

> Last Updated: 2025-12-29 (P0 & P1 items completed)
>
> This document tracks technical debt items identified during code review.
> Each item has a unique ID for tracking and prioritization.

---

## Priority Legend

| Priority | Description |
|----------|-------------|
| **P0** | Critical - Bugs/Security issues, must fix immediately |
| **P1** | High - Performance/UX issues affecting users |
| **P2** | Medium - Code quality improvements |
| **P3** | Low - Nice-to-have improvements |

## Status Legend

| Status | Description |
|--------|-------------|
| `OPEN` | Not started |
| `IN_PROGRESS` | Currently being worked on |
| `DONE` | Completed |
| `WONTFIX` | Decided not to fix |

---

## P0 - Critical Issues

### TD-001: AppState LiDAR Check Not Functional

| Field | Value |
|-------|-------|
| **ID** | TD-001 |
| **Priority** | P0 |
| **Status** | DONE |
| **File** | `FigureScanner3DApp.swift:26-33` |
| **Category** | Bug |

**Description:**
The `checkDeviceCapabilities()` method always returns `true` for LiDAR support instead of actually checking device capabilities.

**Current Code:**
```swift
private func checkDeviceCapabilities() {
    if #available(iOS 16.0, *) {
        hasLiDAR = true // Placeholder - will be replaced with actual check
        isDeviceSupported = true
    }
}
```

**Proposed Fix:**
```swift
import ARKit

private func checkDeviceCapabilities() {
    hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    isDeviceSupported = hasLiDAR
}
```

**Impact:** App may crash or show incorrect UI on non-LiDAR devices.

---

### TD-002: Missing Data Validation in Mesh Deserialization

| Field | Value |
|-------|-------|
| **ID** | TD-002 |
| **Priority** | P0 |
| **Status** | DONE |
| **File** | `ScanStorageService.swift:284-347` |
| **Category** | Security/Stability |

**Description:**
The `deserializeMesh()` method reads data without validating buffer bounds, which can cause crashes with corrupted files.

**Current Code:**
```swift
private func deserializeMesh(_ data: Data) throws -> CapturedMesh {
    var offset = 0
    let vertexCount = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
    // No validation of data.count
```

**Proposed Fix:**
```swift
private func deserializeMesh(_ data: Data) throws -> CapturedMesh {
    let headerSize = 13 // 4 + 4 + 4 + 1 bytes
    guard data.count >= headerSize else {
        throw StorageError.invalidData
    }

    var offset = 0
    let vertexCount = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
    // ... read other header values

    let expectedSize = calculateExpectedSize(vertexCount: Int(vertexCount), normalCount: Int(normalCount), faceCount: Int(faceCount), hasTexCoords: hasTexCoords == 1)
    guard data.count >= expectedSize else {
        throw StorageError.invalidData
    }
    // Continue with deserialization
}
```

**Impact:** App crash when loading corrupted scan files.

---

### TD-003: Gallery Export Does Not Actually Export Files

| Field | Value |
|-------|-------|
| **ID** | TD-003 |
| **Priority** | P0 |
| **Status** | DONE |
| **File** | `GalleryView.swift:486-505` |
| **Category** | Bug |

**Description:**
The `exportScan()` method only creates an `ExportRecord` but doesn't actually export the mesh file.

**Current Code:**
```swift
func exportScan(_ scan: Scan3DModel, format: ExportFormat) async {
    // Export logic would go here
    // For now, we just record the export
    var updatedScan = scan
    let record = ExportRecord(
        format: format,
        fileName: "\(scan.name).\(format.fileExtension)",
        fileSize: scan.fileSize
    )
    updatedScan.exports.append(record)
    // ...
}
```

**Proposed Fix:**
```swift
func exportScan(_ scan: Scan3DModel, format: ExportFormat) async {
    do {
        // Load the mesh from storage
        guard let meshFileName = scan.meshFileName else {
            errorMessage = "No mesh file found"
            return
        }

        let mesh = try await storageService.loadMesh(fileName: meshFileName)

        // Export the mesh
        let result = try await exportService.export(
            mesh: mesh,
            format: format.meshExportFormat,
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

        try await storageService.saveScan(updatedScan)

        // Update local state
        if let index = scans.firstIndex(where: { $0.id == scan.id }) {
            scans[index] = updatedScan
        }

        // Share the file
        exportedFileURL = result.fileURL
        showShareSheet = true
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

**Impact:** Users cannot export their scans from Gallery.

---

### TD-004: Processed Mesh Not Saved After Processing

| Field | Value |
|-------|-------|
| **ID** | TD-004 |
| **Priority** | P0 |
| **Status** | DONE |
| **File** | `FaceScanView.swift:606-617` |
| **Category** | Bug |

**Description:**
After mesh processing completes, the result is discarded and not saved or used.

**Current Code:**
```swift
func stopScan() {
    scanState = .processing
    scanningService.stopScanning()

    Task {
        do {
            if let mesh = scanningService.capturedMesh {
                let _ = try await processingService.process(mesh)  // Result discarded!
            }
            scanState = .completed
            showCompletionAlert = true
        } catch {
            errorMessage = error.localizedDescription
            scanState = .ready
        }
    }
}
```

**Proposed Fix:**
```swift
@Published var processedMesh: MeshProcessingService.ProcessedMesh?

func stopScan() {
    scanState = .processing
    scanningService.stopScanning()

    Task {
        do {
            if let mesh = scanningService.capturedMesh {
                processedMesh = try await processingService.process(mesh)

                // Optionally save to storage
                let scan = Scan3DModel(name: "Face Scan", type: .face)
                try await saveScanToStorage(scan: scan, mesh: mesh, processed: processedMesh)
            }
            scanState = .completed
            showCompletionAlert = true
        } catch {
            errorMessage = error.localizedDescription
            scanState = .ready
        }
    }
}
```

**Impact:** All mesh processing work is wasted, raw mesh is used instead.

---

## P1 - High Priority

### TD-005: DateFormatter Created on Every Call

| Field | Value |
|-------|-------|
| **ID** | TD-005 |
| **Priority** | P1 |
| **Status** | DONE |
| **File** | `Extensions.swift:18-41` |
| **Category** | Performance |

**Description:**
DateFormatters are expensive to create. Currently, new formatters are created on every property access.

**Current Code:**
```swift
var timeAgoString: String {
    let formatter = RelativeDateTimeFormatter()  // Created every time
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: self, relativeTo: Date())
}
```

**Proposed Fix:**
```swift
extension Date {
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static let mediumDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var timeAgoString: String {
        Self.relativeFormatter.localizedString(for: self, relativeTo: Date())
    }

    var shortDateString: String {
        Self.shortDateFormatter.string(from: self)
    }

    var mediumDateTimeString: String {
        Self.mediumDateTimeFormatter.string(from: self)
    }
}
```

**Impact:** Performance degradation in Gallery view with many scans.

---

### TD-006: Mesh Processing Not Parallelized

| Field | Value |
|-------|-------|
| **ID** | TD-006 |
| **Priority** | P1 |
| **Status** | DONE |
| **File** | `MeshProcessingService.swift` |
| **Category** | Performance |

**Description:**
Mesh processing operations (smoothing, normal calculation, etc.) are single-threaded and don't utilize Accelerate framework or Metal compute.

**Proposed Fix:**
- Use `vDSP` for vector operations
- Use `DispatchQueue.concurrentPerform` for parallel iteration
- Consider Metal compute shaders for large meshes

**Impact:** Slow processing for large meshes (>100k vertices).

---

### TD-007: Adjacency List Rebuilt Multiple Times

| Field | Value |
|-------|-------|
| **ID** | TD-007 |
| **Priority** | P1 |
| **Status** | DONE |
| **File** | `MeshProcessingService.swift:127-139, 186-205, 325-337` |
| **Category** | Performance |

**Description:**
The same adjacency list structure is built independently in `removeNoiseWithMapping()`, `removeNoise()`, and `laplacianSmooth()`.

**Proposed Fix:**
```swift
private struct MeshTopology {
    let adjacency: [[Int]]
    let boundaryVertices: Set<Int>

    init(faces: [[Int]], vertexCount: Int) {
        var adj: [[Int]] = Array(repeating: [], count: vertexCount)
        for face in faces {
            for i in 0..<3 {
                let v1 = face[i]
                let v2 = face[(i + 1) % 3]
                if !adj[v1].contains(v2) { adj[v1].append(v2) }
                if !adj[v2].contains(v1) { adj[v2].append(v1) }
            }
        }
        self.adjacency = adj
        // ... compute boundary vertices
    }
}
```

**Impact:** ~3x redundant computation for mesh topology.

---

### TD-008: No Processing Progress Feedback

| Field | Value |
|-------|-------|
| **ID** | TD-008 |
| **Priority** | P1 |
| **Status** | DONE |
| **File** | `MeshProcessingService.swift`, `FaceScanView.swift` |
| **Category** | UX |

**Description:**
Users only see "Processing mesh..." with no indication of which step is running or progress percentage.

**Proposed Fix:**
```swift
enum ProcessingStep: String {
    case removingNoise = "Removing noise..."
    case fillingHoles = "Filling holes..."
    case smoothing = "Smoothing surface..."
    case calculatingNormals = "Calculating normals..."
    case decimating = "Optimizing mesh..."
    case generatingTexCoords = "Generating texture coordinates..."
}

protocol ProcessingProgressDelegate: AnyObject {
    func processingDidUpdate(step: ProcessingStep, progress: Float)
}
```

**Impact:** Poor user experience during long processing times.

---

### TD-009: USDZ Export Not Implemented

| Field | Value |
|-------|-------|
| **ID** | TD-009 |
| **Priority** | P1 |
| **Status** | DONE |
| **File** | `MeshExportService.swift:211-212` |
| **Category** | Feature Gap |

**Description:**
USDZ format is listed in the UI but throws `unsupportedFormat` when selected.

**Current Code:**
```swift
case .usdz:
    throw ExportError.unsupportedFormat  // USDZ requires SceneKit/RealityKit
```

**Proposed Fix (Option A - Implement):**
```swift
case .usdz:
    try await exportUSDZ(vertices: vertices, normals: normals, faces: mesh.faces, to: fileURL)
```

**Proposed Fix (Option B - Disable in UI):**
```swift
// In ExportOptionsView
ForEach(MeshExportService.ExportFormat.allCases.filter { $0 != .usdz }, id: \.self)
```

**Impact:** Users confused when USDZ export fails.

---

## P2 - Medium Priority

### TD-010: Duplicate ExportFormat Enum Definitions

| Field | Value |
|-------|-------|
| **ID** | TD-010 |
| **Priority** | P2 |
| **Status** | OPEN |
| **File** | `Scan3DModel.swift:140-171`, `MeshExportService.swift:12-39` |
| **Category** | Code Duplication |

**Description:**
Two separate `ExportFormat` enums exist with similar functionality, requiring conversion between them.

**Proposed Fix:**
Keep only `MeshExportService.ExportFormat` and update `Scan3DModel` to use it via typealias or direct import.

**Impact:** Code confusion and maintenance burden.

---

### TD-011: Singleton Pattern in Actor

| Field | Value |
|-------|-------|
| **ID** | TD-011 |
| **Priority** | P2 |
| **Status** | OPEN |
| **File** | `ScanStorageService.swift:8-9` |
| **Category** | Architecture |

**Description:**
Using singleton pattern with actors can lead to initialization race conditions.

**Proposed Fix:**
Use Dependency Injection:
```swift
@MainActor
final class AppDependencies: ObservableObject {
    let storageService: ScanStorageService
    let processingService: MeshProcessingService
    let exportService: MeshExportService

    init() {
        self.storageService = ScanStorageService()
        self.processingService = MeshProcessingService()
        self.exportService = MeshExportService()
    }
}

// In App
@StateObject private var dependencies = AppDependencies()
```

**Impact:** Potential race conditions, harder to test.

---

### TD-012: Silent Error Handling in setupDirectories

| Field | Value |
|-------|-------|
| **ID** | TD-012 |
| **Priority** | P2 |
| **Status** | OPEN |
| **File** | `ScanStorageService.swift:52-59` |
| **Category** | Error Handling |

**Description:**
Directory creation errors are silently ignored with `try?`.

**Current Code:**
```swift
private func setupDirectories() {
    for directory in directories {
        try? fileManager.createDirectory(...)  // Errors ignored
    }
}
```

**Proposed Fix:**
```swift
private func setupDirectories() async throws {
    for directory in directories {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            Logger.storage.error("Failed to create directory: \(directory.path), error: \(error)")
            throw StorageError.failedToCreateDirectory(directory.path)
        }
    }
}
```

**Impact:** Silent failures may cause issues later.

---

### TD-013: No Cancellation Support for Processing

| Field | Value |
|-------|-------|
| **ID** | TD-013 |
| **Priority** | P2 |
| **Status** | OPEN |
| **File** | `FaceScanView.swift`, `MeshProcessingService.swift` |
| **Category** | UX |

**Description:**
Users cannot cancel mesh processing once started.

**Proposed Fix:**
```swift
// In ViewModel
private var processingTask: Task<Void, Error>?

func stopScan() {
    scanState = .processing
    scanningService.stopScanning()

    processingTask = Task {
        // ... processing code
    }
}

func cancelProcessing() {
    processingTask?.cancel()
    scanState = .ready
}

// In MeshProcessingService
func process(_ mesh: CapturedMesh, options: ProcessingOptions) async throws -> ProcessedMesh {
    try Task.checkCancellation()
    // Step 1
    try Task.checkCancellation()
    // Step 2
    // ...
}
```

**Impact:** Users stuck waiting for long processing.

---

### TD-014: Missing Unit Tests

| Field | Value |
|-------|-------|
| **ID** | TD-014 |
| **Priority** | P2 |
| **Status** | OPEN |
| **File** | `FigureScanner3DTests/` |
| **Category** | Testing |

**Description:**
Test files exist but contain no actual tests.

**Proposed Tests:**
- `MeshProcessingServiceTests` - Test mesh algorithms
- `MeshExportServiceTests` - Test file format generation
- `ScanStorageServiceTests` - Test CRUD operations
- `Scan3DModelTests` - Test model encoding/decoding

**Impact:** No automated quality assurance.

---

### TD-015: Missing API Documentation

| Field | Value |
|-------|-------|
| **ID** | TD-015 |
| **Priority** | P2 |
| **Status** | OPEN |
| **File** | Multiple files |
| **Category** | Documentation |

**Description:**
Public APIs lack DocC documentation comments.

**Proposed Fix:**
Add documentation to all public methods:
```swift
/// Processes a captured mesh with optimization algorithms.
///
/// The processing pipeline includes:
/// 1. Noise removal - removes outlier vertices
/// 2. Hole filling - repairs small holes in the mesh
/// 3. Laplacian smoothing - smooths the surface
/// 4. Normal recalculation - computes proper shading normals
/// 5. Decimation - reduces vertex count (optional)
///
/// - Parameters:
///   - mesh: The raw captured mesh from LiDAR scanning
///   - options: Processing options including smoothing and decimation settings
/// - Returns: An optimized mesh ready for export
/// - Throws: `ProcessingError` if mesh data is invalid or processing fails
func process(_ mesh: CapturedMesh, options: ProcessingOptions) async throws -> ProcessedMesh
```

**Impact:** Harder for new developers to understand the codebase.

---

## P3 - Low Priority

### TD-016: Magic Numbers in Code

| Field | Value |
|-------|-------|
| **ID** | TD-016 |
| **Priority** | P3 |
| **Status** | OPEN |
| **File** | `LiDARScanningService.swift:49, 54-55` |
| **Category** | Code Quality |

**Description:**
Hard-coded values scattered throughout the code.

**Current Code:**
```swift
private let requiredAngles = 5
private let textureCaptureInterval: TimeInterval = 0.2
private let maxTextureFrames = 30
```

**Proposed Fix:**
```swift
struct ScanConfiguration {
    let requiredAngles: Int
    let textureCaptureInterval: TimeInterval
    let maxTextureFrames: Int
    let faceScanBounds: BoundingBox

    static let `default` = ScanConfiguration(
        requiredAngles: 5,
        textureCaptureInterval: 0.2,
        maxTextureFrames: 30,
        faceScanBounds: BoundingBox(
            min: SIMD3<Float>(-0.15, -0.20, -0.15),
            max: SIMD3<Float>(0.15, 0.15, 0.10)
        )
    )

    static let highQuality = ScanConfiguration(
        requiredAngles: 8,
        textureCaptureInterval: 0.1,
        maxTextureFrames: 60,
        faceScanBounds: ...
    )
}
```

**Impact:** Harder to adjust parameters, unclear meaning.

---

### TD-017: No iCloud Backup Support

| Field | Value |
|-------|-------|
| **ID** | TD-017 |
| **Priority** | P3 |
| **Status** | OPEN |
| **File** | `ScanStorageService.swift` |
| **Category** | Feature |

**Description:**
Scans are stored only locally and lost when app is deleted.

**Proposed Fix:**
Add iCloud sync option in Settings with CloudKit integration.

**Impact:** Users may lose their scans.

---

### TD-018: ShareSheet Not Defined

| Field | Value |
|-------|-------|
| **ID** | TD-018 |
| **Priority** | P3 |
| **Status** | DONE |
| **File** | `FaceScanView.swift:58-60` |
| **Category** | Missing Component |

**Description:**
`ShareSheet` view is referenced but not defined in the codebase.

**Proposed Fix:**
```swift
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

**Impact:** Compilation error if ShareSheet is not defined elsewhere.

---

## Summary

| Priority | Count | Status |
|----------|-------|--------|
| P0 - Critical | 4 | **All DONE** |
| P1 - High | 5 | **All DONE** |
| P2 - Medium | 6 | All OPEN |
| P3 - Low | 3 | 1 DONE, 2 OPEN |
| **Total** | **18** | **10 DONE** |

---

## Changelog

| Date | Author | Changes |
|------|--------|---------|
| 2025-12-29 | Code Review | Initial tech debt identification |
| 2025-12-29 | Claude Code | Completed P0 items (TD-001 to TD-004) |
| 2025-12-29 | Claude Code | Completed P1 items (TD-005 to TD-009) |
| 2025-12-29 | Claude Code | Fixed TD-018 (ShareSheet added in TD-003) |
