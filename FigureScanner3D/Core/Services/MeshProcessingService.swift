import Foundation
import Accelerate
import simd

/// Service for processing and optimizing captured 3D meshes
actor MeshProcessingService {

    // MARK: - Processing Options
    struct ProcessingOptions {
        var smoothingIterations: Int = 3
        var smoothingFactor: Float = 0.5
        var decimationRatio: Float = 0.5  // 0.5 = reduce to 50% of vertices
        var fillHoles: Bool = true
        var removeNoise: Bool = true
        var noiseThreshold: Float = 0.002  // 2mm
    }

    // MARK: - Processed Mesh Result
    struct ProcessedMesh {
        let vertices: [SIMD3<Float>]
        let normals: [SIMD3<Float>]
        let faces: [[Int]]
        let textureCoordinates: [SIMD2<Float>]?
        let textureData: MeshTextureData?

        var vertexCount: Int { vertices.count }
        var faceCount: Int { faces.count }
        var hasTexture: Bool { textureData != nil && textureCoordinates != nil }
    }

    // MARK: - Public Methods

    /// Process a captured mesh with default options
    func process(_ mesh: CapturedMesh) async throws -> ProcessedMesh {
        try await process(mesh, options: ProcessingOptions())
    }

    /// Process a captured mesh with custom options
    func process(_ mesh: CapturedMesh, options: ProcessingOptions) async throws -> ProcessedMesh {
        var vertices = mesh.vertices
        var normals = mesh.normals
        var faces = mesh.faces
        var textureCoords = mesh.textureCoordinates

        // Build vertex index mapping for texture coordinate updates
        var vertexMap: [Int: Int] = [:]
        for i in 0..<vertices.count {
            vertexMap[i] = i
        }

        // Step 1: Remove noise
        if options.removeNoise {
            let (newVertices, newNormals, newFaces, newMap) = removeNoiseWithMapping(
                vertices: vertices,
                normals: normals,
                faces: faces,
                threshold: options.noiseThreshold
            )
            vertices = newVertices
            normals = newNormals
            faces = newFaces

            // Update texture coordinates based on mapping
            if let coords = textureCoords {
                textureCoords = newMap.compactMap { oldIndex, _ in
                    oldIndex < coords.count ? coords[oldIndex] : nil
                }.map { $0 }
            }
        }

        // Step 2: Fill holes
        if options.fillHoles {
            (vertices, normals, faces) = fillHoles(
                vertices: vertices,
                normals: normals,
                faces: faces
            )
        }

        // Step 3: Smooth mesh
        if options.smoothingIterations > 0 {
            vertices = laplacianSmooth(
                vertices: vertices,
                faces: faces,
                iterations: options.smoothingIterations,
                factor: options.smoothingFactor
            )
        }

        // Step 4: Recalculate normals
        normals = recalculateNormals(vertices: vertices, faces: faces)

        // Step 5: Decimate if needed
        if options.decimationRatio < 1.0 {
            (vertices, normals, faces) = decimate(
                vertices: vertices,
                normals: normals,
                faces: faces,
                ratio: options.decimationRatio
            )
            // Regenerate texture coordinates after decimation
            textureCoords = generateTextureCoordinates(vertices: vertices)
        }

        // Step 6: Generate texture coordinates if not present
        if textureCoords == nil || textureCoords?.count != vertices.count {
            textureCoords = generateTextureCoordinates(vertices: vertices)
        }

        return ProcessedMesh(
            vertices: vertices,
            normals: normals,
            faces: faces,
            textureCoordinates: textureCoords,
            textureData: mesh.textureData
        )
    }

    /// Remove noise with vertex mapping for texture coordinate preservation
    private func removeNoiseWithMapping(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        faces: [[Int]],
        threshold: Float
    ) -> ([SIMD3<Float>], [SIMD3<Float>], [[Int]], [Int: Int]) {
        // Build adjacency list
        var adjacency: [[Int]] = Array(repeating: [], count: vertices.count)
        for face in faces {
            for i in 0..<3 {
                let v1 = face[i]
                let v2 = face[(i + 1) % 3]
                if !adjacency[v1].contains(v2) {
                    adjacency[v1].append(v2)
                }
                if !adjacency[v2].contains(v1) {
                    adjacency[v2].append(v1)
                }
            }
        }

        // Find outlier vertices
        var validVertices = Set<Int>()
        for i in 0..<vertices.count {
            let neighbors = adjacency[i]
            if neighbors.isEmpty {
                continue
            }

            let avgDistance = neighbors.reduce(Float(0)) { sum, neighbor in
                sum + length(vertices[i] - vertices[neighbor])
            } / Float(neighbors.count)

            if avgDistance < threshold * 10 {
                validVertices.insert(i)
            }
        }

        // Remap vertices and faces
        var newVertices: [SIMD3<Float>] = []
        var newNormals: [SIMD3<Float>] = []
        var vertexMap: [Int: Int] = [:]

        for (oldIndex, _) in vertices.enumerated() where validVertices.contains(oldIndex) {
            vertexMap[oldIndex] = newVertices.count
            newVertices.append(vertices[oldIndex])
            if oldIndex < normals.count {
                newNormals.append(normals[oldIndex])
            }
        }

        // Remap faces
        var newFaces: [[Int]] = []
        for face in faces {
            if let v0 = vertexMap[face[0]],
               let v1 = vertexMap[face[1]],
               let v2 = vertexMap[face[2]] {
                newFaces.append([v0, v1, v2])
            }
        }

        return (newVertices, newNormals, newFaces, vertexMap)
    }

    // MARK: - Noise Removal

    private func removeNoise(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        faces: [[Int]],
        threshold: Float
    ) -> ([SIMD3<Float>], [SIMD3<Float>], [[Int]]) {
        // Build adjacency list
        var adjacency: [[Int]] = Array(repeating: [], count: vertices.count)
        for face in faces {
            for i in 0..<3 {
                let v1 = face[i]
                let v2 = face[(i + 1) % 3]
                if !adjacency[v1].contains(v2) {
                    adjacency[v1].append(v2)
                }
                if !adjacency[v2].contains(v1) {
                    adjacency[v2].append(v1)
                }
            }
        }

        // Find outlier vertices (those with neighbors too far away)
        var validVertices = Set<Int>()
        for i in 0..<vertices.count {
            let neighbors = adjacency[i]
            if neighbors.isEmpty {
                continue
            }

            let avgDistance = neighbors.reduce(Float(0)) { sum, neighbor in
                sum + length(vertices[i] - vertices[neighbor])
            } / Float(neighbors.count)

            if avgDistance < threshold * 10 {  // Allow 10x threshold for connectivity
                validVertices.insert(i)
            }
        }

        // Remap vertices and faces
        var newVertices: [SIMD3<Float>] = []
        var newNormals: [SIMD3<Float>] = []
        var vertexMap: [Int: Int] = [:]

        for (oldIndex, _) in vertices.enumerated() where validVertices.contains(oldIndex) {
            vertexMap[oldIndex] = newVertices.count
            newVertices.append(vertices[oldIndex])
            if oldIndex < normals.count {
                newNormals.append(normals[oldIndex])
            }
        }

        // Remap faces
        var newFaces: [[Int]] = []
        for face in faces {
            if let v0 = vertexMap[face[0]],
               let v1 = vertexMap[face[1]],
               let v2 = vertexMap[face[2]] {
                newFaces.append([v0, v1, v2])
            }
        }

        return (newVertices, newNormals, newFaces)
    }

    // MARK: - Hole Filling

    private func fillHoles(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        faces: [[Int]]
    ) -> ([SIMD3<Float>], [SIMD3<Float>], [[Int]]) {
        // Find boundary edges (edges that belong to only one face)
        var edgeCount: [String: Int] = [:]
        var edgeToFace: [String: [Int]] = [:]

        for (faceIdx, face) in faces.enumerated() {
            for i in 0..<3 {
                let v1 = face[i]
                let v2 = face[(i + 1) % 3]
                let key = v1 < v2 ? "\(v1)-\(v2)" : "\(v2)-\(v1)"
                edgeCount[key, default: 0] += 1
                edgeToFace[key, default: []].append(faceIdx)
            }
        }

        // Find boundary edges
        let boundaryEdges = edgeCount.filter { $0.value == 1 }.keys

        if boundaryEdges.isEmpty {
            return (vertices, normals, faces)
        }

        // Simple hole filling: add triangles to close small holes
        var newFaces = faces

        // Build boundary loops
        var boundaryVertices: Set<Int> = []
        for edge in boundaryEdges {
            let parts = edge.split(separator: "-")
            if let v1 = Int(parts[0]), let v2 = Int(parts[1]) {
                boundaryVertices.insert(v1)
                boundaryVertices.insert(v2)
            }
        }

        // For small holes (< 10 vertices), create a fan triangulation
        if boundaryVertices.count < 10 && boundaryVertices.count >= 3 {
            let boundaryArray = Array(boundaryVertices)

            // Find centroid
            var centroid = SIMD3<Float>(0, 0, 0)
            for v in boundaryArray {
                centroid += vertices[v]
            }
            centroid /= Float(boundaryArray.count)

            // Create fan triangles (simplified approach)
            for i in 0..<boundaryArray.count {
                let v1 = boundaryArray[i]
                let v2 = boundaryArray[(i + 1) % boundaryArray.count]
                let v3 = boundaryArray[(i + 2) % boundaryArray.count]
                newFaces.append([v1, v2, v3])
            }
        }

        return (vertices, normals, newFaces)
    }

    // MARK: - Laplacian Smoothing

    private func laplacianSmooth(
        vertices: [SIMD3<Float>],
        faces: [[Int]],
        iterations: Int,
        factor: Float
    ) -> [SIMD3<Float>] {
        var smoothedVertices = vertices

        // Build adjacency list
        var adjacency: [[Int]] = Array(repeating: [], count: vertices.count)
        for face in faces {
            for i in 0..<3 {
                let v1 = face[i]
                let v2 = face[(i + 1) % 3]
                if !adjacency[v1].contains(v2) {
                    adjacency[v1].append(v2)
                }
                if !adjacency[v2].contains(v1) {
                    adjacency[v2].append(v1)
                }
            }
        }

        for _ in 0..<iterations {
            var newPositions = smoothedVertices

            for i in 0..<smoothedVertices.count {
                let neighbors = adjacency[i]
                if neighbors.isEmpty { continue }

                // Calculate centroid of neighbors
                var centroid = SIMD3<Float>(0, 0, 0)
                for neighbor in neighbors {
                    centroid += smoothedVertices[neighbor]
                }
                centroid /= Float(neighbors.count)

                // Move vertex towards centroid
                newPositions[i] = mix(smoothedVertices[i], centroid, t: factor)
            }

            smoothedVertices = newPositions
        }

        return smoothedVertices
    }

    // MARK: - Normal Recalculation

    private func recalculateNormals(
        vertices: [SIMD3<Float>],
        faces: [[Int]]
    ) -> [SIMD3<Float>] {
        var normals = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: vertices.count)

        for face in faces {
            guard face.count >= 3 else { continue }

            let v0 = vertices[face[0]]
            let v1 = vertices[face[1]]
            let v2 = vertices[face[2]]

            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let faceNormal = cross(edge1, edge2)

            // Add to vertex normals
            for vertexIndex in face {
                normals[vertexIndex] += faceNormal
            }
        }

        // Normalize
        for i in 0..<normals.count {
            let length = simd_length(normals[i])
            if length > 0 {
                normals[i] /= length
            }
        }

        return normals
    }

    // MARK: - Mesh Decimation

    private func decimate(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        faces: [[Int]],
        ratio: Float
    ) -> ([SIMD3<Float>], [SIMD3<Float>], [[Int]]) {
        // Simple vertex clustering decimation
        let targetCount = Int(Float(vertices.count) * ratio)

        if targetCount >= vertices.count {
            return (vertices, normals, faces)
        }

        // Calculate grid cell size based on mesh bounding box
        var minPoint = vertices[0]
        var maxPoint = vertices[0]
        for v in vertices {
            minPoint = min(minPoint, v)
            maxPoint = max(maxPoint, v)
        }

        let dimensions = maxPoint - minPoint
        let cellCount = Int(pow(Float(targetCount), 1.0/3.0))
        let cellSize = max(dimensions.x, max(dimensions.y, dimensions.z)) / Float(cellCount)

        // Cluster vertices
        var clusters: [String: [Int]] = [:]
        for (i, v) in vertices.enumerated() {
            let cx = Int((v.x - minPoint.x) / cellSize)
            let cy = Int((v.y - minPoint.y) / cellSize)
            let cz = Int((v.z - minPoint.z) / cellSize)
            let key = "\(cx),\(cy),\(cz)"
            clusters[key, default: []].append(i)
        }

        // Create new vertices (cluster centroids)
        var newVertices: [SIMD3<Float>] = []
        var newNormals: [SIMD3<Float>] = []
        var vertexMap: [Int: Int] = [:]

        for (_, indices) in clusters {
            var centroid = SIMD3<Float>(0, 0, 0)
            var normal = SIMD3<Float>(0, 0, 0)

            for i in indices {
                centroid += vertices[i]
                if i < normals.count {
                    normal += normals[i]
                }
            }

            centroid /= Float(indices.count)
            normal = normalize(normal)

            let newIndex = newVertices.count
            for i in indices {
                vertexMap[i] = newIndex
            }

            newVertices.append(centroid)
            newNormals.append(normal)
        }

        // Remap faces
        var newFaces: [[Int]] = []
        for face in faces {
            guard let v0 = vertexMap[face[0]],
                  let v1 = vertexMap[face[1]],
                  let v2 = vertexMap[face[2]] else { continue }

            // Skip degenerate triangles
            if v0 != v1 && v1 != v2 && v0 != v2 {
                newFaces.append([v0, v1, v2])
            }
        }

        return (newVertices, newNormals, newFaces)
    }

    // MARK: - Texture Coordinate Generation

    private func generateTextureCoordinates(
        vertices: [SIMD3<Float>]
    ) -> [SIMD2<Float>] {
        guard !vertices.isEmpty else { return [] }

        // Calculate bounding box
        var minPoint = vertices[0]
        var maxPoint = vertices[0]
        for v in vertices {
            minPoint = min(minPoint, v)
            maxPoint = max(maxPoint, v)
        }

        let dimensions = maxPoint - minPoint

        // Use cylindrical projection for face/body scans
        return vertices.map { vertex in
            // Normalize position
            let normalized = (vertex - minPoint)

            // Cylindrical UV mapping
            let angle = atan2(normalized.x - dimensions.x / 2, normalized.z - dimensions.z / 2)
            let u = (angle + .pi) / (2 * .pi)
            let v = normalized.y / dimensions.y

            return SIMD2<Float>(u, v)
        }
    }
}

// MARK: - Helper Functions

private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
    return a * (1 - t) + b * t
}
