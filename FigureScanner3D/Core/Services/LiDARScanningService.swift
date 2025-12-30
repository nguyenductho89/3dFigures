import Foundation
import ARKit
import RealityKit
import Combine
import CoreImage
import VideoToolbox

// MARK: - Scan Configuration

/// Configuration parameters for 3D scanning operations.
///
/// Use predefined configurations or create custom ones to control scan behavior:
/// - `default`: Standard scanning with balanced quality and performance
/// - `highQuality`: Higher resolution scanning with more captured frames
/// - `quickScan`: Faster scanning with lower quality settings
struct ScanConfiguration {
    /// Number of angles required for a complete scan
    let requiredAngles: Int

    /// Interval between texture frame captures (in seconds)
    let textureCaptureInterval: TimeInterval

    /// Maximum number of texture frames to capture
    let maxTextureFrames: Int

    /// Bounding box for face scanning region
    let faceScanBounds: BoundingBox

    /// Lighting threshold levels for quality indicators
    let lightingThresholds: LightingThresholds

    /// Mesh density target for progress calculation
    let meshDensityTarget: Int

    /// Angle bucket size for quantization (in degrees)
    let angleBucketSize: Int

    struct LightingThresholds {
        let poor: Double
        let fair: Double
        let good: Double

        static let `default` = LightingThresholds(poor: 200, fair: 500, good: 1000)
    }

    // MARK: - Predefined Configurations

    /// Default scanning configuration with balanced settings
    static let `default` = ScanConfiguration(
        requiredAngles: 5,
        textureCaptureInterval: 0.2,
        maxTextureFrames: 30,
        faceScanBounds: BoundingBox(
            // Expanded bounds to capture face mesh when head is turned
            // Width: 50cm, Height: 50cm, Depth: 40cm (centered on face)
            min: SIMD3<Float>(-0.25, -0.30, -0.20),
            max: SIMD3<Float>(0.25, 0.20, 0.20)
        ),
        lightingThresholds: .default,
        meshDensityTarget: 10,
        angleBucketSize: 36
    )

    /// High quality scanning configuration for detailed captures
    static let highQuality = ScanConfiguration(
        requiredAngles: 8,
        textureCaptureInterval: 0.1,
        maxTextureFrames: 60,
        faceScanBounds: BoundingBox(
            // Expanded bounds for high quality capture
            min: SIMD3<Float>(-0.28, -0.35, -0.25),
            max: SIMD3<Float>(0.28, 0.25, 0.25)
        ),
        lightingThresholds: .default,
        meshDensityTarget: 15,
        angleBucketSize: 30
    )

    /// Quick scan configuration for faster captures
    static let quickScan = ScanConfiguration(
        requiredAngles: 3,
        textureCaptureInterval: 0.3,
        maxTextureFrames: 15,
        faceScanBounds: BoundingBox(
            // Smaller bounds for quick scan, but still reasonable
            min: SIMD3<Float>(-0.20, -0.25, -0.15),
            max: SIMD3<Float>(0.20, 0.15, 0.15)
        ),
        lightingThresholds: .default,
        meshDensityTarget: 8,
        angleBucketSize: 45
    )
}

