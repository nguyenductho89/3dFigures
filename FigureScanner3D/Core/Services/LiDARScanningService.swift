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
            min: SIMD3<Float>(-0.15, -0.20, -0.15),
            max: SIMD3<Float>(0.15, 0.15, 0.10)
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
            min: SIMD3<Float>(-0.18, -0.25, -0.18),
            max: SIMD3<Float>(0.18, 0.18, 0.12)
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
            min: SIMD3<Float>(-0.12, -0.18, -0.12),
            max: SIMD3<Float>(0.12, 0.12, 0.08)
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

        // Process captured mesh
        processCapturedMesh()
    }

    func resetScan() {
        isScanning = false
        scanProgress = 0.0
        meshAnchors.removeAll()
        capturedAngles.removeAll()
        capturedTextureFrames.removeAll()
        capturedMesh = nil
        faceAnchor = nil
        errorMessage = nil
        lastTextureCapture = .distantPast
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
        // Use world tracking with scene reconstruction for LiDAR mesh
        // Combined with face tracking for face detection
        let configuration = ARWorldTrackingConfiguration()

        if Self.isLiDARAvailable {
            configuration.sceneReconstruction = .meshWithClassification
            configuration.environmentTexturing = .automatic
        }

        // Enable face tracking if available
        if Self.isFaceTrackingAvailable {
            configuration.userFaceTrackingEnabled = true
        }

        configuration.frameSemantics.insert(.personSegmentation)
        configuration.planeDetection = []

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

                // Filter vertices based on scan bounds (for face scan)
                if scanMode == .face {
                    if let faceTransform = faceTransform {
                        // Convert to face-local space
                        let faceInverse = faceTransform.inverse
                        let localVertex = faceInverse * worldVertex

                        if configuration.faceScanBounds.contains(SIMD3<Float>(localVertex.x, localVertex.y, localVertex.z)) {
                            allVertices.append(SIMD3<Float>(worldVertex.x, worldVertex.y, worldVertex.z))
                        }
                    }
                } else {
                    allVertices.append(SIMD3<Float>(worldVertex.x, worldVertex.y, worldVertex.z))
                }
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
            // Use the best frame for texture projection
            let (atlasImage, atlasSize) = createTextureAtlas()
            let bestFrame = capturedTextureFrames[capturedTextureFrames.count / 2]

            textureCoords = generateTextureCoordinates(
                vertices: allVertices,
                cameraTransform: bestFrame.transform,
                intrinsics: bestFrame.intrinsics,
                imageResolution: bestFrame.imageResolution
            )

            textureData = MeshTextureData(
                frames: capturedTextureFrames,
                atlasImage: atlasImage,
                atlasSize: atlasSize
            )
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
        // Calculate progress based on captured angles
        let angleProgress = Float(capturedAngles.count) / Float(configuration.requiredAngles)

        // Also consider mesh density
        let meshDensity = min(Float(meshAnchors.count) / Float(configuration.meshDensityTarget), 1.0)

        scanProgress = min((angleProgress + meshDensity) / 2.0, 1.0)
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
            for anchor in frame.anchors {
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

                    // Track captured angles
                    if isScanning, let angle = calculateFaceAngle() {
                        capturedAngles.insert(angle)
                        updateScanProgress()
                    }
                }
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
                    self.faceTransform = faceAnchor.transform
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
