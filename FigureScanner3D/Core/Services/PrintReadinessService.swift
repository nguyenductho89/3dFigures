import Foundation
import simd

/// Service for analyzing mesh quality and readiness for 3D printing
/// Provides comprehensive mesh validation and repair recommendations
actor PrintReadinessService {

    // MARK: - Print Readiness Report

    struct PrintReadinessReport {
        let overallScore: Int  // 0-100
        let isWatertight: Bool
        let isManifold: Bool
        let holeCount: Int
        let holeTotalVertices: Int
        let nonManifoldEdgeCount: Int
        let duplicateVertexCount: Int
        let degenerateFaceCount: Int
        let invertedNormalCount: Int
        let selfIntersectionCount: Int
        let minWallThickness: Float?  // in meters
        let boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>)
        let dimensions: SIMD3<Float>  // in meters
        let surfaceArea: Float  // in square meters
        let volume: Float?  // in cubic meters (nil if not watertight)
        let triangleQuality: TriangleQuality
        let recommendations: [PrintRecommendation]

        var isPrintable: Bool {
            overallScore >= 70 && isWatertight && isManifold
        }

        var scoreDescription: String {
            switch overallScore {
            case 90...100: return "Excellent - Ready to print"
            case 70..<90: return "Good - Minor fixes recommended"
            case 50..<70: return "Fair - Repairs needed"
            case 30..<50: return "Poor - Significant repairs needed"
            default: return "Not printable - Major issues"
            }
        }
    }

    struct TriangleQuality {
        let minAspectRatio: Float
        let maxAspectRatio: Float
        let avgAspectRatio: Float
        let poorQualityCount: Int  // aspect ratio > 10
        let veryPoorQualityCount: Int  // aspect ratio > 20
    }

    enum PrintRecommendation: CustomStringConvertible {
        case fillHoles(count: Int, vertices: Int)
        case repairNonManifold(count: Int)
        case removeDuplicateVertices(count: Int)
        case removeDegenerateFaces(count: Int)
        case fixInvertedNormals(count: Int)
        case fixSelfIntersections(count: Int)
        case increaseResolution
        case addBaseForStability
        case checkWallThickness(minRequired: Float)
        case reduceMeshComplexity(targetFaces: Int)

        var description: String {
            switch self {
            case .fillHoles(let count, let vertices):
                return "Fill \(count) holes (\(vertices) boundary vertices)"
            case .repairNonManifold(let count):
                return "Repair \(count) non-manifold edges"
            case .removeDuplicateVertices(let count):
                return "Remove \(count) duplicate vertices"
            case .removeDegenerateFaces(let count):
                return "Remove \(count) degenerate faces"
            case .fixInvertedNormals(let count):
                return "Fix \(count) inverted normals"
            case .fixSelfIntersections(let count):
                return "Fix \(count) self-intersections"
            case .increaseResolution:
                return "Consider rescanning at higher resolution"
            case .addBaseForStability:
                return "Add a base plate for printing stability"
            case .checkWallThickness(let min):
                return "Check wall thickness (min \(String(format: "%.1f", min * 1000))mm recommended)"
            case .reduceMeshComplexity(let target):
                return "Reduce mesh to ~\(target) faces for faster slicing"
            }
        }

        var severity: Severity {
            switch self {
            case .fillHoles, .repairNonManifold, .fixSelfIntersections:
                return .critical
            case .removeDuplicateVertices, .removeDegenerateFaces, .fixInvertedNormals:
                return .warning
            case .increaseResolution, .addBaseForStability, .checkWallThickness, .reduceMeshComplexity:
                return .suggestion
            }
        }

        enum Severity {
            case critical, warning, suggestion
        }
    }

    // MARK: - Mesh Topology Analysis

    private struct MeshAnalysis {
        var boundaryEdges: Set<EdgeKey> = []
        var nonManifoldEdges: Set<EdgeKey> = []
        var edgeFaceCount: [EdgeKey: Int] = [:]
        var vertexFaces: [[Int]] = []
        var holes: [[Int]] = []  // List of boundary loops (vertex indices)
        var duplicateVertices: [(Int, Int)] = []  // Pairs of duplicate vertex indices
        var degenerateFaces: [Int] = []  // Indices of degenerate faces
    }

    private struct EdgeKey: Hashable {
        let v1: Int
        let v2: Int

        init(_ a: Int, _ b: Int) {
            // Normalize edge direction for consistent hashing
            if a < b {
                v1 = a
                v2 = b
            } else {
                v1 = b
                v2 = a
            }
        }
    }

    // MARK: - Public Methods

    /// Analyze mesh for 3D print readiness
    func analyze(mesh: CapturedMesh) async -> PrintReadinessReport {
        let vertices = mesh.vertices
        let faces = mesh.faces
        let normals = mesh.normals

        // Perform mesh analysis
        let analysis = analyzeMeshTopology(vertices: vertices, faces: faces)

        // Calculate metrics
        let boundingBox = calculateBoundingBox(vertices: vertices)
        let dimensions = boundingBox.max - boundingBox.min
        let surfaceArea = calculateSurfaceArea(vertices: vertices, faces: faces)
        let triangleQuality = analyzeTriangleQuality(vertices: vertices, faces: faces)

        // Check watertight and manifold
        let isWatertight = analysis.boundaryEdges.isEmpty
        let isManifold = analysis.nonManifoldEdges.isEmpty

        // Calculate volume (only meaningful for watertight meshes)
        let volume: Float? = isWatertight ? calculateVolume(vertices: vertices, faces: faces) : nil

        // Count inverted normals
        let invertedNormalCount = countInvertedNormals(vertices: vertices, faces: faces, normals: normals)

        // Self-intersection check (simplified - full check is expensive)
        let selfIntersectionCount = 0  // TODO: Implement full self-intersection detection

        // Generate recommendations
        var recommendations: [PrintRecommendation] = []

        if !analysis.holes.isEmpty {
            let totalHoleVertices = analysis.holes.reduce(0) { $0 + $1.count }
            recommendations.append(.fillHoles(count: analysis.holes.count, vertices: totalHoleVertices))
        }

        if !analysis.nonManifoldEdges.isEmpty {
            recommendations.append(.repairNonManifold(count: analysis.nonManifoldEdges.count))
        }

        if !analysis.duplicateVertices.isEmpty {
            recommendations.append(.removeDuplicateVertices(count: analysis.duplicateVertices.count))
        }

        if !analysis.degenerateFaces.isEmpty {
            recommendations.append(.removeDegenerateFaces(count: analysis.degenerateFaces.count))
        }

        if invertedNormalCount > 0 {
            recommendations.append(.fixInvertedNormals(count: invertedNormalCount))
        }

        // Wall thickness recommendation for small figures
        let minDimension = min(dimensions.x, min(dimensions.y, dimensions.z))
        if minDimension < 0.002 {  // Less than 2mm
            recommendations.append(.checkWallThickness(minRequired: 0.001))  // 1mm minimum
        }

        // Mesh complexity recommendation
        if faces.count > 500000 {
            recommendations.append(.reduceMeshComplexity(targetFaces: 200000))
        }

        // Add base recommendation for figures
        recommendations.append(.addBaseForStability)

        // Calculate overall score
        let overallScore = calculateOverallScore(
            isWatertight: isWatertight,
            isManifold: isManifold,
            holeCount: analysis.holes.count,
            nonManifoldCount: analysis.nonManifoldEdges.count,
            duplicateCount: analysis.duplicateVertices.count,
            degenerateCount: analysis.degenerateFaces.count,
            invertedNormalCount: invertedNormalCount,
            triangleQuality: triangleQuality
        )

        return PrintReadinessReport(
            overallScore: overallScore,
            isWatertight: isWatertight,
            isManifold: isManifold,
            holeCount: analysis.holes.count,
            holeTotalVertices: analysis.holes.reduce(0) { $0 + $1.count },
            nonManifoldEdgeCount: analysis.nonManifoldEdges.count,
            duplicateVertexCount: analysis.duplicateVertices.count,
            degenerateFaceCount: analysis.degenerateFaces.count,
            invertedNormalCount: invertedNormalCount,
            selfIntersectionCount: selfIntersectionCount,
            minWallThickness: nil,  // TODO: Implement wall thickness analysis
            boundingBox: boundingBox,
            dimensions: dimensions,
            surfaceArea: surfaceArea,
            volume: volume,
            triangleQuality: triangleQuality,
            recommendations: recommendations
        )
    }

    // MARK: - Private Analysis Methods

    private func analyzeMeshTopology(vertices: [SIMD3<Float>], faces: [[Int]]) -> MeshAnalysis {
        var analysis = MeshAnalysis()
        analysis.vertexFaces = Array(repeating: [], count: vertices.count)

        // Build edge-face relationships and vertex-face relationships
        for (faceIndex, face) in faces.enumerated() {
            guard face.count >= 3 else {
                analysis.degenerateFaces.append(faceIndex)
                continue
            }

            // Check for degenerate triangles
            let v0 = face[0], v1 = face[1], v2 = face[2]
            if v0 == v1 || v1 == v2 || v0 == v2 ||
               v0 >= vertices.count || v1 >= vertices.count || v2 >= vertices.count {
                analysis.degenerateFaces.append(faceIndex)
                continue
            }

            // Check for zero-area triangles
            let p0 = vertices[v0], p1 = vertices[v1], p2 = vertices[v2]
            let edge1 = p1 - p0
            let edge2 = p2 - p0
            let crossProduct = cross(edge1, edge2)
            if length(crossProduct) < 1e-10 {
                analysis.degenerateFaces.append(faceIndex)
                continue
            }

            // Record vertex-face relationships
            for vertexIndex in face {
                if vertexIndex < vertices.count {
                    analysis.vertexFaces[vertexIndex].append(faceIndex)
                }
            }

            // Record edge-face relationships
            for i in 0..<3 {
                let edge = EdgeKey(face[i], face[(i + 1) % 3])
                analysis.edgeFaceCount[edge, default: 0] += 1
            }
        }

        // Identify boundary and non-manifold edges
        for (edge, count) in analysis.edgeFaceCount {
            if count == 1 {
                analysis.boundaryEdges.insert(edge)
            } else if count > 2 {
                analysis.nonManifoldEdges.insert(edge)
            }
        }

        // Find boundary loops (holes)
        analysis.holes = findBoundaryLoops(boundaryEdges: analysis.boundaryEdges)

        // Find duplicate vertices
        analysis.duplicateVertices = findDuplicateVertices(vertices: vertices, threshold: 1e-6)

        return analysis
    }

    private func findBoundaryLoops(boundaryEdges: Set<EdgeKey>) -> [[Int]] {
        guard !boundaryEdges.isEmpty else { return [] }

        var loops: [[Int]] = []
        var remainingEdges = boundaryEdges

        // Build adjacency for boundary vertices
        var adjacency: [Int: Set<Int>] = [:]
        for edge in boundaryEdges {
            adjacency[edge.v1, default: []].insert(edge.v2)
            adjacency[edge.v2, default: []].insert(edge.v1)
        }

        while !remainingEdges.isEmpty {
            guard let startEdge = remainingEdges.first else { break }
            remainingEdges.remove(startEdge)

            var loop = [startEdge.v1, startEdge.v2]
            var current = startEdge.v2
            var previous = startEdge.v1

            // Trace the boundary loop
            while current != loop[0] {
                guard let neighbors = adjacency[current] else { break }
                guard let next = neighbors.first(where: { $0 != previous }) else { break }

                let edge = EdgeKey(current, next)
                remainingEdges.remove(edge)

                if next == loop[0] {
                    break  // Loop completed
                }

                loop.append(next)
                previous = current
                current = next

                // Safety check to prevent infinite loops
                if loop.count > boundaryEdges.count * 2 {
                    break
                }
            }

            if loop.count >= 3 {
                loops.append(loop)
            }
        }

        return loops
    }

    private func findDuplicateVertices(vertices: [SIMD3<Float>], threshold: Float) -> [(Int, Int)] {
        var duplicates: [(Int, Int)] = []
        let thresholdSquared = threshold * threshold

        // Simple O(n²) check - for large meshes, use spatial hashing
        for i in 0..<vertices.count {
            for j in (i + 1)..<vertices.count {
                let diff = vertices[i] - vertices[j]
                if dot(diff, diff) < thresholdSquared {
                    duplicates.append((i, j))
                }
            }
        }

        return duplicates
    }

    private func calculateBoundingBox(vertices: [SIMD3<Float>]) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard !vertices.isEmpty else {
            return (SIMD3<Float>(0, 0, 0), SIMD3<Float>(0, 0, 0))
        }

        var minPoint = vertices[0]
        var maxPoint = vertices[0]

        for vertex in vertices {
            minPoint = min(minPoint, vertex)
            maxPoint = max(maxPoint, vertex)
        }

        return (minPoint, maxPoint)
    }

    private func calculateSurfaceArea(vertices: [SIMD3<Float>], faces: [[Int]]) -> Float {
        var totalArea: Float = 0

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
            let crossProduct = cross(edge1, edge2)

            totalArea += length(crossProduct) / 2
        }

        return totalArea
    }

    private func calculateVolume(vertices: [SIMD3<Float>], faces: [[Int]]) -> Float {
        // Signed volume using divergence theorem
        var totalVolume: Float = 0

        for face in faces {
            guard face.count >= 3,
                  face[0] < vertices.count,
                  face[1] < vertices.count,
                  face[2] < vertices.count else { continue }

            let v0 = vertices[face[0]]
            let v1 = vertices[face[1]]
            let v2 = vertices[face[2]]

            // Signed volume of tetrahedron formed with origin
            let signedVolume = dot(v0, cross(v1, v2)) / 6
            totalVolume += signedVolume
        }

        return abs(totalVolume)
    }

    private func analyzeTriangleQuality(vertices: [SIMD3<Float>], faces: [[Int]]) -> TriangleQuality {
        var aspectRatios: [Float] = []

        for face in faces {
            guard face.count >= 3,
                  face[0] < vertices.count,
                  face[1] < vertices.count,
                  face[2] < vertices.count else { continue }

            let v0 = vertices[face[0]]
            let v1 = vertices[face[1]]
            let v2 = vertices[face[2]]

            // Calculate edge lengths
            let e0 = length(v1 - v0)
            let e1 = length(v2 - v1)
            let e2 = length(v0 - v2)

            guard e0 > 0 && e1 > 0 && e2 > 0 else { continue }

            // Aspect ratio = longest edge / shortest altitude
            let maxEdge = max(e0, max(e1, e2))
            let s = (e0 + e1 + e2) / 2  // Semi-perimeter
            let area = sqrt(max(0, s * (s - e0) * (s - e1) * (s - e2)))

            if area > 0 {
                let minAltitude = 2 * area / maxEdge
                let aspectRatio = maxEdge / minAltitude
                aspectRatios.append(aspectRatio)
            }
        }

        guard !aspectRatios.isEmpty else {
            return TriangleQuality(
                minAspectRatio: 0,
                maxAspectRatio: 0,
                avgAspectRatio: 0,
                poorQualityCount: 0,
                veryPoorQualityCount: 0
            )
        }

        let minAR = aspectRatios.min() ?? 0
        let maxAR = aspectRatios.max() ?? 0
        let avgAR = aspectRatios.reduce(0, +) / Float(aspectRatios.count)
        let poorCount = aspectRatios.filter { $0 > 10 }.count
        let veryPoorCount = aspectRatios.filter { $0 > 20 }.count

        return TriangleQuality(
            minAspectRatio: minAR,
            maxAspectRatio: maxAR,
            avgAspectRatio: avgAR,
            poorQualityCount: poorCount,
            veryPoorQualityCount: veryPoorCount
        )
    }

    private func countInvertedNormals(vertices: [SIMD3<Float>], faces: [[Int]], normals: [SIMD3<Float>]) -> Int {
        guard !normals.isEmpty else { return 0 }

        var invertedCount = 0

        // Calculate mesh centroid
        let centroid = vertices.reduce(SIMD3<Float>(0, 0, 0), +) / Float(vertices.count)

        for face in faces {
            guard face.count >= 3,
                  face[0] < vertices.count,
                  face[1] < vertices.count,
                  face[2] < vertices.count else { continue }

            let v0 = vertices[face[0]]
            let v1 = vertices[face[1]]
            let v2 = vertices[face[2]]

            // Calculate face normal
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let faceNormal = normalize(cross(edge1, edge2))

            // Face centroid
            let faceCentroid = (v0 + v1 + v2) / 3

            // Direction from mesh centroid to face centroid (should be outward)
            let outwardDir = normalize(faceCentroid - centroid)

            // If face normal points inward, it's inverted
            if dot(faceNormal, outwardDir) < 0 {
                invertedCount += 1
            }
        }

        return invertedCount
    }

    private func calculateOverallScore(
        isWatertight: Bool,
        isManifold: Bool,
        holeCount: Int,
        nonManifoldCount: Int,
        duplicateCount: Int,
        degenerateCount: Int,
        invertedNormalCount: Int,
        triangleQuality: TriangleQuality
    ) -> Int {
        var score = 100

        // Critical issues (major deductions)
        if !isWatertight {
            score -= 30
            score -= min(holeCount * 5, 20)  // Additional penalty per hole
        }

        if !isManifold {
            score -= 25
            score -= min(nonManifoldCount * 2, 15)
        }

        // Warning issues (moderate deductions)
        score -= min(duplicateCount / 10, 10)
        score -= min(degenerateCount * 2, 10)
        score -= min(invertedNormalCount / 10, 10)

        // Triangle quality (minor deductions)
        score -= min(triangleQuality.poorQualityCount / 100, 5)
        score -= min(triangleQuality.veryPoorQualityCount / 50, 5)

        return max(0, score)
    }
}