/// Service responsible for LiDAR-based 3D scanning
@MainActor
final class LiDARScanningService: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var isScanning = false
    @Published private(set) var scanProgress: Float = 0.0
    @Published private(set) var capturedMesh: CapturedMesh?
    @Published private(set) var faceDetected = false
    @Published private(set) var faceTransform: simd_float4x4?
    @Published private(set) var lightingQuality: LightingQuality = .good
    @Published private(set) var distanceToFace: Float = 0.0
    @Published private(set) var errorMessage: String?

    // MARK: - Types
    enum LightingQuality {
        case poor, fair, good, excellent

        var description: String {
            switch self {
            case .poor: return "Poor lighting"
            case .fair: return "Fair lighting"
            case .good: return "Good lighting"
            case .excellent: return "Excellent lighting"
            }
        }
    }

    enum ScanMode {
        case face
        case body
        case bust
    }

    // MARK: - Configuration
    private var configuration: ScanConfiguration

    // MARK: - Private Properties
    private var arView: ARView?
    private var scanMode: ScanMode = .face
    private var meshAnchors: [ARMeshAnchor] = []
    private var faceAnchor: ARFaceAnchor?
    private var scanStartTime: Date?
    private var capturedAngles: Set<Int> = []

    /// Stores the last valid face transform for use during mesh processing
    /// This prevents 0 vertices when face tracking is temporarily lost
    private var lastValidFaceTransform: simd_float4x4?

    // Face geometry capture for face scanning mode
    // Stores face mesh data captured at different angles
    private var capturedFaceGeometries: [CapturedFaceGeometry] = []
    private var lastFaceGeometryCapture: Date = .distantPast
    private let faceGeometryCaptureInterval: TimeInterval = 0.2 // Capture every 200ms (slower, more stable)

    // Texture capture properties
    private var capturedTextureFrames: [CapturedTextureFrame] = []
    private var lastTextureCapture: Date = .distantPast

    // MARK: - Initialization

    /// Creates a new scanning service with the specified configuration
    /// - Parameter configuration: Scan configuration parameters (defaults to `.default`)
    init(configuration: ScanConfiguration = .default) {
        self.configuration = configuration
        super.init()
    }

    // MARK: - Device Capability Check
    static var isLiDARAvailable: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    static var isFaceTrackingAvailable: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    // MARK: - Public Methods

    /// Updates the scan configuration
    /// - Parameter configuration: New configuration to use
    func updateConfiguration(_ configuration: ScanConfiguration) {
        self.configuration = configuration
    }

    /// Current scan configuration
    var currentConfiguration: ScanConfiguration {
        configuration
    }

    func configure(arView: ARView, mode: ScanMode) {
        self.arView = arView
        self.scanMode = mode
        arView.session.delegate = self

        setupARSession()
    }

    func startScanning() {
        guard !isScanning else { return }

        isScanning = true
        scanProgress = 0.0
        meshAnchors.removeAll()
        capturedAngles.removeAll()
        capturedFaceGeometries.removeAll()
        capturedTextureFrames.removeAll()
        lastFaceGeometryCapture = .distantPast
        lastTextureCapture = .distantPast
        scanStartTime = Date()
        errorMessage = nil

        // Enable mesh visualization
        if let arView = arView {
            arView.debugOptions.insert(.showSceneUnderstanding)
        }
    }

    func stopScanning() {
        isScanning = false

        // Disable mesh visualization
        if let arView = arView {
            arView.debugOptions.remove(.showSceneUnderstanding)
        }

        // Validate minimum captures for face scan
        if scanMode == .face {
            let minCaptures = 5
            if capturedFaceGeometries.count < minCaptures {
                errorMessage = "Not enough data captured (\(capturedFaceGeometries.count)/\(minCaptures)). Please try scanning again with your face visible."
                return
            }
        }

        // Process captured mesh
        processCapturedMesh()
    }

    func resetScan() {
        isScanning = false
        scanProgress = 0.0
        meshAnchors.removeAll()
        capturedAngles.removeAll()
        capturedTextureFrames.removeAll()
        capturedFaceGeometries.removeAll()
        capturedMesh = nil
        faceAnchor = nil
        lastValidFaceTransform = nil
        errorMessage = nil
        lastTextureCapture = .distantPast
        lastFaceGeometryCapture = .distantPast
    }

    // MARK: - Private Methods

    private func setupARSession() {
        guard let arView = arView else { return }

        switch scanMode {
        case .face:
            setupFaceScanSession(arView: arView)
        case .body, .bust:
            setupBodyScanSession(arView: arView)
        }
    }

    private func setupFaceScanSession(arView: ARView) {
        // Use ARFaceTrackingConfiguration to use the TrueDepth front camera
        // This provides ARFaceAnchor with face geometry mesh data
        guard Self.isFaceTrackingAvailable else {
            errorMessage = "Face tracking is not available on this device"
            return
        }

        let configuration = ARFaceTrackingConfiguration()

        // Enable world tracking if available (for better positioning)
        if ARFaceTrackingConfiguration.supportsWorldTracking {
            configuration.isWorldTrackingEnabled = true
        }

        // Maximum number of faces to track
        configuration.maximumNumberOfTrackedFaces = 1

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    private func setupBodyScanSession(arView: ARView) {
        let configuration = ARWorldTrackingConfiguration()

        if Self.isLiDARAvailable {
            configuration.sceneReconstruction = .meshWithClassification
        }

        configuration.environmentTexturing = .automatic
        configuration.frameSemantics.insert(.personSegmentation)

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    private func processCapturedMesh() {
        // For face scanning, use captured face geometries from TrueDepth camera
        if scanMode == .face {
            processFaceGeometries()
            return
        }

        // For body/bust scanning, use LiDAR mesh anchors
        guard !meshAnchors.isEmpty else {
            errorMessage = "No mesh data captured"
            return
        }

        // Combine all mesh anchors into a single mesh
        var allVertices: [SIMD3<Float>] = []
        var allNormals: [SIMD3<Float>] = []
        var allFaces: [[Int]] = []
        var vertexOffset = 0

        for anchor in meshAnchors {
            let geometry = anchor.geometry

            // Get vertices
            let vertices = geometry.vertices
            let vertexBuffer = vertices.buffer.contents()

            for i in 0..<vertices.count {
                let vertexPointer = vertexBuffer.advanced(by: vertices.offset + vertices.stride * i)
                let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee

                // Transform vertex to world space
                let worldVertex = anchor.transform * SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
                allVertices.append(SIMD3<Float>(worldVertex.x, worldVertex.y, worldVertex.z))
            }

            // Get normals
            let normals = geometry.normals
            let normalBuffer = normals.buffer.contents()

            for i in 0..<normals.count {
                let normalPointer = normalBuffer.advanced(by: normals.offset + normals.stride * i)
                let normal = normalPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee

                // Transform normal to world space (rotation only)
                let rotationMatrix = simd_float3x3(
                    SIMD3<Float>(anchor.transform.columns.0.x, anchor.transform.columns.0.y, anchor.transform.columns.0.z),
                    SIMD3<Float>(anchor.transform.columns.1.x, anchor.transform.columns.1.y, anchor.transform.columns.1.z),
                    SIMD3<Float>(anchor.transform.columns.2.x, anchor.transform.columns.2.y, anchor.transform.columns.2.z)
                )
                let worldNormal = rotationMatrix * normal
                allNormals.append(worldNormal)
            }

            // Get faces
            let faces = geometry.faces
            let faceBuffer = faces.buffer.contents()

            for i in 0..<faces.count {
                let facePointer = faceBuffer.advanced(by: faces.bytesPerIndex * 3 * i)

                var indices: [Int] = []
                for j in 0..<3 {
                    let indexPointer = facePointer.advanced(by: faces.bytesPerIndex * j)
                    let index: Int
                    if faces.bytesPerIndex == 4 {
                        index = Int(indexPointer.assumingMemoryBound(to: UInt32.self).pointee)
                    } else {
                        index = Int(indexPointer.assumingMemoryBound(to: UInt16.self).pointee)
                    }
                    indices.append(index + vertexOffset)
                }
                allFaces.append(indices)
            }

            vertexOffset += vertices.count
        }

        // Generate texture coordinates and texture data
        var textureCoords: [SIMD2<Float>]? = nil
        var textureData: MeshTextureData? = nil

        if !capturedTextureFrames.isEmpty {
            print("[BodyScan] Generating multi-view texture coordinates from \(capturedTextureFrames.count) frames")

            // For body scanning, use multi-view texture projection
            // Each vertex is projected from the camera that best faces its normal
            textureCoords = generateMultiViewTextureCoordinates(
                vertices: allVertices,
                normals: allNormals,
                frames: capturedTextureFrames
            )

            // Create texture atlas from captured frames
            let (atlasImage, atlasSize) = createTextureAtlas()
            textureData = MeshTextureData(
                frames: capturedTextureFrames,
                atlasImage: atlasImage,
                atlasSize: atlasSize
            )

            print("[BodyScan] Generated \(textureCoords?.count ?? 0) texture coordinates")
        }

        // Create captured mesh
        capturedMesh = CapturedMesh(
            vertices: allVertices,
            normals: allNormals,
            faces: allFaces,
            textureCoordinates: textureCoords,
            textureData: textureData,
            scanMode: scanMode,
            captureDate: Date()
        )
    }

    /// Process captured face geometries from TrueDepth camera into final mesh
    private func processFaceGeometries() {
        guard !capturedFaceGeometries.isEmpty else {
            errorMessage = "No face data captured. Make sure your face is visible to the front camera."
            return
        }

        // Log capture statistics
        print("[FaceScan] Processing \(capturedFaceGeometries.count) captured geometries")

        // Warn if too few captures
        if capturedFaceGeometries.count < 10 {
            print("[FaceScan] Warning: Only \(capturedFaceGeometries.count) captures - scan may be incomplete")
        }

        // Find the best geometry:
        // 1. Prefer frontal view (face looking at camera) for best quality
        // 2. Fall back to geometry with most vertices
        let bestGeometry: CapturedFaceGeometry

        // Try to find a frontal capture (angle bucket near center)
        // With angleBucketSize=36, center would be bucket 5 (180/36)
        let centerBucket = 180 / configuration.angleBucketSize
        let frontalCaptures = capturedFaceGeometries.filter { geometry in
            guard let angle = geometry.angle else { return false }
            return abs(angle - centerBucket) <= 1 // Within 1 bucket of center
        }

        if let frontalGeometry = frontalCaptures.max(by: { $0.vertices.count < $1.vertices.count }) {
            bestGeometry = frontalGeometry
            print("[FaceScan] Using frontal capture with \(bestGeometry.vertices.count) vertices")
        } else {
            // Fall back to geometry with most vertices
            bestGeometry = capturedFaceGeometries.max(by: { $0.vertices.count < $1.vertices.count })!
            print("[FaceScan] No frontal capture found, using max vertices: \(bestGeometry.vertices.count)")
        }

        print("[FaceScan] Best geometry: \(bestGeometry.vertices.count) vertices, \(bestGeometry.triangleCount) triangles")

        var allVertices: [SIMD3<Float>] = []
        var allNormals: [SIMD3<Float>] = []
        var allFaces: [[Int]] = []

        // Extract vertices from captured geometry (already copied from ARFaceGeometry)
        let vertexCount = bestGeometry.vertices.count

        for i in 0..<vertexCount {
            let vertex = bestGeometry.vertices[i]
            // Transform vertex from face-local space to world space
            let worldVertex = bestGeometry.transform * SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
            allVertices.append(SIMD3<Float>(worldVertex.x, worldVertex.y, worldVertex.z))
        }

        // Generate normals (compute from faces)
        allNormals = Array(repeating: SIMD3<Float>(0, 0, 0), count: vertexCount)

        // Get triangle indices and compute face normals
        let triangleCount = bestGeometry.triangleCount

        for i in 0..<triangleCount {
            let baseIdx = i * 3
            let idx0 = Int(bestGeometry.triangleIndices[baseIdx])
            let idx1 = Int(bestGeometry.triangleIndices[baseIdx + 1])
            let idx2 = Int(bestGeometry.triangleIndices[baseIdx + 2])

            allFaces.append([idx0, idx1, idx2])

            // Compute face normal
            let v0 = allVertices[idx0]
            let v1 = allVertices[idx1]
            let v2 = allVertices[idx2]

            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let faceNormal = normalize(cross(edge1, edge2))

            // Accumulate normals for smooth shading
            allNormals[idx0] += faceNormal
            allNormals[idx1] += faceNormal
            allNormals[idx2] += faceNormal
        }

        // Normalize accumulated normals
        for i in 0..<allNormals.count {
            let len = length(allNormals[i])
            if len > 0 {
                allNormals[i] = allNormals[i] / len
            }
        }

        // Generate texture coordinates by projecting vertices onto camera image
        var textureCoords: [SIMD2<Float>]? = nil
        var textureData: MeshTextureData? = nil

        if !capturedTextureFrames.isEmpty {
            // Use the frame from the middle of the scan for best overall coverage
            // This provides the best frontal view since face geometry and texture capture happen simultaneously
            let bestFrameIndex = capturedTextureFrames.count / 2
            let bestFrame = capturedTextureFrames[bestFrameIndex]

            print("[FaceScan] Using texture frame \(bestFrameIndex + 1)/\(capturedTextureFrames.count)")
            print("[FaceScan] Frame resolution: \(bestFrame.imageResolution)")

            // Project face vertices onto camera image plane
            // Use face-local vertices (not world-transformed) for projection
            textureCoords = generateFaceTextureCoordinates(
                vertices: bestGeometry.vertices,
                faceTransform: bestGeometry.transform,
                cameraTransform: bestFrame.transform,
                intrinsics: bestFrame.intrinsics,
                imageResolution: bestFrame.imageResolution
            )

            // Create texture atlas with the best frame
            textureData = MeshTextureData(
                frames: capturedTextureFrames,
                atlasImage: bestFrame.image,
                atlasSize: bestFrame.imageResolution
            )

            print("[FaceScan] Generated \(textureCoords?.count ?? 0) texture coordinates")

            // Log UV coordinate bounds for debugging
            if let coords = textureCoords, !coords.isEmpty {
                let minU = coords.map { $0.x }.min() ?? 0
                let maxU = coords.map { $0.x }.max() ?? 0
                let minV = coords.map { $0.y }.min() ?? 0
                let maxV = coords.map { $0.y }.max() ?? 0
                print("[FaceScan] UV bounds: U[\(minU)...\(maxU)], V[\(minV)...\(maxV)]")
            }
        } else {
            // Fall back to ARFaceGeometry's built-in texture coordinates
            textureCoords = bestGeometry.textureCoordinates
            print("[FaceScan] Using built-in ARFaceGeometry texture coordinates (no frames captured)")
        }

        // Create captured mesh
        capturedMesh = CapturedMesh(
            vertices: allVertices,
            normals: allNormals,
            faces: allFaces,
            textureCoordinates: textureCoords,
            textureData: textureData,
            scanMode: scanMode,
            captureDate: Date()
        )
    }

    /// Capture face geometry from ARFaceAnchor
    private func captureFaceGeometry(from faceAnchor: ARFaceAnchor) {
        let now = Date()
        guard now.timeIntervalSince(lastFaceGeometryCapture) >= faceGeometryCaptureInterval else { return }

        // Create captured geometry with copied vertex data
        let capturedGeometry = CapturedFaceGeometry(
            from: faceAnchor,
            angle: calculateFaceAngle()
        )

        capturedFaceGeometries.append(capturedGeometry)
        lastFaceGeometryCapture = now
    }

    private func updateLightingQuality(frame: ARFrame) {
        guard let lightEstimate = frame.lightEstimate else {
            lightingQuality = .fair
            return
        }

        let ambientIntensity = lightEstimate.ambientIntensity
        let thresholds = configuration.lightingThresholds

        switch ambientIntensity {
        case 0..<thresholds.poor:
            lightingQuality = .poor
        case thresholds.poor..<thresholds.fair:
            lightingQuality = .fair
        case thresholds.fair..<thresholds.good:
            lightingQuality = .good
        default:
            lightingQuality = .excellent
        }
    }

    private func updateScanProgress() {
        let newProgress: Float

        if scanMode == .face {
            // For face scanning, progress is primarily based on scan duration
            // This ensures user has enough time to turn head through all positions
            let scanDuration: Float = 8.0 // 8 seconds for complete scan
            let elapsedTime = Float(Date().timeIntervalSince(scanStartTime ?? Date()))
            let timeProgress = min(elapsedTime / scanDuration, 1.0)

            // Also require minimum captures to ensure we have data
            let minRequiredCaptures: Float = 20.0
            let captureProgress = min(Float(capturedFaceGeometries.count) / minRequiredCaptures, 1.0)

            // Progress = 80% time-based + 20% capture-based
            // This ensures scan takes enough time for user to complete all head movements
            newProgress = (timeProgress * 0.8) + (captureProgress * 0.2)
        } else {
            // For body/bust scanning, use LiDAR mesh anchors
            let angleProgress = Float(capturedAngles.count) / Float(configuration.requiredAngles)
            let meshDensity = min(Float(meshAnchors.count) / Float(configuration.meshDensityTarget), 1.0)
            newProgress = min((angleProgress + meshDensity) / 2.0, 1.0)
        }

        // Only allow progress to increase, never decrease
        if newProgress > scanProgress {
            scanProgress = newProgress
        }
    }

    private func calculateFaceAngle() -> Int? {
        guard let faceTransform = faceTransform else { return nil }

        // Extract rotation from transform
        let forward = SIMD3<Float>(faceTransform.columns.2.x, faceTransform.columns.2.y, faceTransform.columns.2.z)

        // Calculate horizontal angle (yaw)
        let angle = atan2(forward.x, forward.z)
        let degrees = Int(angle * 180 / .pi)

        // Quantize to angle bucket size (e.g., 36-degree buckets = 10 buckets for 360 degrees)
        return (degrees + 180) / configuration.angleBucketSize
    }

    // MARK: - Texture Capture

    private func captureTextureFrame(from frame: ARFrame) {
        guard isScanning else { return }

        let now = Date()
        guard now.timeIntervalSince(lastTextureCapture) >= configuration.textureCaptureInterval else { return }
        guard capturedTextureFrames.count < configuration.maxTextureFrames else { return }

        // Convert pixel buffer to CGImage
        let pixelBuffer = frame.capturedImage
        guard let cgImage = createCGImage(from: pixelBuffer) else { return }

        let textureFrame = CapturedTextureFrame(
            image: cgImage,
            timestamp: frame.timestamp,
            transform: frame.camera.transform,
            intrinsics: frame.camera.intrinsics,
            imageResolution: CGSize(
                width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
                height: CGFloat(CVPixelBufferGetHeight(pixelBuffer))
            )
        )

        capturedTextureFrames.append(textureFrame)
        lastTextureCapture = now
    }

    private func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        return cgImage
    }

    // MARK: - Texture Coordinate Generation

    /// Generate texture coordinates using multi-view projection for body scanning
    /// Each vertex is projected from the camera that best faces its surface normal
    private func generateMultiViewTextureCoordinates(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        frames: [CapturedTextureFrame]
    ) -> [SIMD2<Float>] {
        guard !vertices.isEmpty, !frames.isEmpty else { return [] }

        // Pre-compute camera forward directions for each frame
        let cameraDirections: [SIMD3<Float>] = frames.map { frame in
            // Camera forward is -Z in camera space, transform to world space
            let forward = SIMD3<Float>(
                -frame.transform.columns.2.x,
                -frame.transform.columns.2.y,
                -frame.transform.columns.2.z
            )
            return normalize(forward)
        }

        // Pre-compute camera positions
        let cameraPositions: [SIMD3<Float>] = frames.map { frame in
            SIMD3<Float>(
                frame.transform.columns.3.x,
                frame.transform.columns.3.y,
                frame.transform.columns.3.z
            )
        }

        return vertices.enumerated().map { (index, vertex) in
            let normal = index < normals.count ? normals[index] : SIMD3<Float>(0, 0, 1)

            // Find the best frame for this vertex (camera most facing the vertex normal)
            var bestFrameIndex = 0
            var bestScore: Float = -Float.infinity

            for (frameIndex, cameraDir) in cameraDirections.enumerated() {
                // Direction from camera to vertex
                let toVertex = normalize(vertex - cameraPositions[frameIndex])

                // Score = how well the camera faces the surface
                // High score when camera is looking at the front of the surface
                let facingScore = dot(-toVertex, normal)

                // Also consider if vertex is in front of camera
                let inFrontScore = dot(toVertex, cameraDir)

                // Combined score: prefer cameras that see the front of the surface
                let score = facingScore * 0.7 + inFrontScore * 0.3

                if score > bestScore {
                    bestScore = score
                    bestFrameIndex = frameIndex
                }
            }

            // Project vertex using the best frame
            let bestFrame = frames[bestFrameIndex]
            return projectVertexToFrame(
                vertex: vertex,
                frame: bestFrame
            )
        }
    }

    /// Project a single vertex onto a camera frame
    private func projectVertexToFrame(
        vertex: SIMD3<Float>,
        frame: CapturedTextureFrame
    ) -> SIMD2<Float> {
        let viewMatrix = frame.transform.inverse
        let worldPos = SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
        let cameraPos = viewMatrix * worldPos

        // Skip vertices behind camera
        guard cameraPos.z < -0.01 else {
            return SIMD2<Float>(0.5, 0.5)
        }

        // Project to image plane using intrinsics
        let x = -cameraPos.x / cameraPos.z
        let y = -cameraPos.y / cameraPos.z

        let fx = frame.intrinsics[0, 0]
        let fy = frame.intrinsics[1, 1]
        let cx = frame.intrinsics[2, 0]
        let cy = frame.intrinsics[2, 1]

        let u = (fx * x + cx) / Float(frame.imageResolution.width)
        let v = (fy * y + cy) / Float(frame.imageResolution.height)

        // Clamp to valid range
        return SIMD2<Float>(
            max(0, min(1, u)),
            max(0, min(1, 1 - v))  // Flip Y for texture coordinates
        )
    }

    private func generateTextureCoordinates(
        vertices: [SIMD3<Float>],
        cameraTransform: simd_float4x4,
        intrinsics: simd_float3x3,
        imageResolution: CGSize
    ) -> [SIMD2<Float>] {
        guard !vertices.isEmpty else { return [] }

        let viewMatrix = cameraTransform.inverse

        return vertices.map { vertex in
            // Transform vertex to camera space
            let worldPos = SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
            let cameraPos = viewMatrix * worldPos

            // Skip vertices behind camera
            guard cameraPos.z < 0 else {
                return SIMD2<Float>(0, 0)
            }

            // Project to image plane using intrinsics
            let x = -cameraPos.x / cameraPos.z
            let y = -cameraPos.y / cameraPos.z

            let fx = intrinsics[0, 0]
            let fy = intrinsics[1, 1]
            let cx = intrinsics[2, 0]
            let cy = intrinsics[2, 1]

            let u = (fx * x + cx) / Float(imageResolution.width)
            let v = (fy * y + cy) / Float(imageResolution.height)

            // Clamp to valid range
            return SIMD2<Float>(
                max(0, min(1, u)),
                max(0, min(1, 1 - v))  // Flip Y for texture coordinates
            )
        }
    }

    /// Generate texture coordinates for face mesh by projecting vertices onto camera image
    /// This handles the TrueDepth front camera's coordinate system and mirroring
    private func generateFaceTextureCoordinates(
        vertices: [SIMD3<Float>],
        faceTransform: simd_float4x4,
        cameraTransform: simd_float4x4,
        intrinsics: simd_float3x3,
        imageResolution: CGSize
    ) -> [SIMD2<Float>] {
        guard !vertices.isEmpty else { return [] }

        // For front-facing TrueDepth camera:
        // 1. Face vertices are in face-local space
        // 2. faceTransform transforms from face-local to camera space
        // 3. The camera image is horizontally mirrored (selfie mode)

        let fx = intrinsics[0, 0]
        let fy = intrinsics[1, 1]
        let cx = intrinsics[2, 0]
        let cy = intrinsics[2, 1]

        let imageWidth = Float(imageResolution.width)
        let imageHeight = Float(imageResolution.height)

        return vertices.map { vertex in
            // Transform vertex from face-local space to camera space
            // For TrueDepth camera, faceTransform already gives us the position
            // relative to the camera coordinate system
            let localPos = SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
            let cameraPos = faceTransform * localPos

            // In camera space, Z is depth (positive going away from camera)
            // For front camera, the face is in front of the camera (positive Z)
            guard cameraPos.z > 0.01 else {
                return SIMD2<Float>(0.5, 0.5) // Default to center if behind camera
            }

            // Project to image plane using pinhole camera model
            // Note: For ARKit front camera, X is positive to the left
            let x = cameraPos.x / cameraPos.z
            let y = cameraPos.y / cameraPos.z

            // Apply camera intrinsics to get pixel coordinates
            var pixelX = fx * x + cx
            var pixelY = fy * y + cy

            // The front camera image is mirrored horizontally (selfie mode)
            // Mirror the X coordinate to match
            pixelX = imageWidth - pixelX

            // Convert to normalized UV coordinates [0, 1]
            let u = pixelX / imageWidth
            // Flip V coordinate: image Y=0 is at top, but texture V=0 should be at bottom
            // for SceneKit rendering to display correctly
            let v = 1.0 - (pixelY / imageHeight)

            // Clamp to valid range
            return SIMD2<Float>(
                max(0, min(1, u)),
                max(0, min(1, v))
            )
        }
    }

    // MARK: - Texture Atlas Generation

    private func createTextureAtlas() -> (CGImage?, CGSize) {
        guard !capturedTextureFrames.isEmpty else { return (nil, .zero) }

        // Use the best frame (middle of capture) as the main texture
        let bestFrameIndex = capturedTextureFrames.count / 2
        let bestFrame = capturedTextureFrames[bestFrameIndex]

        return (bestFrame.image, bestFrame.imageResolution)
    }
}

