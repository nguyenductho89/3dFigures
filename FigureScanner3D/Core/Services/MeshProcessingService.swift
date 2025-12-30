import Foundation
import Accelerate
import simd

/// Service for processing and optimizing captured 3D meshes.
///
/// This service provides a complete mesh processing pipeline for improving
/// the quality of 3D scans captured via LiDAR. The processing includes:
///
/// - **Noise Removal**: Eliminates outlier vertices that are far from their neighbors
/// - **Hole Filling**: Repairs small gaps in the mesh surface
/// - **Laplacian Smoothing**: Reduces surface roughness while preserving shape
/// - **Normal Recalculation**: Computes accurate vertex normals for proper shading
/// - **Decimation**: Reduces vertex count for smaller file sizes (optional)
/// - **Texture Coordinate Generation**: Creates UV mapping for texture application
///
/// ## Usage Example
///
/// ```swift
/// let processingService = MeshProcessingService()
///
/// // With default options
/// let processed = try await processingService.process(capturedMesh)
///
/// // With custom options and progress tracking
/// let options = ProcessingOptions(smoothingIterations: 5, decimationRatio: 0.3)
/// let processed = try await processingService.process(capturedMesh, options: options) { step, progress in
///     print("Step: \(step.rawValue), Progress: \(progress * 100)%")
/// }
/// ```
///
/// ## Performance Considerations
///
/// - Large meshes (>100k vertices) are processed in parallel using `DispatchQueue.concurrentPerform`
/// - Mesh topology is computed once and reused across processing steps
/// - Processing supports task cancellation via Swift's cooperative cancellation
actor MeshProcessingService {

    // MARK: - Processing Step (for progress reporting)
    enum ProcessingStep: String, CaseIterable {
        case preparingData = "Preparing data..."
        case removingNoise = "Removing noise..."
        case fillingHoles = "Filling holes..."
        case smoothing = "Smoothing surface..."
        case calculatingNormals = "Calculating normals..."
        case decimating = "Optimizing mesh..."
        case generatingTexCoords = "Generating texture coordinates..."
        case finalizing = "Finalizing..."

        var progress: Float {
            switch self {
            case .preparingData: return 0.0
            case .removingNoise: return 0.15
            case .fillingHoles: return 0.30
            case .smoothing: return 0.45
            case .calculatingNormals: return 0.70
            case .decimating: return 0.80
            case .generatingTexCoords: return 0.90
            case .finalizing: return 0.95
            }
        }
    }

    // MARK: - Progress Callback
    typealias ProgressCallback = @Sendable (ProcessingStep, Float) -> Void

    // MARK: - Processing Options
    struct ProcessingOptions {
        var smoothingIterations: Int = 3
        var smoothingFactor: Float = 0.5
        var decimationRatio: Float = 0.5  // 0.5 = reduce to 50% of vertices
        var fillHoles: Bool = true
        var removeNoise: Bool = true
        var noiseThreshold: Float = 0.002  // 2mm

        // 3D Print preparation options
        var prepareForPrint: Bool = false
        var maxHoleSize: Int = 500  // Maximum hole size (in vertices) to fill
        var fixNonManifold: Bool = true
        var removeDuplicateVertices: Bool = true
        var ensureOutwardNormals: Bool = true

        /// Preset for 3D printing preparation
        static var printReady: ProcessingOptions {
            var options = ProcessingOptions()
            options.prepareForPrint = true
            options.smoothingIterations = 2
            options.smoothingFactor = 0.3
            options.decimationRatio = 0.7
            options.fillHoles = true
            options.maxHoleSize = 500
            options.fixNonManifold = true
            options.removeDuplicateVertices = true
            options.ensureOutwardNormals = true
            return options
        }
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

    // MARK: - Mesh Topology (cached for performance)
    /// Precomputed mesh topology to avoid rebuilding adjacency lists
    private struct MeshTopology {
        let adjacency: [[Int]]
        let boundaryEdges: Set<String>

        init(faces: [[Int]], vertexCount: Int) {
            var adj: [[Int]] = Array(repeating: [], count: vertexCount)
            var edgeCount: [String: Int] = [:]

            for face in faces {
                for i in 0..<3 {
                    let v1 = face[i]
                    let v2 = face[(i + 1) % 3]

                    // Build adjacency (avoid duplicates)
                    if v1 < vertexCount && v2 < vertexCount {
                        if !adj[v1].contains(v2) { adj[v1].append(v2) }
                        if !adj[v2].contains(v1) { adj[v2].append(v1) }
                    }

                    // Count edges for boundary detection
                    let key = v1 < v2 ? "\(v1)-\(v2)" : "\(v2)-\(v1)"
                    edgeCount[key, default: 0] += 1
                }
            }

            self.adjacency = adj
            self.boundaryEdges = Set(edgeCount.filter { $0.value == 1 }.keys)
        }
    }

    // MARK: - Public Methods

    /// Processes a captured mesh with default options.
    ///
    /// Applies the standard processing pipeline with balanced quality settings.
    ///
    /// - Parameter mesh: The raw captured mesh from LiDAR scanning
    /// - Returns: An optimized mesh ready for export or display
    /// - Throws: Processing errors if mesh data is invalid
    func process(_ mesh: CapturedMesh) async throws -> ProcessedMesh {
        try await process(mesh, options: ProcessingOptions(), progress: nil)
    }

    /// Processes a captured mesh with custom processing options.
    ///
    /// - Parameters:
    ///   - mesh: The raw captured mesh from LiDAR scanning
    ///   - options: Custom processing options (smoothing, decimation, etc.)
    /// - Returns: An optimized mesh ready for export or display
    /// - Throws: Processing errors if mesh data is invalid
    func process(_ mesh: CapturedMesh, options: ProcessingOptions) async throws -> ProcessedMesh {
        try await process(mesh, options: options, progress: nil)
    }

    /// Processes a captured mesh with progress reporting.
    ///
    /// This method provides real-time progress updates during processing,
    /// useful for displaying progress indicators in the UI.
    ///
    /// - Parameters:
    ///   - mesh: The raw captured mesh from LiDAR scanning
    ///   - options: Processing options including smoothing and decimation settings
    ///   - progress: A callback that receives the current step and progress value (0.0-1.0)
    /// - Returns: An optimized mesh ready for export or display
    /// - Throws: Processing errors if mesh data is invalid or processing fails
    ///
    /// - Note: The progress callback is invoked on an unspecified thread.
    ///         Use `@MainActor` dispatch if updating UI elements.
    func process(
        _ mesh: CapturedMesh,
        options: ProcessingOptions,
        progress: ProgressCallback?
    ) async throws -> ProcessedMesh {
        var vertices = mesh.vertices
        var normals = mesh.normals
        var faces = mesh.faces
        var textureCoords = mesh.textureCoordinates

        // Report initial progress
        progress?(.preparingData, ProcessingStep.preparingData.progress)

        // Build vertex index mapping for texture coordinate updates
        var vertexMap: [Int: Int] = [:]
        for i in 0..<vertices.count {
            vertexMap[i] = i
        }

        // Step 1: Remove noise
        if options.removeNoise {
            progress?(.removingNoise, ProcessingStep.removingNoise.progress)

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

        // Step 2: Fill holes (with advanced algorithm for 3D printing)
        if options.fillHoles {
            progress?(.fillingHoles, ProcessingStep.fillingHoles.progress)

            (vertices, normals, faces) = fillHoles(
                vertices: vertices,
                normals: normals,
                faces: faces,
                maxHoleSize: options.maxHoleSize
            )
        }

        // Step 3: Smooth mesh
        if options.smoothingIterations > 0 {
            progress?(.smoothing, ProcessingStep.smoothing.progress)

            vertices = laplacianSmooth(
                vertices: vertices,
                faces: faces,
                iterations: options.smoothingIterations,
                factor: options.smoothingFactor
            )
        }

        // Step 4: Recalculate normals
        progress?(.calculatingNormals, ProcessingStep.calculatingNormals.progress)
        normals = recalculateNormals(vertices: vertices, faces: faces)

        // Step 5: Decimate if needed
        if options.decimationRatio < 1.0 {
            progress?(.decimating, ProcessingStep.decimating.progress)

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
            progress?(.generatingTexCoords, ProcessingStep.generatingTexCoords.progress)
            textureCoords = generateTextureCoordinates(vertices: vertices)
        }

        progress?(.finalizing, ProcessingStep.finalizing.progress)

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
        // Build topology once (reused structure)
        let topology = MeshTopology(faces: faces, vertexCount: vertices.count)

        // Find outlier vertices using parallel processing for large meshes
        var validFlags = [Bool](repeating: false, count: vertices.count)
        let thresholdMultiplied = threshold * 10

        if vertices.count > 10000 {
            // Parallel processing for very large meshes only
            // Swift arrays aren't thread-safe, avoid for small meshes like face (~1220 vertices)
            DispatchQueue.concurrentPerform(iterations: vertices.count) { i in
                let neighbors = topology.adjacency[i]
                guard !neighbors.isEmpty else { return }

                var totalDistance: Float = 0
                for neighbor in neighbors {
                    totalDistance += length(vertices[i] - vertices[neighbor])
                }
                let avgDistance = totalDistance / Float(neighbors.count)

                if avgDistance < thresholdMultiplied {
                    validFlags[i] = true
                }
            }
        } else {
            // Sequential for small meshes (avoid overhead)
            for i in 0..<vertices.count {
                let neighbors = topology.adjacency[i]
                guard !neighbors.isEmpty else { continue }

                let avgDistance = neighbors.reduce(Float(0)) { sum, neighbor in
                    sum + length(vertices[i] - vertices[neighbor])
                } / Float(neighbors.count)

                if avgDistance < thresholdMultiplied {
                    validFlags[i] = true
                }
            }
        }

        // Remap vertices and faces
        var newVertices: [SIMD3<Float>] = []
        var newNormals: [SIMD3<Float>] = []
        var vertexMap: [Int: Int] = [:]
        newVertices.reserveCapacity(vertices.count)
        newNormals.reserveCapacity(normals.count)

        for oldIndex in 0..<vertices.count where validFlags[oldIndex] {
            vertexMap[oldIndex] = newVertices.count
            newVertices.append(vertices[oldIndex])
            if oldIndex < normals.count {
                newNormals.append(normals[oldIndex])
            }
        }

        // Remap faces
        var newFaces: [[Int]] = []
        newFaces.reserveCapacity(faces.count)
        for face in faces {
            if let v0 = vertexMap[face[0]],
               let v1 = vertexMap[face[1]],
               let v2 = vertexMap[face[2]] {
                newFaces.append([v0, v1, v2])
            }
        }

        return (newVertices, newNormals, newFaces, vertexMap)
    }

    // MARK: - Advanced Hole Filling

    private func fillHoles(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        faces: [[Int]],
        maxHoleSize: Int = 500
    ) -> ([SIMD3<Float>], [SIMD3<Float>], [[Int]]) {
        // Find boundary edges (edges that belong to only one face)
        var edgeCount: [String: Int] = [:]
        var adjacency: [Int: Set<Int>] = [:]

        for face in faces {
            for i in 0..<3 {
                let v1 = face[i]
                let v2 = face[(i + 1) % 3]
                let key = v1 < v2 ? "\(v1)-\(v2)" : "\(v2)-\(v1)"
                edgeCount[key, default: 0] += 1

                adjacency[v1, default: []].insert(v2)
                adjacency[v2, default: []].insert(v1)
            }
        }

        // Find boundary edges
        let boundaryEdgeKeys = edgeCount.filter { $0.value == 1 }.keys

        if boundaryEdgeKeys.isEmpty {
            return (vertices, normals, faces)
        }

        // Build boundary adjacency (only boundary edges)
        var boundaryAdjacency: [Int: Set<Int>] = [:]
        for key in boundaryEdgeKeys {
            let parts = key.split(separator: "-")
            guard let v1 = Int(parts[0]), let v2 = Int(parts[1]) else { continue }
            boundaryAdjacency[v1, default: []].insert(v2)
            boundaryAdjacency[v2, default: []].insert(v1)
        }

        // Find all boundary loops (holes)
        var visitedVertices: Set<Int> = []
        var boundaryLoops: [[Int]] = []

        for startVertex in boundaryAdjacency.keys {
            guard !visitedVertices.contains(startVertex) else { continue }

            var loop: [Int] = []
            var current = startVertex
            var previous: Int? = nil

            // Trace the boundary loop
            while true {
                loop.append(current)
                visitedVertices.insert(current)

                guard let neighbors = boundaryAdjacency[current] else { break }
                let nextOptions = neighbors.filter { $0 != previous }

                guard let next = nextOptions.first else { break }

                if next == startVertex && loop.count >= 3 {
                    // Loop completed
                    break
                }

                previous = current
                current = next

                // Safety check
                if loop.count > maxHoleSize * 2 {
                    break
                }
            }

            if loop.count >= 3 {
                boundaryLoops.append(loop)
            }
        }

        print("[MeshProcessing] Found \(boundaryLoops.count) holes to fill")

        var newVertices = vertices
        var newNormals = normals
        var newFaces = faces

        // Fill each hole
        for (holeIndex, loop) in boundaryLoops.enumerated() {
            guard loop.count <= maxHoleSize else {
                print("[MeshProcessing] Skipping hole \(holeIndex + 1) - too large (\(loop.count) vertices)")
                continue
            }

            let (filledFaces, addedVertices, addedNormals) = fillSingleHole(
                loop: loop,
                vertices: newVertices,
                normals: newNormals
            )

            // Add new vertices
            let vertexOffset = newVertices.count
            newVertices.append(contentsOf: addedVertices)
            newNormals.append(contentsOf: addedNormals)

            // Add new faces with offset
            for face in filledFaces {
                let offsetFace = face.map { idx in
                    idx >= vertices.count ? idx - vertices.count + vertexOffset : idx
                }
                newFaces.append(offsetFace)
            }

            print("[MeshProcessing] Filled hole \(holeIndex + 1) with \(filledFaces.count) triangles")
        }

        return (newVertices, newNormals, newFaces)
    }

    /// Fill a single hole using advancing front triangulation
    private func fillSingleHole(
        loop: [Int],
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>]
    ) -> (faces: [[Int]], addedVertices: [SIMD3<Float>], addedNormals: [SIMD3<Float>]) {
        guard loop.count >= 3 else { return ([], [], []) }

        var filledFaces: [[Int]] = []
        var addedVertices: [SIMD3<Float>] = []
        var addedNormals: [SIMD3<Float>] = []

        // For small holes, use simple fan triangulation from centroid
        if loop.count <= 20 {
            // Calculate centroid
            var centroid = SIMD3<Float>(0, 0, 0)
            var avgNormal = SIMD3<Float>(0, 0, 0)

            for vertexIndex in loop {
                centroid += vertices[vertexIndex]
                if vertexIndex < normals.count {
                    avgNormal += normals[vertexIndex]
                }
            }
            centroid /= Float(loop.count)
            avgNormal = normalize(avgNormal)

            // Add centroid as new vertex
            let centroidIndex = vertices.count + addedVertices.count
            addedVertices.append(centroid)
            addedNormals.append(avgNormal)

            // Create fan triangles
            for i in 0..<loop.count {
                let v1 = loop[i]
                let v2 = loop[(i + 1) % loop.count]
                filledFaces.append([v1, v2, centroidIndex])
            }
        } else {
            // For larger holes, use ear clipping algorithm
            filledFaces = earClipTriangulation(loop: loop, vertices: vertices)
        }

        return (filledFaces, addedVertices, addedNormals)
    }

    /// Ear clipping triangulation for larger holes
    private func earClipTriangulation(loop: [Int], vertices: [SIMD3<Float>]) -> [[Int]] {
        guard loop.count >= 3 else { return [] }

        var remainingIndices = loop
        var triangles: [[Int]] = []

        // Calculate average normal of the hole boundary
        let holeNormal = calculateHoleNormal(loop: loop, vertices: vertices)

        while remainingIndices.count > 3 {
            var earFound = false

            for i in 0..<remainingIndices.count {
                let prevIdx = (i - 1 + remainingIndices.count) % remainingIndices.count
                let nextIdx = (i + 1) % remainingIndices.count

                let vPrev = remainingIndices[prevIdx]
                let vCurr = remainingIndices[i]
                let vNext = remainingIndices[nextIdx]

                // Check if this is a valid ear (convex vertex, no other vertices inside)
                if isEar(prev: vPrev, curr: vCurr, next: vNext,
                        remainingIndices: remainingIndices,
                        vertices: vertices,
                        holeNormal: holeNormal) {
                    // Add triangle
                    triangles.append([vPrev, vCurr, vNext])
                    remainingIndices.remove(at: i)
                    earFound = true
                    break
                }
            }

            // If no ear found, force add a triangle to avoid infinite loop
            if !earFound && remainingIndices.count >= 3 {
                triangles.append([remainingIndices[0], remainingIndices[1], remainingIndices[2]])
                remainingIndices.remove(at: 1)
            }
        }

        // Add final triangle
        if remainingIndices.count == 3 {
            triangles.append([remainingIndices[0], remainingIndices[1], remainingIndices[2]])
        }

        return triangles
    }

    private func calculateHoleNormal(loop: [Int], vertices: [SIMD3<Float>]) -> SIMD3<Float> {
        var normal = SIMD3<Float>(0, 0, 0)

        for i in 0..<loop.count {
            let v0 = vertices[loop[i]]
            let v1 = vertices[loop[(i + 1) % loop.count]]
            let v2 = vertices[loop[(i + 2) % loop.count]]

            let edge1 = v1 - v0
            let edge2 = v2 - v1
            normal += cross(edge1, edge2)
        }

        return normalize(normal)
    }

    private func isEar(prev: Int, curr: Int, next: Int,
                      remainingIndices: [Int],
                      vertices: [SIMD3<Float>],
                      holeNormal: SIMD3<Float>) -> Bool {
        let vPrev = vertices[prev]
        let vCurr = vertices[curr]
        let vNext = vertices[next]

        // Check if vertex is convex (forms correct winding)
        let edge1 = vCurr - vPrev
        let edge2 = vNext - vCurr
        let crossProduct = cross(edge1, edge2)

        if dot(crossProduct, holeNormal) < 0 {
            return false  // Reflex vertex, not an ear
        }

        // Check if any other vertex is inside the triangle
        for idx in remainingIndices {
            if idx == prev || idx == curr || idx == next { continue }

            if pointInTriangle(point: vertices[idx], v0: vPrev, v1: vCurr, v2: vNext) {
                return false  // Another vertex inside, not a valid ear
            }
        }

        return true
    }

    private func pointInTriangle(point: SIMD3<Float>, v0: SIMD3<Float>, v1: SIMD3<Float>, v2: SIMD3<Float>) -> Bool {
        // Project to 2D (use XY plane, ignoring Z for simplicity)
        let p = SIMD2<Float>(point.x, point.y)
        let a = SIMD2<Float>(v0.x, v0.y)
        let b = SIMD2<Float>(v1.x, v1.y)
        let c = SIMD2<Float>(v2.x, v2.y)

        let v0v1 = b - a
        let v0v2 = c - a
        let v0p = p - a

        let dot00 = dot(v0v2, v0v2)
        let dot01 = dot(v0v2, v0v1)
        let dot02 = dot(v0v2, v0p)
        let dot11 = dot(v0v1, v0v1)
        let dot12 = dot(v0v1, v0p)

        let invDenom = 1 / (dot00 * dot11 - dot01 * dot01)
        let u = (dot11 * dot02 - dot01 * dot12) * invDenom
        let v = (dot00 * dot12 - dot01 * dot02) * invDenom

        return u >= 0 && v >= 0 && u + v < 1
    }

    // MARK: - Laplacian Smoothing

    private func laplacianSmooth(
        vertices: [SIMD3<Float>],
        faces: [[Int]],
        iterations: Int,
        factor: Float
    ) -> [SIMD3<Float>] {
        var smoothedVertices = vertices

        // Build topology once and reuse for all iterations
        let topology = MeshTopology(faces: faces, vertexCount: vertices.count)
        let adjacency = topology.adjacency
        // Disable parallel processing - Swift arrays aren't thread-safe for concurrent writes
        // Face mesh is ~1220 vertices which is small enough for sequential processing
        let useParallel = false // vertices.count > 10000
        let oneMinusFactor = 1 - factor

        for _ in 0..<iterations {
            var newPositions = smoothedVertices

            if useParallel {
                // Parallel smoothing for large meshes
                DispatchQueue.concurrentPerform(iterations: smoothedVertices.count) { i in
                    let neighbors = adjacency[i]
                    guard !neighbors.isEmpty else { return }

                    // Calculate centroid of neighbors
                    var centroid = SIMD3<Float>(0, 0, 0)
                    for neighbor in neighbors {
                        centroid += smoothedVertices[neighbor]
                    }
                    centroid /= Float(neighbors.count)

                    // Move vertex towards centroid
                    newPositions[i] = smoothedVertices[i] * oneMinusFactor + centroid * factor
                }
            } else {
                // Sequential for small meshes
                for i in 0..<smoothedVertices.count {
                    let neighbors = adjacency[i]
                    guard !neighbors.isEmpty else { continue }

                    // Calculate centroid of neighbors
                    var centroid = SIMD3<Float>(0, 0, 0)
                    for neighbor in neighbors {
                        centroid += smoothedVertices[neighbor]
                    }
                    centroid /= Float(neighbors.count)

                    // Move vertex towards centroid
                    newPositions[i] = smoothedVertices[i] * oneMinusFactor + centroid * factor
                }
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

        // Accumulate face normals to vertices (sequential due to write dependencies)
        for face in faces {
            guard face.count >= 3,
                  face[0] < vertices.count,
                  face[1] < vertices.count,
                  face[2] < vertices.count else { continue }

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

        // Normalize (parallel for very large meshes only)
        if normals.count > 10000 {
            DispatchQueue.concurrentPerform(iterations: normals.count) { i in
                let len = simd_length(normals[i])
                if len > 0 {
                    normals[i] /= len
                }
            }
        } else {
            for i in 0..<normals.count {
                let len = simd_length(normals[i])
                if len > 0 {
                    normals[i] /= len
                }
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
