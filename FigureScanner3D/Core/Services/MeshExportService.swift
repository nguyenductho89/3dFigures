import Foundation
import simd
import UniformTypeIdentifiers
import CoreImage
import ImageIO
import Compression

/// Service for exporting 3D meshes to various file formats
actor MeshExportService {

    // MARK: - Export Format
    enum ExportFormat: String, CaseIterable {
        case stl = "STL"
        case obj = "OBJ"
        case ply = "PLY"
        case usdz = "USDZ"

        /// Formats that are currently implemented and supported for export
        static var supportedFormats: [ExportFormat] {
            [.stl, .obj, .ply]  // USDZ requires SceneKit/RealityKit integration (not yet implemented)
        }

        var fileExtension: String {
            rawValue.lowercased()
        }

        var mimeType: String {
            switch self {
            case .stl: return "model/stl"
            case .obj: return "model/obj"
            case .ply: return "model/ply"
            case .usdz: return "model/vnd.usdz+zip"
            }
        }

        var utType: UTType {
            switch self {
            case .stl: return UTType(filenameExtension: "stl") ?? .data
            case .obj: return UTType(filenameExtension: "obj") ?? .data
            case .ply: return UTType(filenameExtension: "ply") ?? .data
            case .usdz: return .usdz
            }
        }

        var isSupported: Bool {
            Self.supportedFormats.contains(self)
        }
    }

    // MARK: - Export Options
    struct ExportOptions {
        var scale: Float = 1.0
        var centerMesh: Bool = true
        var binary: Bool = true  // For STL and PLY
        var includeNormals: Bool = true
        var includeTextureCoords: Bool = true
        var includeTexture: Bool = true
        var textureResolution: Int = 2048
        var createZipArchive: Bool = false
    }

    // MARK: - Export Result
    struct ExportResult {
        let fileURL: URL
        let format: ExportFormat
        let fileSize: Int64
        let vertexCount: Int
        let faceCount: Int
        let textureURL: URL?      // Texture image file (if exported)
        let materialURL: URL?     // MTL file (for OBJ format)
        let isZipArchive: Bool
        let additionalFiles: [URL]

        init(fileURL: URL, format: ExportFormat, fileSize: Int64, vertexCount: Int, faceCount: Int,
             textureURL: URL? = nil, materialURL: URL? = nil, isZipArchive: Bool = false, additionalFiles: [URL] = []) {
            self.fileURL = fileURL
            self.format = format
            self.fileSize = fileSize
            self.vertexCount = vertexCount
            self.faceCount = faceCount
            self.textureURL = textureURL
            self.materialURL = materialURL
            self.isZipArchive = isZipArchive
            self.additionalFiles = additionalFiles
        }
    }

    // MARK: - Errors
    enum ExportError: Error, LocalizedError {
        case noMeshData
        case invalidFormat
        case writeFailed(String)
        case unsupportedFormat
        case zipCreationFailed(String)

        var errorDescription: String? {
            switch self {
            case .noMeshData: return "No mesh data available"
            case .invalidFormat: return "Invalid export format"
            case .writeFailed(let reason): return "Failed to write file: \(reason)"
            case .unsupportedFormat: return "Export format not supported"
            case .zipCreationFailed(let reason): return "Failed to create ZIP archive: \(reason)"
            }
        }
    }

    // MARK: - Public Methods

    /// Export mesh to specified format
    func export(
        mesh: MeshProcessingService.ProcessedMesh,
        format: ExportFormat,
        fileName: String,
        options: ExportOptions = ExportOptions()
    ) async throws -> ExportResult {
        guard mesh.vertexCount > 0 else {
            throw ExportError.noMeshData
        }

        // Apply transformations
        var vertices = mesh.vertices
        var normals = mesh.normals

        // Center mesh
        if options.centerMesh {
            let center = calculateCenter(vertices: vertices)
            vertices = vertices.map { $0 - center }
        }

        // Apply scale
        if options.scale != 1.0 {
            vertices = vertices.map { $0 * options.scale }
        }

        // Create export directory
        let exportDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Exports", isDirectory: true)

        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let fileURL = exportDir.appendingPathComponent("\(fileName).\(format.fileExtension)")

        var textureURL: URL? = nil
        var materialURL: URL? = nil

        // Export based on format
        switch format {
        case .stl:
            try await exportSTL(
                vertices: vertices,
                normals: normals,
                faces: mesh.faces,
                to: fileURL,
                binary: options.binary
            )
        case .obj:
            // Export texture if available
            if options.includeTexture, let textureData = mesh.textureData, let atlasImage = textureData.atlasImage {
                textureURL = exportDir.appendingPathComponent("\(fileName)_texture.jpg")

                // Resize texture if needed
                let resizedImage = resizeImage(atlasImage, to: options.textureResolution)
                try await exportTextureImage(resizedImage ?? atlasImage, to: textureURL!)

                // Export MTL file
                materialURL = exportDir.appendingPathComponent("\(fileName).mtl")
                try await exportMTL(
                    textureName: "\(fileName)_texture.jpg",
                    to: materialURL!
                )
            }

            try await exportOBJ(
                vertices: vertices,
                normals: normals,
                faces: mesh.faces,
                textureCoords: options.includeTextureCoords ? mesh.textureCoordinates : nil,
                materialName: materialURL != nil ? fileName : nil,
                to: fileURL
            )

            // Create ZIP archive if requested
            if options.createZipArchive && (textureURL != nil || materialURL != nil) {
                var filesToZip: [URL] = [fileURL]
                if let mtlURL = materialURL { filesToZip.append(mtlURL) }
                if let texURL = textureURL { filesToZip.append(texURL) }

                let zipURL = exportDir.appendingPathComponent("\(fileName).zip")
                try await createZipArchive(from: filesToZip, to: zipURL)

                // Clean up individual files
                for file in filesToZip {
                    try? FileManager.default.removeItem(at: file)
                }

                // Get ZIP file size
                let zipAttributes = try FileManager.default.attributesOfItem(atPath: zipURL.path)
                let zipFileSize = zipAttributes[.size] as? Int64 ?? 0

                return ExportResult(
                    fileURL: zipURL,
                    format: format,
                    fileSize: zipFileSize,
                    vertexCount: vertices.count,
                    faceCount: mesh.faceCount,
                    textureURL: nil,
                    materialURL: nil,
                    isZipArchive: true,
                    additionalFiles: []
                )
            }
        case .ply:
            try await exportPLY(
                vertices: vertices,
                normals: options.includeNormals ? normals : nil,
                faces: mesh.faces,
                to: fileURL,
                binary: options.binary
            )
        case .usdz:
            throw ExportError.unsupportedFormat  // USDZ requires SceneKit/RealityKit
        }

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        return ExportResult(
            fileURL: fileURL,
            format: format,
            fileSize: fileSize,
            vertexCount: vertices.count,
            faceCount: mesh.faceCount,
            textureURL: textureURL,
            materialURL: materialURL
        )
    }

    /// Export to CapturedMesh (before processing)
    func export(
        mesh: CapturedMesh,
        format: ExportFormat,
        fileName: String,
        options: ExportOptions = ExportOptions()
    ) async throws -> ExportResult {
        let processed = MeshProcessingService.ProcessedMesh(
            vertices: mesh.vertices,
            normals: mesh.normals,
            faces: mesh.faces,
            textureCoordinates: mesh.textureCoordinates,
            textureData: mesh.textureData
        )
        return try await export(mesh: processed, format: format, fileName: fileName, options: options)
    }

    // MARK: - STL Export

    private func exportSTL(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        faces: [[Int]],
        to url: URL,
        binary: Bool
    ) async throws {
        if binary {
            try await exportSTLBinary(vertices: vertices, normals: normals, faces: faces, to: url)
        } else {
            try await exportSTLASCII(vertices: vertices, normals: normals, faces: faces, to: url)
        }
    }

    private func exportSTLBinary(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        faces: [[Int]],
        to url: URL
    ) async throws {
        var data = Data()

        // Header (80 bytes)
        let header = "Binary STL exported from 3D Figure Scanner".padding(toLength: 80, withPad: " ", startingAt: 0)
        data.append(contentsOf: header.utf8.prefix(80))
        if data.count < 80 {
            data.append(contentsOf: [UInt8](repeating: 0, count: 80 - data.count))
        }

        // Number of triangles (4 bytes)
        var triangleCount = UInt32(faces.count)
        data.append(Data(bytes: &triangleCount, count: 4))

        // Triangles
        for face in faces {
            guard face.count >= 3 else { continue }

            let v0 = vertices[face[0]]
            let v1 = vertices[face[1]]
            let v2 = vertices[face[2]]

            // Calculate face normal
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            var normal = normalize(cross(edge1, edge2))

            // Normal (12 bytes)
            data.append(Data(bytes: &normal.x, count: 4))
            data.append(Data(bytes: &normal.y, count: 4))
            data.append(Data(bytes: &normal.z, count: 4))

            // Vertices (36 bytes)
            var vertex0 = v0
            var vertex1 = v1
            var vertex2 = v2
            data.append(Data(bytes: &vertex0.x, count: 4))
            data.append(Data(bytes: &vertex0.y, count: 4))
            data.append(Data(bytes: &vertex0.z, count: 4))
            data.append(Data(bytes: &vertex1.x, count: 4))
            data.append(Data(bytes: &vertex1.y, count: 4))
            data.append(Data(bytes: &vertex1.z, count: 4))
            data.append(Data(bytes: &vertex2.x, count: 4))
            data.append(Data(bytes: &vertex2.y, count: 4))
            data.append(Data(bytes: &vertex2.z, count: 4))

            // Attribute byte count (2 bytes)
            var attrByteCount: UInt16 = 0
            data.append(Data(bytes: &attrByteCount, count: 2))
        }

        try data.write(to: url)
    }

    private func exportSTLASCII(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        faces: [[Int]],
        to url: URL
    ) async throws {
        var content = "solid mesh\n"

        for face in faces {
            guard face.count >= 3 else { continue }

            let v0 = vertices[face[0]]
            let v1 = vertices[face[1]]
            let v2 = vertices[face[2]]

            // Calculate face normal
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let normal = normalize(cross(edge1, edge2))

            content += "  facet normal \(normal.x) \(normal.y) \(normal.z)\n"
            content += "    outer loop\n"
            content += "      vertex \(v0.x) \(v0.y) \(v0.z)\n"
            content += "      vertex \(v1.x) \(v1.y) \(v1.z)\n"
            content += "      vertex \(v2.x) \(v2.y) \(v2.z)\n"
            content += "    endloop\n"
            content += "  endfacet\n"
        }

        content += "endsolid mesh\n"

        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - OBJ Export

    private func exportOBJ(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        faces: [[Int]],
        textureCoords: [SIMD2<Float>]?,
        materialName: String?,
        to url: URL
    ) async throws {
        var content = "# OBJ file exported from 3D Figure Scanner\n"
        content += "# Vertices: \(vertices.count)\n"
        content += "# Faces: \(faces.count)\n\n"

        // Material library reference
        if let matName = materialName {
            content += "mtllib \(matName).mtl\n\n"
        }

        // Vertices
        for v in vertices {
            content += "v \(v.x) \(v.y) \(v.z)\n"
        }
        content += "\n"

        // Texture coordinates
        if let texCoords = textureCoords {
            for t in texCoords {
                content += "vt \(t.x) \(t.y)\n"
            }
            content += "\n"
        }

        // Normals
        for n in normals {
            content += "vn \(n.x) \(n.y) \(n.z)\n"
        }
        content += "\n"

        // Use material
        if materialName != nil {
            content += "usemtl material0\n"
        }

        // Faces (OBJ uses 1-based indexing)
        for face in faces {
            guard face.count >= 3 else { continue }

            if textureCoords != nil {
                // v/vt/vn format
                content += "f"
                for i in face {
                    content += " \(i + 1)/\(i + 1)/\(i + 1)"
                }
                content += "\n"
            } else {
                // v//vn format
                content += "f"
                for i in face {
                    content += " \(i + 1)//\(i + 1)"
                }
                content += "\n"
            }
        }

        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - MTL Export

    private func exportMTL(
        textureName: String,
        to url: URL
    ) async throws {
        var content = "# MTL file exported from 3D Figure Scanner\n\n"
        content += "newmtl material0\n"
        content += "Ka 0.2 0.2 0.2\n"        // Ambient color
        content += "Kd 0.8 0.8 0.8\n"        // Diffuse color
        content += "Ks 0.0 0.0 0.0\n"        // Specular color
        content += "Ns 0.0\n"                 // Specular exponent
        content += "d 1.0\n"                  // Opacity
        content += "illum 1\n"                // Illumination model
        content += "map_Kd \(textureName)\n" // Diffuse texture map

        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Texture Image Export

    private func exportTextureImage(_ image: CGImage, to url: URL) async throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ExportError.writeFailed("Could not create image destination")
        }

        // JPEG quality settings
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.85
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.writeFailed("Could not finalize image export")
        }
    }

    // MARK: - PLY Export

    private func exportPLY(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>]?,
        faces: [[Int]],
        to url: URL,
        binary: Bool
    ) async throws {
        if binary {
            try await exportPLYBinary(vertices: vertices, normals: normals, faces: faces, to: url)
        } else {
            try await exportPLYASCII(vertices: vertices, normals: normals, faces: faces, to: url)
        }
    }

    private func exportPLYASCII(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>]?,
        faces: [[Int]],
        to url: URL
    ) async throws {
        var content = "ply\n"
        content += "format ascii 1.0\n"
        content += "comment Exported from 3D Figure Scanner\n"
        content += "element vertex \(vertices.count)\n"
        content += "property float x\n"
        content += "property float y\n"
        content += "property float z\n"

        if normals != nil {
            content += "property float nx\n"
            content += "property float ny\n"
            content += "property float nz\n"
        }

        content += "element face \(faces.count)\n"
        content += "property list uchar int vertex_indices\n"
        content += "end_header\n"

        // Vertices
        for (i, v) in vertices.enumerated() {
            if let n = normals, i < n.count {
                content += "\(v.x) \(v.y) \(v.z) \(n[i].x) \(n[i].y) \(n[i].z)\n"
            } else {
                content += "\(v.x) \(v.y) \(v.z)\n"
            }
        }

        // Faces
        for face in faces {
            content += "\(face.count)"
            for i in face {
                content += " \(i)"
            }
            content += "\n"
        }

        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func exportPLYBinary(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>]?,
        faces: [[Int]],
        to url: URL
    ) async throws {
        var header = "ply\n"
        header += "format binary_little_endian 1.0\n"
        header += "comment Exported from 3D Figure Scanner\n"
        header += "element vertex \(vertices.count)\n"
        header += "property float x\n"
        header += "property float y\n"
        header += "property float z\n"

        if normals != nil {
            header += "property float nx\n"
            header += "property float ny\n"
            header += "property float nz\n"
        }

        header += "element face \(faces.count)\n"
        header += "property list uchar int vertex_indices\n"
        header += "end_header\n"

        var data = Data(header.utf8)

        // Vertices
        for (i, v) in vertices.enumerated() {
            var x = v.x, y = v.y, z = v.z
            data.append(Data(bytes: &x, count: 4))
            data.append(Data(bytes: &y, count: 4))
            data.append(Data(bytes: &z, count: 4))

            if let n = normals, i < n.count {
                var nx = n[i].x, ny = n[i].y, nz = n[i].z
                data.append(Data(bytes: &nx, count: 4))
                data.append(Data(bytes: &ny, count: 4))
                data.append(Data(bytes: &nz, count: 4))
            }
        }

        // Faces
        for face in faces {
            var count = UInt8(face.count)
            data.append(Data(bytes: &count, count: 1))
            for i in face {
                var index = Int32(i)
                data.append(Data(bytes: &index, count: 4))
            }
        }

        try data.write(to: url)
    }

    // MARK: - Helper Methods

    private func calculateCenter(vertices: [SIMD3<Float>]) -> SIMD3<Float> {
        guard !vertices.isEmpty else { return .zero }

        var sum = SIMD3<Float>(0, 0, 0)
        for v in vertices {
            sum += v
        }
        return sum / Float(vertices.count)
    }

    // MARK: - Image Resizing

    private func resizeImage(_ image: CGImage, to maxSize: Int) -> CGImage? {
        let width = image.width
        let height = image.height

        // If already smaller, return original
        if width <= maxSize && height <= maxSize {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let aspectRatio = CGFloat(width) / CGFloat(height)
        var newWidth: CGFloat
        var newHeight: CGFloat

        if width > height {
            newWidth = CGFloat(maxSize)
            newHeight = newWidth / aspectRatio
        } else {
            newHeight = CGFloat(maxSize)
            newWidth = newHeight * aspectRatio
        }

        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: Int(newWidth),
            height: Int(newHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        return context.makeImage()
    }

    // MARK: - ZIP Archive Creation

    private func createZipArchive(from files: [URL], to zipURL: URL) async throws {
        // Create a temporary directory for the archive contents
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Copy files to temp directory
        for file in files {
            let destURL = tempDir.appendingPathComponent(file.lastPathComponent)
            try FileManager.default.copyItem(at: file, to: destURL)
        }

        // Create ZIP using FileManager's built-in archiving
        // We use NSFileCoordinator for proper file coordination
        let coordinator = NSFileCoordinator()
        var error: NSError?

        coordinator.coordinate(readingItemAt: tempDir, options: .forUploading, error: &error) { zipTempURL in
            do {
                // Move the created ZIP to the final destination
                if FileManager.default.fileExists(atPath: zipURL.path) {
                    try FileManager.default.removeItem(at: zipURL)
                }
                try FileManager.default.copyItem(at: zipTempURL, to: zipURL)
            } catch {
                // Error will be captured in the outer scope
            }
        }

        if let coordinatorError = error {
            throw ExportError.zipCreationFailed(coordinatorError.localizedDescription)
        }

        // Verify the ZIP was created
        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw ExportError.zipCreationFailed("ZIP file was not created")
        }
    }

    // MARK: - Export with Configuration

    /// Export mesh using ExportConfiguration
    func export(
        mesh: CapturedMesh,
        configuration: ExportConfiguration,
        fileName: String
    ) async throws -> ExportResult {
        let options = ExportOptions(
            scale: configuration.scale,
            centerMesh: configuration.centerMesh,
            binary: configuration.binaryFormat,
            includeNormals: configuration.includeNormals,
            includeTextureCoords: configuration.includeTextureCoords,
            includeTexture: configuration.includeTexture,
            textureResolution: configuration.textureResolution.size,
            createZipArchive: configuration.createZipArchive
        )

        return try await export(
            mesh: mesh,
            format: configuration.format,
            fileName: fileName,
            options: options
        )
    }
}