// MARK: - ARSessionDelegate
extension LiDARScanningService: ARSessionDelegate {

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            updateLightingQuality(frame: frame)

            // Capture texture frame during scanning
            captureTextureFrame(from: frame)

            // Update face tracking
            var faceFoundInFrame = false
            for anchor in frame.anchors {
                if let faceAnchor = anchor as? ARFaceAnchor {
                    self.faceAnchor = faceAnchor
                    self.faceDetected = true
                    self.faceTransform = faceAnchor.transform

                    // Save last valid face transform for mesh processing
                    if isScanning {
                        self.lastValidFaceTransform = faceAnchor.transform

                        // Capture face geometry for face scanning mode
                        if scanMode == .face {
                            captureFaceGeometry(from: faceAnchor)
                        }
                    }

                    // Calculate distance to face
                    let facePosition = SIMD3<Float>(
                        faceAnchor.transform.columns.3.x,
                        faceAnchor.transform.columns.3.y,
                        faceAnchor.transform.columns.3.z
                    )
                    self.distanceToFace = length(facePosition)

                    // Track captured angles
                    if isScanning, let angle = calculateFaceAngle() {
                        capturedAngles.insert(angle)
                        updateScanProgress()
                    }

                    faceFoundInFrame = true
                }
            }

            // When face is temporarily lost during scanning, continue to update progress
            // based on captured face geometries
            if !faceFoundInFrame {
                self.faceDetected = false
            }

            if isScanning && !faceFoundInFrame {
                updateScanProgress()
            }
        }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                if let meshAnchor = anchor as? ARMeshAnchor, isScanning {
                    meshAnchors.append(meshAnchor)
                    updateScanProgress()
                }

                if let faceAnchor = anchor as? ARFaceAnchor {
                    self.faceAnchor = faceAnchor
                    self.faceDetected = true
                    self.faceTransform = faceAnchor.transform

                    // Calculate distance to face
                    let facePosition = SIMD3<Float>(
                        faceAnchor.transform.columns.3.x,
                        faceAnchor.transform.columns.3.y,
                        faceAnchor.transform.columns.3.z
                    )
                    self.distanceToFace = length(facePosition)
                }
            }
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                if let meshAnchor = anchor as? ARMeshAnchor, isScanning {
                    // Update existing mesh anchor
                    if let index = meshAnchors.firstIndex(where: { $0.identifier == meshAnchor.identifier }) {
                        meshAnchors[index] = meshAnchor
                    } else {
                        meshAnchors.append(meshAnchor)
                    }
                    updateScanProgress()
                }

                if let faceAnchor = anchor as? ARFaceAnchor {
                    self.faceAnchor = faceAnchor
                    self.faceDetected = true
                    self.faceTransform = faceAnchor.transform

                    // Calculate distance to face
                    let facePosition = SIMD3<Float>(
                        faceAnchor.transform.columns.3.x,
                        faceAnchor.transform.columns.3.y,
                        faceAnchor.transform.columns.3.z
                    )
                    self.distanceToFace = length(facePosition)

                    // Capture face geometry during scanning
                    if isScanning {
                        self.lastValidFaceTransform = faceAnchor.transform

                        if scanMode == .face {
                            captureFaceGeometry(from: faceAnchor)
                        }

                        // Track captured angles
                        if let angle = calculateFaceAngle() {
                            capturedAngles.insert(angle)
                        }
                        updateScanProgress()
                    }
                }
            }
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Supporting Types

struct BoundingBox {
    let min: SIMD3<Float>
    let max: SIMD3<Float>

    func contains(_ point: SIMD3<Float>) -> Bool {
        return point.x >= min.x && point.x <= max.x &&
               point.y >= min.y && point.y <= max.y &&
               point.z >= min.z && point.z <= max.z
    }
}

/// Captured texture frame data
struct CapturedTextureFrame {
    let image: CGImage
    let timestamp: TimeInterval
    let transform: simd_float4x4  // Camera transform when captured
    let intrinsics: simd_float3x3  // Camera intrinsics
    let imageResolution: CGSize
}

/// Captured face geometry data from TrueDepth camera
/// Stores copied vertex data since ARFaceGeometry buffers are invalidated after each frame
struct CapturedFaceGeometry {
    let vertices: [SIMD3<Float>]
    let textureCoordinates: [SIMD2<Float>]
    let triangleIndices: [Int16]
    let triangleCount: Int
    let transform: simd_float4x4  // Face transform when captured
    let timestamp: Date
    let angle: Int?  // Face angle bucket when captured

    init(from faceAnchor: ARFaceAnchor, angle: Int?) {
        let geometry = faceAnchor.geometry

        // Safely copy vertices using Array initializer (atomic copy)
        self.vertices = Array(geometry.vertices).map { SIMD3<Float>($0.x, $0.y, $0.z) }

        // Safely copy texture coordinates
        self.textureCoordinates = Array(geometry.textureCoordinates).map { SIMD2<Float>($0.x, $0.y) }

        // Safely copy triangle indices (ARFaceGeometry uses Int16 for indices)
        self.triangleIndices = Array(geometry.triangleIndices)
        self.triangleCount = geometry.triangleCount

        self.transform = faceAnchor.transform
        self.timestamp = Date()
        self.angle = angle
    }
}

/// Texture data for the mesh
struct MeshTextureData {
    let frames: [CapturedTextureFrame]
    let atlasImage: CGImage?  // Combined texture atlas
    let atlasSize: CGSize

    var frameCount: Int { frames.count }
}

struct CapturedMesh {
    let id = UUID()
    let vertices: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let faces: [[Int]]
    let textureCoordinates: [SIMD2<Float>]?
    let textureData: MeshTextureData?
    let scanMode: LiDARScanningService.ScanMode
    let captureDate: Date

    var vertexCount: Int { vertices.count }
    var faceCount: Int { faces.count }
    var hasTexture: Bool { textureData != nil && textureCoordinates != nil }

    // Calculate bounding box
    var boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>) {
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

    // Calculate mesh dimensions
    var dimensions: SIMD3<Float> {
        let box = boundingBox
        return box.max - box.min
    }
}
