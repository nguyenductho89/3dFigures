# Technical Architecture Document
## 3D Figure Scanner App

**Version**: 1.1
**Last Updated**: December 2024
**Author**: Engineering Team
**Status**: Implementation In Progress

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-12 | Initial architecture design |
| 1.1 | 2024-12-29 | Added implemented LiDAR scanning services (LiDARScanningService, MeshProcessingService, MeshExportService) |

---

## Table of Contents
1. [System Overview](#1-system-overview)
2. [Technology Stack](#2-technology-stack)
3. [App Architecture](#3-app-architecture)
4. [Module Structure](#4-module-structure)
5. [3D Scanning Pipeline](#5-3d-scanning-pipeline)
6. [Data Models](#6-data-models)
7. [Storage Architecture](#7-storage-architecture)
8. [Performance Architecture](#8-performance-architecture)
9. [Security Architecture](#9-security-architecture)
10. [Testing Architecture](#10-testing-architecture)
11. [CI/CD Pipeline](#11-cicd-pipeline)
12. [Third-Party Dependencies](#12-third-party-dependencies)
13. [API Specifications](#13-api-specifications)
14. [Error Handling](#14-error-handling)
15. [Appendix](#15-appendix)

---

## 1. System Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        3D Figure Scanner App                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │  Presentation │  │   Domain     │  │    Data      │              │
│  │    Layer      │  │   Layer      │  │   Layer      │              │
│  │              │  │              │  │              │              │
│  │  • SwiftUI   │  │  • Use Cases │  │  • Core Data │              │
│  │  • ViewModels│  │  • Entities  │  │  • File Mgmt │              │
│  │  • Views     │  │  • Protocols │  │  • ARKit     │              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
│         │                 │                 │                       │
│         └─────────────────┼─────────────────┘                       │
│                           │                                         │
│  ┌────────────────────────┴────────────────────────┐               │
│  │              Core Services Layer                 │               │
│  │                                                  │               │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐│               │
│  │  │  Scanning   │  │    Mesh     │  │  Export  ││               │
│  │  │  Engine     │  │  Processor  │  │  Engine  ││               │
│  │  └─────────────┘  └─────────────┘  └──────────┘│               │
│  └─────────────────────────────────────────────────┘               │
│                           │                                         │
├───────────────────────────┼─────────────────────────────────────────┤
│                    Apple Frameworks                                  │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐      │
│  │  ARKit  │ │ Vision  │ │  Metal  │ │SceneKit │ │RealityKit│      │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘      │
├─────────────────────────────────────────────────────────────────────┤
│                        Hardware Layer                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
│  │   LiDAR     │  │  RGB Camera │  │  TrueDepth  │                 │
│  │   Scanner   │  │             │  │   Camera    │                 │
│  └─────────────┘  └─────────────┘  └─────────────┘                 │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 System Context Diagram

```
                                    ┌─────────────┐
                                    │   User      │
                                    └──────┬──────┘
                                           │
                                           ▼
┌──────────────────────────────────────────────────────────────────┐
│                     3D Figure Scanner App                         │
│                                                                   │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐          │
│  │   Scan      │───▶│   Process   │───▶│   Export    │          │
│  │   Module    │    │   Module    │    │   Module    │          │
│  └─────────────┘    └─────────────┘    └─────────────┘          │
└──────────────────────────────────────────────────────────────────┘
         │                                        │
         ▼                                        ▼
┌─────────────────┐                    ┌─────────────────┐
│  Local Storage  │                    │  External Apps  │
│  • Core Data    │                    │  • Files App    │
│  • File System  │                    │  • 3D Printers  │
└─────────────────┘                    │  • Slicers      │
                                       │  • Cloud        │
                                       └─────────────────┘
```

---

## 2. Technology Stack

### 2.1 Core Technologies

| Layer | Technology | Purpose |
|-------|------------|---------|
| Language | Swift 5.9+ | Primary development language |
| UI Framework | SwiftUI | Declarative UI |
| Architecture | MVVM + Clean Architecture | Code organization |
| Async | Swift Concurrency (async/await) | Asynchronous operations |
| DI | Swift DI / Factory Pattern | Dependency injection |

### 2.2 Apple Frameworks

| Framework | Version | Purpose |
|-----------|---------|---------|
| ARKit | 6.0+ | LiDAR scanning, scene reconstruction |
| RealityKit | 2.0+ | AR preview, 3D rendering |
| SceneKit | Latest | 3D model preview |
| Vision | Latest | Face detection |
| Metal | 3.0+ | GPU compute, mesh processing |
| Model I/O | Latest | 3D file import/export |
| Core Data | Latest | Local persistence |
| AVFoundation | Latest | Camera capture |
| CoreImage | Latest | Image processing |
| Accelerate | Latest | Math operations |

### 2.3 Development Requirements

| Requirement | Specification |
|-------------|---------------|
| Xcode | 15.0+ |
| iOS Deployment Target | 16.0+ |
| Swift Version | 5.9+ |
| macOS (Development) | Sonoma 14.0+ |

---

## 3. App Architecture

### 3.1 Clean Architecture + MVVM

```
┌─────────────────────────────────────────────────────────────────┐
│                      Presentation Layer                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                         Views                                ││
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       ││
│  │  │HomeView  │ │ScanView  │ │PreviewView│ │ExportView│       ││
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘       ││
│  └───────┼────────────┼────────────┼────────────┼───────────────┘│
│          │            │            │            │                │
│  ┌───────┴────────────┴────────────┴────────────┴───────────────┐│
│  │                      ViewModels                              ││
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       ││
│  │  │HomeVM    │ │ScanVM    │ │PreviewVM │ │ExportVM  │       ││
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘       ││
│  └──────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Domain Layer                              │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │                       Use Cases                              ││
│  │  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐   ││
│  │  │StartFaceScan   │ │ProcessMesh     │ │ExportModel     │   ││
│  │  │StartBodyScan   │ │EditMesh        │ │ShareModel      │   ││
│  │  │StopScan        │ │GenerateBase    │ │SaveToGallery   │   ││
│  │  └────────────────┘ └────────────────┘ └────────────────┘   ││
│  └──────────────────────────────────────────────────────────────┘│
│  ┌──────────────────────────────────────────────────────────────┐│
│  │                       Entities                               ││
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐               ││
│  │  │ScanSession │ │Mesh3D      │ │ExportConfig│               ││
│  │  │ScanType    │ │Texture     │ │ScanProject │               ││
│  │  └────────────┘ └────────────┘ └────────────┘               ││
│  └──────────────────────────────────────────────────────────────┘│
│  ┌──────────────────────────────────────────────────────────────┐│
│  │                    Repository Protocols                      ││
│  │  ┌─────────────────────┐ ┌─────────────────────┐            ││
│  │  │ScanRepositoryProtocol│ │ProjectRepositoryProtocol│        ││
│  │  └─────────────────────┘ └─────────────────────┘            ││
│  └──────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Data Layer                               │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │                    Repositories                              ││
│  │  ┌────────────────┐ ┌────────────────┐                      ││
│  │  │ScanRepository  │ │ProjectRepository│                      ││
│  │  └────────────────┘ └────────────────┘                      ││
│  └──────────────────────────────────────────────────────────────┘│
│  ┌──────────────────────────────────────────────────────────────┐│
│  │                    Data Sources                              ││
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐         ││
│  │  │ARKitDataSource│ │CoreDataSource│ │FileDataSource│         ││
│  │  └──────────────┘ └──────────────┘ └──────────────┘         ││
│  └──────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Data Flow (Unidirectional)

```
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│    User Action                                                 │
│        │                                                       │
│        ▼                                                       │
│    ┌───────┐     ┌──────────┐     ┌─────────┐     ┌────────┐ │
│    │ View  │────▶│ViewModel │────▶│Use Case │────▶│  Repo  │ │
│    └───────┘     └──────────┘     └─────────┘     └────────┘ │
│        ▲              │                                │      │
│        │              │                                │      │
│        │         State Update                     Data │      │
│        │              │                                │      │
│        │              ▼                                ▼      │
│    ┌───────┐     ┌──────────┐                   ┌────────┐   │
│    │ View  │◀────│  State   │◀──────────────────│  Data  │   │
│    └───────┘     └──────────┘                   │ Source │   │
│                                                 └────────┘   │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### 3.3 State Management

```swift
// AppState.swift
@MainActor
final class AppState: ObservableObject {
    @Published var currentScan: ScanSession?
    @Published var scanHistory: [ScanProject] = []
    @Published var isScanning: Bool = false
    @Published var processingState: ProcessingState = .idle
    @Published var exportState: ExportState = .idle
}

enum ProcessingState: Equatable {
    case idle
    case processing(progress: Double)
    case completed(mesh: Mesh3D)
    case failed(error: ProcessingError)
}

enum ExportState: Equatable {
    case idle
    case exporting(progress: Double)
    case completed(url: URL)
    case failed(error: ExportError)
}
```

---

## 4. Module Structure

### 4.1 Project Structure

```
3DFigureScanner/
├── App/
│   ├── 3DFigureScannerApp.swift
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── AppConfiguration.swift
│
├── Presentation/
│   ├── Common/
│   │   ├── Components/
│   │   │   ├── LoadingView.swift
│   │   │   ├── ErrorView.swift
│   │   │   ├── ProgressRing.swift
│   │   │   └── GradientButton.swift
│   │   ├── Modifiers/
│   │   │   └── ViewModifiers.swift
│   │   └── Extensions/
│   │       └── View+Extensions.swift
│   │
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   └── Components/
│   │       ├── ScanTypeCard.swift
│   │       └── RecentScansGrid.swift
│   │
│   ├── Scanning/
│   │   ├── ScanView.swift
│   │   ├── ScanViewModel.swift
│   │   ├── FaceScanView.swift
│   │   ├── BodyScanView.swift
│   │   ├── BustScanView.swift
│   │   └── Components/
│   │       ├── ScanGuidanceOverlay.swift
│   │       ├── DistanceIndicator.swift
│   │       ├── LightingIndicator.swift
│   │       ├── ProgressTracker.swift
│   │       └── ARViewContainer.swift
│   │
│   ├── Preview/
│   │   ├── PreviewView.swift
│   │   ├── PreviewViewModel.swift
│   │   ├── ARPreviewView.swift
│   │   └── Components/
│   │       ├── MeshViewer.swift
│   │       ├── MeshInfoPanel.swift
│   │       └── ViewModeToggle.swift
│   │
│   ├── Editor/
│   │   ├── EditorView.swift
│   │   ├── EditorViewModel.swift
│   │   └── Components/
│   │       ├── CropTool.swift
│   │       ├── ScaleTool.swift
│   │       └── BaseTool.swift
│   │
│   ├── Export/
│   │   ├── ExportView.swift
│   │   ├── ExportViewModel.swift
│   │   └── Components/
│   │       ├── FormatSelector.swift
│   │       ├── SizeSelector.swift
│   │       └── QualitySelector.swift
│   │
│   ├── Gallery/
│   │   ├── GalleryView.swift
│   │   ├── GalleryViewModel.swift
│   │   └── Components/
│   │       ├── ProjectCard.swift
│   │       └── ProjectDetailSheet.swift
│   │
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
│
├── Domain/
│   ├── Entities/
│   │   ├── ScanSession.swift
│   │   ├── ScanType.swift
│   │   ├── Mesh3D.swift
│   │   ├── Texture.swift
│   │   ├── ScanProject.swift
│   │   ├── ExportConfig.swift
│   │   └── ExportFormat.swift
│   │
│   ├── UseCases/
│   │   ├── Scanning/
│   │   │   ├── StartFaceScanUseCase.swift
│   │   │   ├── StartBodyScanUseCase.swift
│   │   │   ├── StartBustScanUseCase.swift
│   │   │   ├── StopScanUseCase.swift
│   │   │   └── PauseScanUseCase.swift
│   │   │
│   │   ├── Processing/
│   │   │   ├── ProcessMeshUseCase.swift
│   │   │   ├── RepairMeshUseCase.swift
│   │   │   ├── SmoothMeshUseCase.swift
│   │   │   └── GenerateBaseUseCase.swift
│   │   │
│   │   ├── Export/
│   │   │   ├── ExportSTLUseCase.swift
│   │   │   ├── ExportOBJUseCase.swift
│   │   │   ├── ExportGLTFUseCase.swift
│   │   │   └── ExportUSDZUseCase.swift
│   │   │
│   │   └── Gallery/
│   │       ├── SaveProjectUseCase.swift
│   │       ├── LoadProjectsUseCase.swift
│   │       └── DeleteProjectUseCase.swift
│   │
│   └── Protocols/
│       ├── ScanRepositoryProtocol.swift
│       ├── MeshRepositoryProtocol.swift
│       ├── ProjectRepositoryProtocol.swift
│       └── ExportRepositoryProtocol.swift
│
├── Data/
│   ├── Repositories/
│   │   ├── ScanRepository.swift
│   │   ├── MeshRepository.swift
│   │   ├── ProjectRepository.swift
│   │   └── ExportRepository.swift
│   │
│   ├── DataSources/
│   │   ├── Local/
│   │   │   ├── CoreDataManager.swift
│   │   │   ├── FileManager+Extension.swift
│   │   │   └── ProjectLocalDataSource.swift
│   │   │
│   │   └── ARKit/
│   │       ├── ARSessionManager.swift
│   │       ├── LiDARDataSource.swift
│   │       └── FaceTrackingDataSource.swift
│   │
│   ├── Models/
│   │   ├── CoreData/
│   │   │   ├── 3DFigureScanner.xcdatamodeld
│   │   │   ├── ProjectEntity+CoreDataClass.swift
│   │   │   └── ProjectEntity+CoreDataProperties.swift
│   │   │
│   │   └── DTOs/
│   │       ├── MeshDTO.swift
│   │       └── ProjectDTO.swift
│   │
│   └── Mappers/
│       ├── ProjectMapper.swift
│       └── MeshMapper.swift
│
├── Core/
│   ├── Scanning/
│   │   ├── ScanningEngine.swift
│   │   ├── FaceScanningEngine.swift
│   │   ├── BodyScanningEngine.swift
│   │   ├── PointCloudGenerator.swift
│   │   ├── MeshReconstructor.swift
│   │   └── TextureCapture.swift
│   │
│   ├── MeshProcessing/
│   │   ├── MeshProcessor.swift
│   │   ├── HoleFiller.swift
│   │   ├── NoiseReducer.swift
│   │   ├── MeshSmoother.swift
│   │   ├── ManifoldChecker.swift
│   │   ├── MeshDecimator.swift
│   │   └── BaseGenerator.swift
│   │
│   ├── Export/
│   │   ├── ExportEngine.swift
│   │   ├── STLExporter.swift
│   │   ├── OBJExporter.swift
│   │   ├── GLTFExporter.swift
│   │   ├── USDZExporter.swift
│   │   ├── PLYExporter.swift
│   │   └── HollowGenerator.swift
│   │
│   ├── Metal/
│   │   ├── MetalManager.swift
│   │   ├── Shaders/
│   │   │   ├── MeshProcessing.metal
│   │   │   ├── PointCloudProcessing.metal
│   │   │   └── TextureProcessing.metal
│   │   └── ComputePipelines/
│   │       ├── MeshComputePipeline.swift
│   │       └── TextureComputePipeline.swift
│   │
│   └── Utilities/
│       ├── MathUtils.swift
│       ├── GeometryUtils.swift
│       └── ColorUtils.swift
│
├── Infrastructure/
│   ├── DI/
│   │   ├── Container.swift
│   │   └── Resolver.swift
│   │
│   ├── Navigation/
│   │   ├── Router.swift
│   │   ├── AppCoordinator.swift
│   │   └── Routes.swift
│   │
│   ├── Analytics/
│   │   ├── AnalyticsService.swift
│   │   └── AnalyticsEvent.swift
│   │
│   └── Logging/
│       └── Logger.swift
│
├── Resources/
│   ├── Assets.xcassets/
│   ├── Localizable.strings
│   ├── LaunchScreen.storyboard
│   └── Info.plist
│
└── Tests/
    ├── UnitTests/
    │   ├── Domain/
    │   ├── Data/
    │   └── Core/
    │
    ├── IntegrationTests/
    │
    └── UITests/
```

### 4.2 Module Dependencies

```
┌─────────────────────────────────────────────────────────────────┐
│                          App Module                              │
│  (Entry point, DI setup, Navigation)                            │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Presentation Module                          │
│  (Views, ViewModels, UI Components)                             │
│  Dependencies: Domain, Infrastructure                            │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Domain Module                              │
│  (Entities, Use Cases, Repository Protocols)                    │
│  Dependencies: None (Pure Swift)                                 │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Data Module                               │
│  (Repository Implementations, Data Sources, Mappers)            │
│  Dependencies: Domain, Core                                      │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Core Module                               │
│  (Scanning Engine, Mesh Processing, Export, Metal)              │
│  Dependencies: Apple Frameworks (ARKit, Metal, etc.)            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. 3D Scanning Pipeline

### 5.1 Overall Scanning Pipeline

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        3D Scanning Pipeline                              │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌────────────┐
│   Stage 1    │    │   Stage 2    │    │   Stage 3    │    │  Stage 4   │
│   Capture    │───▶│ Point Cloud  │───▶│    Mesh      │───▶│  Texture   │
│              │    │  Generation  │    │ Reconstruction    │  Mapping   │
└──────────────┘    └──────────────┘    └──────────────┘    └────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌────────────┐
│ • LiDAR Data │    │ • Depth to   │    │ • Poisson    │    │ • UV       │
│ • RGB Frames │    │   3D Points  │    │   Surface    │    │   Unwrap   │
│ • Camera     │    │ • Filtering  │    │ • Marching   │    │ • Texture  │
│   Pose       │    │ • Registration    │   Cubes      │    │   Baking   │
│ • Depth Maps │    │ • Merging    │    │ • Ball       │    │ • Color    │
└──────────────┘    └──────────────┘    │   Pivoting   │    │   Correct  │
                                        └──────────────┘    └────────────┘
                                               │
                                               ▼
                                        ┌──────────────┐    ┌────────────┐
                                        │   Stage 5    │    │  Stage 6   │
                                        │    Post      │───▶│   Output   │
                                        │  Processing  │    │            │
                                        └──────────────┘    └────────────┘
                                               │                   │
                                               ▼                   ▼
                                        ┌──────────────┐    ┌────────────┐
                                        │ • Hole Fill  │    │ • Mesh3D   │
                                        │ • Smoothing  │    │ • Texture  │
                                        │ • Decimation │    │ • Metadata │
                                        │ • Manifold   │    │            │
                                        └──────────────┘    └────────────┘
```

### 5.2 Face Scanning Pipeline

```swift
// FaceScanningEngine.swift

final class FaceScanningEngine: NSObject {

    // MARK: - Properties
    private let arSession: ARSession
    private let pointCloudGenerator: PointCloudGenerator
    private let meshReconstructor: MeshReconstructor
    private let textureCapture: TextureCapture

    private var capturedFrames: [CapturedFrame] = []
    private var currentPointCloud: PointCloud?

    // MARK: - Configuration
    struct Configuration {
        let targetDistance: ClosedRange<Float> = 0.3...0.5  // 30-50cm
        let minimumVertices: Int = 50_000
        let captureInterval: TimeInterval = 0.1  // 10 FPS capture
        let requiredAngles: [Float] = [-45, -30, -15, 0, 15, 30, 45]  // degrees
    }

    // MARK: - Pipeline Stages

    func startScanning() async throws -> AsyncThrowingStream<ScanProgress, Error> {
        AsyncThrowingStream { continuation in
            // Stage 1: Configure ARSession
            let config = ARFaceTrackingConfiguration()
            config.isLightEstimationEnabled = true
            config.maximumNumberOfTrackedFaces = 1

            arSession.delegate = self
            arSession.run(config)

            // ... scanning loop
        }
    }

    // Stage 2: Capture Frame
    private func captureFrame(_ frame: ARFrame, faceAnchor: ARFaceAnchor) -> CapturedFrame {
        CapturedFrame(
            depthMap: frame.sceneDepth?.depthMap,
            colorImage: frame.capturedImage,
            cameraTransform: frame.camera.transform,
            faceTransform: faceAnchor.transform,
            faceGeometry: faceAnchor.geometry,
            timestamp: frame.timestamp
        )
    }

    // Stage 3: Generate Point Cloud
    private func generatePointCloud(from frames: [CapturedFrame]) async -> PointCloud {
        await pointCloudGenerator.generate(from: frames)
    }

    // Stage 4: Reconstruct Mesh
    private func reconstructMesh(from pointCloud: PointCloud) async -> RawMesh {
        await meshReconstructor.reconstruct(
            pointCloud: pointCloud,
            algorithm: .poissonSurface(depth: 8)
        )
    }

    // Stage 5: Apply Texture
    private func applyTexture(to mesh: RawMesh, frames: [CapturedFrame]) async -> TexturedMesh {
        await textureCapture.applyTexture(
            to: mesh,
            from: frames,
            resolution: .high  // 2048x2048
        )
    }
}
```

### 5.3 Body Scanning Pipeline

```swift
// BodyScanningEngine.swift

final class BodyScanningEngine {

    // MARK: - Configuration
    struct Configuration {
        let targetDistance: ClosedRange<Float> = 1.0...2.0  // 1-2m
        let minimumVertices: Int = 200_000
        let fullRotation: Float = 360  // degrees
        let verticalSections: Int = 3  // head, torso, legs
    }

    // MARK: - State
    private var scanSegments: [ScanSegment] = []
    private var currentAngle: Float = 0
    private var coveredAngles: Set<Int> = []

    // MARK: - Pipeline

    func startScanning() async throws -> AsyncThrowingStream<BodyScanProgress, Error> {
        AsyncThrowingStream { continuation in
            // Configure ARWorldTracking với Scene Reconstruction
            let config = ARWorldTrackingConfiguration()
            config.sceneReconstruction = .meshWithClassification
            config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]

            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                arSession.run(config)
            }

            // ... body scanning loop
        }
    }

    // Continuous mesh capture as user walks around
    private func captureMeshSegment(
        _ frame: ARFrame,
        anchors: [ARMeshAnchor]
    ) -> MeshSegment {
        var combinedVertices: [SIMD3<Float>] = []
        var combinedFaces: [SIMD3<UInt32>] = []

        for anchor in anchors {
            let geometry = anchor.geometry
            let vertices = extractVertices(from: geometry)
            let faces = extractFaces(from: geometry)

            // Transform to world coordinates
            let worldVertices = vertices.map { vertex in
                anchor.transform * SIMD4<Float>(vertex, 1)
            }

            combinedVertices.append(contentsOf: worldVertices.map { SIMD3($0.x, $0.y, $0.z) })
            combinedFaces.append(contentsOf: faces)
        }

        return MeshSegment(
            vertices: combinedVertices,
            faces: combinedFaces,
            angle: currentAngle,
            timestamp: frame.timestamp
        )
    }

    // Merge all segments into final mesh
    private func mergeMeshSegments(_ segments: [MeshSegment]) async -> RawMesh {
        await meshMerger.merge(
            segments: segments,
            overlapThreshold: 0.02,  // 2cm overlap detection
            smoothingPasses: 2
        )
    }
}
```

### 5.4 ARKit Scene Reconstruction Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    ARKit Scene Reconstruction                            │
└─────────────────────────────────────────────────────────────────────────┘

        ARSession                ARFrame                  ARMeshAnchor
            │                       │                          │
            │   didUpdate          │                          │
            ├──────────────────────▶                          │
            │                       │                          │
            │                       │  sceneDepth              │
            │                       ├─────────────────────────▶│
            │                       │                          │
            │                       │  meshAnchors             │
            │                       ├─────────────────────────▶│
            │                       │                          │
            ▼                       ▼                          ▼
┌─────────────────┐     ┌─────────────────┐      ┌─────────────────────┐
│  Configuration  │     │   Frame Data    │      │    Mesh Geometry    │
├─────────────────┤     ├─────────────────┤      ├─────────────────────┤
│• sceneRecon-    │     │• depthMap       │      │• vertices           │
│  struction      │     │• confidenceMap  │      │• normals            │
│• frameSemantics │     │• capturedImage  │      │• faces              │
│• planeDetection │     │• cameraTransform│      │• classification     │
└─────────────────┘     └─────────────────┘      └─────────────────────┘
                                │
                                ▼
                    ┌─────────────────────┐
                    │  Mesh Processing    │
                    ├─────────────────────┤
                    │ 1. Extract vertices │
                    │ 2. Transform coords │
                    │ 3. Merge overlaps   │
                    │ 4. Apply texture    │
                    └─────────────────────┘
```

### 5.5 Mesh Processing Pipeline

```swift
// MeshProcessor.swift

final class MeshProcessor {

    private let holeFiller: HoleFiller
    private let noiseReducer: NoiseReducer
    private let meshSmoother: MeshSmoother
    private let manifoldChecker: ManifoldChecker
    private let meshDecimator: MeshDecimator

    struct ProcessingOptions {
        var fillHoles: Bool = true
        var reduceNoise: Bool = true
        var smoothingPasses: Int = 2
        var smoothingFactor: Float = 0.5
        var targetVertexCount: Int? = nil  // For decimation
        var ensureManifold: Bool = true
    }

    func process(
        _ mesh: RawMesh,
        options: ProcessingOptions,
        progressHandler: @escaping (ProcessingProgress) -> Void
    ) async throws -> ProcessedMesh {

        var currentMesh = mesh
        var totalSteps = 5
        var currentStep = 0

        // Step 1: Hole Filling
        if options.fillHoles {
            progressHandler(.step(currentStep, totalSteps, "Filling holes..."))
            currentMesh = await holeFiller.fill(currentMesh)
            currentStep += 1
        }

        // Step 2: Noise Reduction
        if options.reduceNoise {
            progressHandler(.step(currentStep, totalSteps, "Reducing noise..."))
            currentMesh = await noiseReducer.reduce(
                currentMesh,
                threshold: 0.005  // 5mm noise threshold
            )
            currentStep += 1
        }

        // Step 3: Smoothing
        if options.smoothingPasses > 0 {
            progressHandler(.step(currentStep, totalSteps, "Smoothing surface..."))
            currentMesh = await meshSmoother.smooth(
                currentMesh,
                passes: options.smoothingPasses,
                factor: options.smoothingFactor,
                algorithm: .laplacian
            )
            currentStep += 1
        }

        // Step 4: Decimation (if needed)
        if let targetCount = options.targetVertexCount,
           currentMesh.vertexCount > targetCount {
            progressHandler(.step(currentStep, totalSteps, "Optimizing mesh..."))
            currentMesh = await meshDecimator.decimate(
                currentMesh,
                targetVertexCount: targetCount,
                preserveBoundaries: true
            )
            currentStep += 1
        }

        // Step 5: Manifold Check & Repair
        if options.ensureManifold {
            progressHandler(.step(currentStep, totalSteps, "Ensuring printability..."))
            let result = await manifoldChecker.checkAndRepair(currentMesh)
            currentMesh = result.mesh
            currentStep += 1
        }

        progressHandler(.completed)

        return ProcessedMesh(
            mesh: currentMesh,
            isManifold: true,
            vertexCount: currentMesh.vertexCount,
            faceCount: currentMesh.faceCount
        )
    }
}
```

### 5.6 Metal Compute Shaders

```metal
// MeshProcessing.metal

#include <metal_stdlib>
using namespace metal;

// Vertex structure
struct Vertex {
    float3 position;
    float3 normal;
    float2 uv;
};

// Laplacian smoothing kernel
kernel void laplacianSmooth(
    device Vertex* vertices [[buffer(0)]],
    device const uint* adjacency [[buffer(1)]],
    device const uint* adjacencyOffsets [[buffer(2)]],
    constant float& factor [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    uint startIdx = adjacencyOffsets[id];
    uint endIdx = adjacencyOffsets[id + 1];
    uint neighborCount = endIdx - startIdx;

    if (neighborCount == 0) return;

    float3 centroid = float3(0.0);

    for (uint i = startIdx; i < endIdx; i++) {
        uint neighborIdx = adjacency[i];
        centroid += vertices[neighborIdx].position;
    }

    centroid /= float(neighborCount);

    // Move vertex towards centroid
    vertices[id].position = mix(
        vertices[id].position,
        centroid,
        factor
    );
}

// Noise reduction kernel
kernel void reduceNoise(
    device Vertex* vertices [[buffer(0)]],
    device const float* noiseEstimate [[buffer(1)]],
    constant float& threshold [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    if (noiseEstimate[id] > threshold) {
        // Apply bilateral filter
        // ... implementation
    }
}

// Normal recalculation kernel
kernel void recalculateNormals(
    device Vertex* vertices [[buffer(0)]],
    device const uint3* faces [[buffer(1)]],
    device atomic_uint* normalAccum [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    uint3 face = faces[id];

    float3 v0 = vertices[face.x].position;
    float3 v1 = vertices[face.y].position;
    float3 v2 = vertices[face.z].position;

    float3 normal = normalize(cross(v1 - v0, v2 - v0));

    // Accumulate normals for each vertex
    // ... atomic operations
}
```

---

## 6. Data Models

### 6.1 Domain Entities

```swift
// ScanSession.swift
struct ScanSession: Identifiable {
    let id: UUID
    let type: ScanType
    let startTime: Date
    var endTime: Date?
    var status: ScanStatus
    var progress: Double
    var capturedFrames: Int
    var quality: ScanQuality
}

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

    var targetDistance: ClosedRange<Float> {
        switch self {
        case .face: return 0.3...0.5
        case .body: return 1.0...2.0
        case .bust: return 0.5...1.0
        }
    }
}

enum ScanStatus: String, Codable {
    case preparing
    case scanning
    case processing
    case completed
    case failed
    case cancelled
}

enum ScanQuality: String, Codable {
    case low
    case medium
    case high
    case ultra

    var targetVertexCount: Int {
        switch self {
        case .low: return 50_000
        case .medium: return 100_000
        case .high: return 200_000
        case .ultra: return 500_000
        }
    }
}
```

```swift
// Mesh3D.swift
struct Mesh3D {
    let id: UUID
    var vertices: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var uvCoordinates: [SIMD2<Float>]
    var faces: [SIMD3<UInt32>]
    var texture: Texture?

    var vertexCount: Int { vertices.count }
    var faceCount: Int { faces.count }

    var boundingBox: BoundingBox {
        BoundingBox(vertices: vertices)
    }

    var isManifold: Bool {
        // Check if mesh is closed and printable
        ManifoldChecker.check(self)
    }
}

struct BoundingBox {
    let min: SIMD3<Float>
    let max: SIMD3<Float>

    var size: SIMD3<Float> {
        max - min
    }

    var center: SIMD3<Float> {
        (min + max) / 2
    }

    init(vertices: [SIMD3<Float>]) {
        var minV = SIMD3<Float>(repeating: .infinity)
        var maxV = SIMD3<Float>(repeating: -.infinity)

        for v in vertices {
            minV = min(minV, v)
            maxV = max(maxV, v)
        }

        self.min = minV
        self.max = maxV
    }
}
```

```swift
// Texture.swift
struct Texture {
    let id: UUID
    let image: CGImage
    let width: Int
    let height: Int
    let format: TextureFormat

    enum TextureFormat {
        case rgba8
        case rgb8
        case compressed
    }
}
```

```swift
// ScanProject.swift
struct ScanProject: Identifiable, Codable {
    let id: UUID
    var name: String
    let type: ScanType
    let createdAt: Date
    var modifiedAt: Date
    var meshFileURL: URL
    var textureFileURL: URL?
    var thumbnailURL: URL?
    var metadata: ProjectMetadata
}

struct ProjectMetadata: Codable {
    var vertexCount: Int
    var faceCount: Int
    var boundingBoxSize: SIMD3<Float>
    var hasTexture: Bool
    var isManifold: Bool
    var scanDuration: TimeInterval
    var deviceModel: String
}
```

```swift
// ExportConfig.swift
struct ExportConfig {
    var format: ExportFormat
    var scale: Float = 1.0
    var targetHeight: Float?  // in cm
    var unit: ExportUnit = .millimeters
    var includeTexture: Bool = true
    var textureResolution: TextureResolution = .high
    var makeHollow: Bool = false
    var wallThickness: Float = 2.0  // mm
    var addDrainHoles: Bool = false
}

enum ExportFormat: String, CaseIterable {
    case stl
    case obj
    case gltf
    case glb
    case usdz
    case ply

    var fileExtension: String { rawValue }

    var supportsTexture: Bool {
        switch self {
        case .stl, .ply: return false
        case .obj, .gltf, .glb, .usdz: return true
        }
    }

    var supportsColor: Bool {
        switch self {
        case .stl: return false
        default: return true
        }
    }
}

enum ExportUnit: String, CaseIterable {
    case millimeters = "mm"
    case centimeters = "cm"
    case inches = "in"

    var conversionFactor: Float {
        switch self {
        case .millimeters: return 1.0
        case .centimeters: return 10.0
        case .inches: return 25.4
        }
    }
}

enum TextureResolution: Int, CaseIterable {
    case low = 512
    case medium = 1024
    case high = 2048
    case ultra = 4096

    var displayName: String {
        "\(rawValue)x\(rawValue)"
    }
}
```

### 6.2 Core Data Models

```swift
// ProjectEntity+CoreDataProperties.swift

extension ProjectEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectEntity> {
        return NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var type: String
    @NSManaged public var createdAt: Date
    @NSManaged public var modifiedAt: Date
    @NSManaged public var meshFilePath: String
    @NSManaged public var textureFilePath: String?
    @NSManaged public var thumbnailPath: String?
    @NSManaged public var vertexCount: Int32
    @NSManaged public var faceCount: Int32
    @NSManaged public var boundingBoxX: Float
    @NSManaged public var boundingBoxY: Float
    @NSManaged public var boundingBoxZ: Float
    @NSManaged public var hasTexture: Bool
    @NSManaged public var isManifold: Bool
    @NSManaged public var scanDuration: Double
    @NSManaged public var deviceModel: String
}
```

### 6.3 Data Transfer Objects

```swift
// MeshDTO.swift
struct MeshDTO: Codable {
    let vertexData: Data  // Compressed vertex array
    let normalData: Data
    let uvData: Data?
    let faceData: Data
    let textureData: Data?

    init(from mesh: Mesh3D) {
        self.vertexData = mesh.vertices.withUnsafeBytes { Data($0) }
        self.normalData = mesh.normals.withUnsafeBytes { Data($0) }
        self.uvData = mesh.uvCoordinates.isEmpty ? nil : mesh.uvCoordinates.withUnsafeBytes { Data($0) }
        self.faceData = mesh.faces.withUnsafeBytes { Data($0) }
        self.textureData = mesh.texture?.image.pngData()
    }

    func toMesh() -> Mesh3D {
        // Convert back to Mesh3D
        // ... implementation
    }
}
```

---

## 7. Storage Architecture

### 7.1 Storage Strategy

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Storage Architecture                              │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                           App Sandbox                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────┐  ┌────────────────────┐  ┌──────────────────┐  │
│  │    Documents/      │  │    Library/        │  │     tmp/         │  │
│  │                    │  │                    │  │                  │  │
│  │  ├── Projects/     │  │  ├── Caches/       │  │  ├── Scans/      │  │
│  │  │   ├── {uuid}/   │  │  │   ├── thumbs/   │  │  │   └── temp    │  │
│  │  │   │   ├── mesh  │  │  │   └── exports/  │  │  │       files   │  │
│  │  │   │   ├── tex   │  │  │                 │  │  │               │  │
│  │  │   │   └── meta  │  │  ├── CoreData/     │  │  └── Processing/ │  │
│  │  │   └── ...       │  │  │   └── store     │  │      └── temp    │  │
│  │  │                 │  │  │                 │  │          mesh    │  │
│  │  └── Exports/      │  │  └── Preferences/  │  │                  │  │
│  │      └── temp      │  │      └── settings  │  │                  │  │
│  │                    │  │                    │  │                  │  │
│  └────────────────────┘  └────────────────────┘  └──────────────────┘  │
│                                                                          │
│         User Data            App Data              Temporary             │
│        (Backed up)        (Not backed up)        (Cleared)              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.2 File Storage Manager

```swift
// FileStorageManager.swift

final class FileStorageManager {

    static let shared = FileStorageManager()

    // MARK: - Directory URLs

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var projectsDirectory: URL {
        documentsDirectory.appendingPathComponent("Projects", isDirectory: true)
    }

    private var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    private var thumbnailsDirectory: URL {
        cachesDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    private var tempDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    // MARK: - Project Storage

    func projectDirectory(for projectId: UUID) -> URL {
        projectsDirectory.appendingPathComponent(projectId.uuidString, isDirectory: true)
    }

    func saveMesh(_ mesh: Mesh3D, projectId: UUID) async throws -> URL {
        let directory = projectDirectory(for: projectId)
        try createDirectoryIfNeeded(directory)

        let meshURL = directory.appendingPathComponent("mesh.bin")
        let meshDTO = MeshDTO(from: mesh)
        let data = try JSONEncoder().encode(meshDTO)
        try data.write(to: meshURL)

        return meshURL
    }

    func saveTexture(_ texture: Texture, projectId: UUID) async throws -> URL {
        let directory = projectDirectory(for: projectId)
        let textureURL = directory.appendingPathComponent("texture.png")

        guard let data = texture.image.pngData() else {
            throw StorageError.textureEncodingFailed
        }

        try data.write(to: textureURL)
        return textureURL
    }

    func loadMesh(from url: URL) async throws -> Mesh3D {
        let data = try Data(contentsOf: url)
        let meshDTO = try JSONDecoder().decode(MeshDTO.self, from: data)
        return meshDTO.toMesh()
    }

    // MARK: - Thumbnail Management

    func saveThumbnail(_ image: UIImage, projectId: UUID) async throws -> URL {
        try createDirectoryIfNeeded(thumbnailsDirectory)

        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(projectId.uuidString).jpg")

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.thumbnailEncodingFailed
        }

        try data.write(to: thumbnailURL)
        return thumbnailURL
    }

    // MARK: - Export

    func exportDirectory() -> URL {
        let directory = documentsDirectory.appendingPathComponent("Exports", isDirectory: true)
        try? createDirectoryIfNeeded(directory)
        return directory
    }

    // MARK: - Cleanup

    func deleteProject(_ projectId: UUID) throws {
        let directory = projectDirectory(for: projectId)
        try FileManager.default.removeItem(at: directory)

        // Also delete thumbnail
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(projectId.uuidString).jpg")
        try? FileManager.default.removeItem(at: thumbnailURL)
    }

    func clearTempDirectory() {
        let tempScanDirectory = tempDirectory.appendingPathComponent("Scans")
        try? FileManager.default.removeItem(at: tempScanDirectory)
    }

    func calculateStorageUsed() -> Int64 {
        var totalSize: Int64 = 0

        if let enumerator = FileManager.default.enumerator(
            at: projectsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }

        return totalSize
    }

    // MARK: - Helpers

    private func createDirectoryIfNeeded(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        }
    }
}
```

### 7.3 Core Data Stack

```swift
// CoreDataManager.swift

final class CoreDataManager {

    static let shared = CoreDataManager()

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "3DFigureScanner")

        // Configure for lightweight migration
        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data store failed: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }

    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                Logger.error("Failed to save context: \(error)")
            }
        }
    }

    // MARK: - CRUD Operations

    func createProject(_ project: ScanProject) async throws {
        let context = newBackgroundContext()

        try await context.perform {
            let entity = ProjectEntity(context: context)
            entity.id = project.id
            entity.name = project.name
            entity.type = project.type.rawValue
            entity.createdAt = project.createdAt
            entity.modifiedAt = project.modifiedAt
            entity.meshFilePath = project.meshFileURL.path
            entity.textureFilePath = project.textureFileURL?.path
            entity.thumbnailPath = project.thumbnailURL?.path
            entity.vertexCount = Int32(project.metadata.vertexCount)
            entity.faceCount = Int32(project.metadata.faceCount)
            entity.boundingBoxX = project.metadata.boundingBoxSize.x
            entity.boundingBoxY = project.metadata.boundingBoxSize.y
            entity.boundingBoxZ = project.metadata.boundingBoxSize.z
            entity.hasTexture = project.metadata.hasTexture
            entity.isManifold = project.metadata.isManifold
            entity.scanDuration = project.metadata.scanDuration
            entity.deviceModel = project.metadata.deviceModel

            try context.save()
        }
    }

    func fetchAllProjects() async throws -> [ScanProject] {
        let context = newBackgroundContext()

        return try await context.perform {
            let request = ProjectEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \ProjectEntity.modifiedAt, ascending: false)
            ]

            let entities = try context.fetch(request)
            return entities.map { ProjectMapper.map($0) }
        }
    }

    func deleteProject(_ projectId: UUID) async throws {
        let context = newBackgroundContext()

        try await context.perform {
            let request = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", projectId as CVarArg)

            if let entity = try context.fetch(request).first {
                context.delete(entity)
                try context.save()
            }
        }
    }
}
```

---

## 8. Performance Architecture

### 8.1 Memory Management

```swift
// MemoryManager.swift

final class MemoryManager {

    static let shared = MemoryManager()

    // Memory thresholds
    private let warningThreshold: UInt64 = 1_500_000_000  // 1.5GB
    private let criticalThreshold: UInt64 = 1_800_000_000 // 1.8GB

    var currentMemoryUsage: UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    var memoryPressureLevel: MemoryPressureLevel {
        let usage = currentMemoryUsage
        if usage > criticalThreshold {
            return .critical
        } else if usage > warningThreshold {
            return .warning
        }
        return .normal
    }

    func startMonitoring(handler: @escaping (MemoryPressureLevel) -> Void) {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            handler(self.memoryPressureLevel)
        }

        source.resume()
    }

    enum MemoryPressureLevel {
        case normal
        case warning
        case critical
    }
}
```

### 8.2 Streaming Mesh Processing

```swift
// StreamingMeshProcessor.swift

final class StreamingMeshProcessor {

    // Process mesh in chunks to avoid memory spikes
    func processLargeMesh(
        _ mesh: RawMesh,
        chunkSize: Int = 10_000
    ) async throws -> ProcessedMesh {

        let totalVertices = mesh.vertexCount
        let chunks = stride(from: 0, to: totalVertices, by: chunkSize).map {
            $0..<min($0 + chunkSize, totalVertices)
        }

        var processedChunks: [MeshChunk] = []

        for (index, range) in chunks.enumerated() {
            // Process chunk
            let chunk = extractChunk(from: mesh, range: range)
            let processed = try await processChunk(chunk)
            processedChunks.append(processed)

            // Report progress
            let progress = Double(index + 1) / Double(chunks.count)
            await MainActor.run {
                progressHandler?(progress)
            }

            // Allow memory cleanup between chunks
            await Task.yield()
        }

        // Merge processed chunks
        return mergeChunks(processedChunks)
    }
}
```

### 8.3 Performance Metrics

```swift
// PerformanceMonitor.swift

final class PerformanceMonitor {

    static let shared = PerformanceMonitor()

    private var frameTimestamps: [CFTimeInterval] = []
    private let maxSamples = 60

    // FPS Tracking
    func recordFrame() {
        let timestamp = CACurrentMediaTime()
        frameTimestamps.append(timestamp)

        if frameTimestamps.count > maxSamples {
            frameTimestamps.removeFirst()
        }
    }

    var currentFPS: Double {
        guard frameTimestamps.count >= 2 else { return 0 }

        let duration = frameTimestamps.last! - frameTimestamps.first!
        return Double(frameTimestamps.count - 1) / duration
    }

    // GPU Usage (approximation via Metal)
    func measureGPUTime(for commandBuffer: MTLCommandBuffer) -> CFTimeInterval {
        commandBuffer.addCompletedHandler { buffer in
            let gpuTime = buffer.gpuEndTime - buffer.gpuStartTime
            Logger.debug("GPU time: \(gpuTime * 1000)ms")
        }
        return 0
    }

    // Scan Quality Metrics
    struct ScanMetrics {
        var capturedFrames: Int
        var averageFPS: Double
        var verticesCaptured: Int
        var coveragePercentage: Double
        var scanDuration: TimeInterval
    }
}
```

### 8.4 Optimization Strategies

| Area | Strategy | Implementation |
|------|----------|----------------|
| Mesh Storage | Compressed binary format | `MeshDTO` with compressed data |
| Texture | ASTC compression | Metal texture compression |
| Point Cloud | LOD streaming | Progressive refinement |
| UI | Lazy loading | `LazyVGrid`, `LazyVStack` |
| AR Session | Adaptive quality | Dynamic resolution scaling |
| Export | Background processing | `Task.detached` with progress |

---

## 9. Security Architecture

### 9.1 Data Protection

```swift
// SecurityManager.swift

final class SecurityManager {

    // File protection
    func setFileProtection(_ url: URL, level: FileProtectionType = .complete) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: level],
            ofItemAtPath: url.path
        )
    }

    // Keychain for sensitive data (if needed for future cloud features)
    func saveToKeychain(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw SecurityError.keychainSaveFailed
        }
    }
}
```

### 9.2 Privacy Considerations

```swift
// PrivacyManager.swift

final class PrivacyManager {

    // Camera permission
    func requestCameraPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    // Check permissions status
    var cameraPermissionStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    // Privacy manifest requirements (iOS 17+)
    static let requiredPrivacyAPIs = [
        "NSCameraUsageDescription",
        "NSPhotoLibraryUsageDescription"
    ]

    // Data handling policy
    struct DataPolicy {
        static let localProcessingOnly = true
        static let noCloudUpload = true  // MVP: All processing local
        static let facialDataNotStored = true  // Only mesh, not identifiable data
    }
}
```

### 9.3 App Transport Security

```xml
<!-- Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>

<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan 3D models using LiDAR</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is required to save exported 3D models</string>
```

---

## 10. Testing Architecture

### 10.1 Testing Strategy

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Testing Pyramid                                  │
└─────────────────────────────────────────────────────────────────────────┘

                              ┌───────────┐
                             │    E2E    │  ← 10%
                            │   Tests   │     Manual + Automated
                           └───────────┘
                          ┌─────────────────┐
                         │  Integration    │  ← 20%
                        │     Tests       │     XCTest
                       └─────────────────┘
                      ┌───────────────────────┐
                     │       Unit Tests      │  ← 70%
                    │   (Domain, Core, Data) │     XCTest + Quick/Nimble
                   └───────────────────────┘
```

### 10.2 Unit Tests

```swift
// MeshProcessorTests.swift

import XCTest
@testable import FigureScanner

final class MeshProcessorTests: XCTestCase {

    var sut: MeshProcessor!
    var mockMesh: RawMesh!

    override func setUp() {
        super.setUp()
        sut = MeshProcessor()
        mockMesh = MockMeshFactory.createSimpleMesh(vertexCount: 1000)
    }

    override func tearDown() {
        sut = nil
        mockMesh = nil
        super.tearDown()
    }

    // MARK: - Hole Filling Tests

    func testHoleFilling_WithHolesPresent_FillsAllHoles() async throws {
        // Given
        let meshWithHoles = MockMeshFactory.createMeshWithHoles(holeCount: 5)
        let options = MeshProcessor.ProcessingOptions(fillHoles: true)

        // When
        let result = try await sut.process(meshWithHoles, options: options) { _ in }

        // Then
        XCTAssertTrue(result.mesh.isManifold)
        XCTAssertEqual(result.mesh.holeCount, 0)
    }

    // MARK: - Smoothing Tests

    func testSmoothing_WithHighNoise_ReducesNoise() async throws {
        // Given
        let noisyMesh = MockMeshFactory.createNoisyMesh(noiseLevel: 0.1)
        let options = MeshProcessor.ProcessingOptions(
            smoothingPasses: 3,
            smoothingFactor: 0.5
        )

        // When
        let result = try await sut.process(noisyMesh, options: options) { _ in }

        // Then
        let originalVariance = calculateVertexVariance(noisyMesh)
        let resultVariance = calculateVertexVariance(result.mesh)
        XCTAssertLessThan(resultVariance, originalVariance)
    }

    // MARK: - Manifold Tests

    func testManifoldCheck_WithNonManifoldMesh_RepairsMesh() async throws {
        // Given
        let nonManifold = MockMeshFactory.createNonManifoldMesh()
        let options = MeshProcessor.ProcessingOptions(ensureManifold: true)

        // When
        let result = try await sut.process(nonManifold, options: options) { _ in }

        // Then
        XCTAssertTrue(result.isManifold)
    }

    // MARK: - Performance Tests

    func testProcessing_WithLargeMesh_CompletesWithinTimeout() async throws {
        // Given
        let largeMesh = MockMeshFactory.createSimpleMesh(vertexCount: 100_000)
        let options = MeshProcessor.ProcessingOptions()

        // When/Then
        let expectation = expectation(description: "Processing completes")

        Task {
            _ = try await sut.process(largeMesh, options: options) { _ in }
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 30.0)
    }
}
```

### 10.3 Integration Tests

```swift
// ScanningIntegrationTests.swift

import XCTest
@testable import FigureScanner

final class ScanningIntegrationTests: XCTestCase {

    func testFullScanPipeline_FaceScan_ProducesValidMesh() async throws {
        // This test requires a device with LiDAR
        guard ARFaceTrackingConfiguration.isSupported else {
            throw XCTSkip("Face tracking not supported on this device")
        }

        // Given
        let scanEngine = FaceScanningEngine()
        let meshProcessor = MeshProcessor()

        // When - Simulate scan with mock data
        let rawMesh = try await scanEngine.performMockScan()
        let processedMesh = try await meshProcessor.process(rawMesh, options: .default) { _ in }

        // Then
        XCTAssertGreaterThan(processedMesh.vertexCount, 10_000)
        XCTAssertTrue(processedMesh.isManifold)
    }
}
```

### 10.4 UI Tests

```swift
// ScanFlowUITests.swift

import XCTest

final class ScanFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testFaceScanFlow_SelectFaceScan_ShowsScanScreen() {
        // Given
        let faceScanButton = app.buttons["Face Scan"]

        // When
        faceScanButton.tap()

        // Then
        XCTAssertTrue(app.staticTexts["Position your face"].waitForExistence(timeout: 5))
    }

    func testExportFlow_SelectSTL_ShowsExportOptions() {
        // Navigate to a completed scan first
        // ...

        // Given
        let exportButton = app.buttons["Export"]

        // When
        exportButton.tap()
        app.buttons["STL"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Export Settings"].exists)
    }
}
```

---

## 11. CI/CD Pipeline

### 11.1 Pipeline Architecture

```yaml
# .github/workflows/ios.yml

name: iOS CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  XCODE_VERSION: '15.0'
  IOS_DESTINATION: 'platform=iOS Simulator,name=iPhone 15 Pro'

jobs:
  build-and-test:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_${{ env.XCODE_VERSION }}.app

      - name: Cache Swift Packages
        uses: actions/cache@v3
        with:
          path: ~/Library/Developer/Xcode/DerivedData/**/SourcePackages
          key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}

      - name: Build
        run: |
          xcodebuild build \
            -scheme "3DFigureScanner" \
            -destination "${{ env.IOS_DESTINATION }}" \
            -configuration Debug \
            CODE_SIGNING_ALLOWED=NO

      - name: Run Unit Tests
        run: |
          xcodebuild test \
            -scheme "3DFigureScanner" \
            -destination "${{ env.IOS_DESTINATION }}" \
            -resultBundlePath TestResults.xcresult \
            CODE_SIGNING_ALLOWED=NO

      - name: Upload Test Results
        uses: actions/upload-artifact@v3
        if: failure()
        with:
          name: test-results
          path: TestResults.xcresult

  lint:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Run SwiftLint
        run: |
          brew install swiftlint
          swiftlint lint --reporter github-actions-logging

  deploy-testflight:
    needs: [build-and-test, lint]
    runs-on: macos-14
    if: github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v4

      - name: Install Fastlane
        run: gem install fastlane

      - name: Build and Upload to TestFlight
        env:
          APP_STORE_CONNECT_API_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
        run: |
          fastlane beta
```

### 11.2 Fastlane Configuration

```ruby
# fastlane/Fastfile

default_platform(:ios)

platform :ios do

  before_all do
    setup_ci if ENV['CI']
  end

  desc "Run all tests"
  lane :test do
    run_tests(
      scheme: "3DFigureScanner",
      device: "iPhone 15 Pro",
      code_coverage: true,
      output_types: "junit,html"
    )
  end

  desc "Build and upload to TestFlight"
  lane :beta do
    match(type: "appstore", readonly: true)

    increment_build_number(
      build_number: ENV['GITHUB_RUN_NUMBER']
    )

    build_app(
      scheme: "3DFigureScanner",
      export_method: "app-store"
    )

    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )
  end

  desc "Deploy to App Store"
  lane :release do
    match(type: "appstore", readonly: true)

    build_app(
      scheme: "3DFigureScanner",
      export_method: "app-store"
    )

    upload_to_app_store(
      submit_for_review: true,
      automatic_release: false,
      precheck_include_in_app_purchases: false
    )
  end

end
```

---

## 12. Third-Party Dependencies

### 12.1 Dependencies Overview

| Package | Version | Purpose | License |
|---------|---------|---------|---------|
| None (MVP) | - | - | - |

**Note**: MVP sử dụng 100% Apple frameworks để tránh dependencies. Các dependencies dưới đây có thể được thêm vào các phiên bản sau:

### 12.2 Potential Future Dependencies

| Package | Purpose | When to Add |
|---------|---------|-------------|
| Firebase Analytics | Usage analytics | v1.0 Launch |
| Firebase Crashlytics | Crash reporting | v1.0 Launch |
| Sentry | Error tracking | Alternative to Firebase |
| Alamofire | Networking (cloud features) | v2.0+ |
| Kingfisher | Image caching | v2.0+ (if cloud gallery) |

### 12.3 Swift Package Manager Configuration

```swift
// Package.swift (if using SPM)

// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "3DFigureScanner",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "3DFigureScanner",
            targets: ["3DFigureScanner"]
        ),
    ],
    dependencies: [
        // Add dependencies here when needed
        // .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
    ],
    targets: [
        .target(
            name: "3DFigureScanner",
            dependencies: []
        ),
        .testTarget(
            name: "3DFigureScannerTests",
            dependencies: ["3DFigureScanner"]
        ),
    ]
)
```

---

## 13. API Specifications

### 13.1 Internal Service APIs

```swift
// ScanningServiceProtocol.swift

protocol ScanningServiceProtocol {

    /// Start a face scanning session
    /// - Returns: AsyncThrowingStream of scan progress updates
    func startFaceScan() async throws -> AsyncThrowingStream<ScanProgress, Error>

    /// Start a body scanning session
    func startBodyScan() async throws -> AsyncThrowingStream<ScanProgress, Error>

    /// Start a bust scanning session
    func startBustScan() async throws -> AsyncThrowingStream<ScanProgress, Error>

    /// Pause current scan
    func pauseScan()

    /// Resume paused scan
    func resumeScan()

    /// Stop and finalize scan
    /// - Returns: Raw mesh from scanning session
    func stopScan() async throws -> RawMesh

    /// Cancel scan without saving
    func cancelScan()
}

// ScanProgress.swift
enum ScanProgress {
    case preparing
    case scanning(progress: Double, angle: Float?, quality: ScanQuality)
    case processing(stage: String, progress: Double)
    case completed(mesh: RawMesh)
    case failed(error: ScanError)
}
```

```swift
// MeshProcessingServiceProtocol.swift

protocol MeshProcessingServiceProtocol {

    /// Process raw mesh with specified options
    func process(
        _ mesh: RawMesh,
        options: ProcessingOptions
    ) async throws -> ProcessedMesh

    /// Fill holes in mesh
    func fillHoles(_ mesh: Mesh3D) async throws -> Mesh3D

    /// Smooth mesh surface
    func smooth(_ mesh: Mesh3D, factor: Float, passes: Int) async throws -> Mesh3D

    /// Check and repair manifold issues
    func repairManifold(_ mesh: Mesh3D) async throws -> (mesh: Mesh3D, wasRepaired: Bool)

    /// Generate base for figure
    func generateBase(_ mesh: Mesh3D, style: BaseStyle) async throws -> Mesh3D

    /// Make mesh hollow
    func makeHollow(_ mesh: Mesh3D, wallThickness: Float) async throws -> Mesh3D
}
```

```swift
// ExportServiceProtocol.swift

protocol ExportServiceProtocol {

    /// Export mesh to specified format
    func export(
        _ mesh: ProcessedMesh,
        format: ExportFormat,
        config: ExportConfig
    ) async throws -> URL

    /// Get estimated file size before export
    func estimateFileSize(
        _ mesh: ProcessedMesh,
        format: ExportFormat,
        config: ExportConfig
    ) -> Int64

    /// Validate exported file
    func validate(_ url: URL, format: ExportFormat) async throws -> ValidationResult
}

struct ValidationResult {
    let isValid: Bool
    let vertexCount: Int
    let faceCount: Int
    let fileSize: Int64
    let issues: [String]
}
```

### 13.2 ViewModel Interfaces

```swift
// ScanViewModel.swift

@MainActor
final class ScanViewModel: ObservableObject {

    // MARK: - Published State
    @Published private(set) var scanState: ScanState = .idle
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentAngle: Float = 0
    @Published private(set) var qualityIndicator: QualityIndicator = .good
    @Published private(set) var distanceIndicator: DistanceIndicator = .optimal
    @Published private(set) var lightingIndicator: LightingIndicator = .good
    @Published private(set) var capturedFrames: Int = 0
    @Published var errorMessage: String?

    // MARK: - Actions
    func startScan(type: ScanType) async
    func pauseScan()
    func resumeScan()
    func stopScan() async
    func cancelScan()
}

enum ScanState: Equatable {
    case idle
    case preparing
    case scanning
    case paused
    case processing(progress: Double)
    case completed(mesh: Mesh3D)
    case failed(error: String)
}
```

---

## 14. Error Handling

### 14.1 Error Types

```swift
// Errors.swift

enum ScanError: LocalizedError {
    case lidarNotAvailable
    case cameraPermissionDenied
    case faceNotDetected
    case bodyNotDetected
    case insufficientLighting
    case subjectMoved
    case scanTimeout
    case memoryPressure
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .lidarNotAvailable:
            return "LiDAR scanner is not available on this device"
        case .cameraPermissionDenied:
            return "Camera permission is required for scanning"
        case .faceNotDetected:
            return "No face detected. Please position your face in the frame"
        case .bodyNotDetected:
            return "No person detected. Please ensure the subject is visible"
        case .insufficientLighting:
            return "Insufficient lighting. Please move to a brighter area"
        case .subjectMoved:
            return "Subject moved during scan. Please stay still"
        case .scanTimeout:
            return "Scan timed out. Please try again"
        case .memoryPressure:
            return "Device memory is low. Please close other apps"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .lidarNotAvailable:
            return "This app requires iPhone 12 Pro or newer with LiDAR"
        case .insufficientLighting:
            return "Try moving to a well-lit area or turning on more lights"
        case .subjectMoved:
            return "Ask the subject to remain still during the scan"
        default:
            return nil
        }
    }
}

enum ProcessingError: LocalizedError {
    case meshReconstructionFailed
    case holeFillFailed
    case manifoldRepairFailed
    case textureMapFailed
    case insufficientVertices
    case timeout

    var errorDescription: String? {
        switch self {
        case .meshReconstructionFailed:
            return "Failed to reconstruct 3D mesh from scan data"
        case .holeFillFailed:
            return "Failed to fill holes in mesh"
        case .manifoldRepairFailed:
            return "Failed to repair mesh for 3D printing"
        case .textureMapFailed:
            return "Failed to apply texture to mesh"
        case .insufficientVertices:
            return "Not enough detail captured. Please rescan"
        case .timeout:
            return "Processing timed out"
        }
    }
}

enum ExportError: LocalizedError {
    case formatNotSupported
    case writeFailed
    case fileTooLarge
    case diskSpaceInsufficient
    case validationFailed(reasons: [String])

    var errorDescription: String? {
        switch self {
        case .formatNotSupported:
            return "Export format is not supported"
        case .writeFailed:
            return "Failed to write export file"
        case .fileTooLarge:
            return "Export file is too large"
        case .diskSpaceInsufficient:
            return "Not enough disk space for export"
        case .validationFailed(let reasons):
            return "Export validation failed: \(reasons.joined(separator: ", "))"
        }
    }
}

enum StorageError: LocalizedError {
    case meshEncodingFailed
    case meshDecodingFailed
    case textureEncodingFailed
    case thumbnailEncodingFailed
    case fileNotFound
    case permissionDenied
}
```

### 14.2 Error Handling Strategy

```swift
// ErrorHandler.swift

final class ErrorHandler {

    static let shared = ErrorHandler()

    func handle(_ error: Error, context: ErrorContext) {
        // Log error
        Logger.error("[\(context.rawValue)] \(error.localizedDescription)")

        // Track in analytics
        AnalyticsService.shared.trackError(error, context: context)

        // Determine if recoverable
        if let recoverableError = error as? RecoverableError {
            // Attempt recovery
            recoverableError.attemptRecovery()
        }
    }

    enum ErrorContext: String {
        case scanning
        case processing
        case export
        case storage
        case ui
    }
}

protocol RecoverableError: Error {
    func attemptRecovery() -> Bool
}
```

---

## 15. Appendix

### 15.1 Glossary

| Term | Definition |
|------|------------|
| **LiDAR** | Light Detection and Ranging - laser-based depth sensing |
| **Mesh** | 3D surface made of connected polygons (triangles) |
| **Manifold** | A mesh that is "watertight" - suitable for 3D printing |
| **Point Cloud** | Collection of 3D points in space |
| **UV Mapping** | Process of projecting 2D texture onto 3D surface |
| **Decimation** | Reducing polygon count while preserving shape |
| **Poisson Surface** | Algorithm for reconstructing mesh from point cloud |
| **ARKit** | Apple's Augmented Reality framework |
| **Metal** | Apple's low-level GPU programming framework |
| **Scene Reconstruction** | ARKit feature to create 3D mesh of environment |

### 15.2 Reference Links

- [ARKit Documentation](https://developer.apple.com/documentation/arkit)
- [RealityKit Documentation](https://developer.apple.com/documentation/realitykit)
- [Metal Documentation](https://developer.apple.com/documentation/metal)
- [Model I/O Documentation](https://developer.apple.com/documentation/modelio)
- [SceneKit Documentation](https://developer.apple.com/documentation/scenekit)
- [STL File Format](https://en.wikipedia.org/wiki/STL_(file_format))
- [OBJ File Format](https://en.wikipedia.org/wiki/Wavefront_.obj_file)

### 15.3 Device Specifications

| Device | LiDAR Range | Depth Resolution | Notes |
|--------|-------------|------------------|-------|
| iPhone 12 Pro | 0-5m | 256x192 | First gen LiDAR |
| iPhone 13 Pro | 0-5m | 256x192 | Improved accuracy |
| iPhone 14 Pro | 0-5m | 256x192 | Better low-light |
| iPhone 15 Pro | 0-5m | 256x192 | Latest generation |
| iPad Pro 2020+ | 0-5m | 256x192 | Larger screen |

### 15.4 File Format Specifications

| Format | Max Vertices | Max File Size | Color Support | Notes |
|--------|--------------|---------------|---------------|-------|
| STL | Unlimited | ~2GB | No | Most compatible |
| OBJ | Unlimited | ~2GB | Yes (MTL) | Industry standard |
| GLTF/GLB | Unlimited | ~2GB | Yes | Web/game ready |
| USDZ | Unlimited | ~2GB | Yes | Apple AR |
| PLY | Unlimited | ~2GB | Yes (vertex) | Point cloud |

---

## 16. Implemented Core Services

This section documents the actual implemented services in the codebase.

### 16.1 LiDARScanningService

Located at: `FigureScanner3D/Core/Services/LiDARScanningService.swift`

```swift
/// Service responsible for LiDAR-based 3D scanning
@MainActor
final class LiDARScanningService: NSObject, ObservableObject {

    // Published Properties
    @Published private(set) var isScanning = false
    @Published private(set) var scanProgress: Float = 0.0
    @Published private(set) var capturedMesh: CapturedMesh?
    @Published private(set) var faceDetected = false
    @Published private(set) var faceTransform: simd_float4x4?
    @Published private(set) var lightingQuality: LightingQuality = .good
    @Published private(set) var distanceToFace: Float = 0.0

    // Key Features:
    // - ARWorldTrackingConfiguration with sceneReconstruction = .meshWithClassification
    // - Face tracking using ARFaceTrackingConfiguration.userFaceTrackingEnabled
    // - Real-time mesh capture from ARMeshAnchor
    // - Lighting quality estimation from ARFrame.lightEstimate
    // - Distance calculation for optimal scanning range (25-50cm for face)
    // - Progress tracking based on captured angles (5 angles for complete scan)
}
```

**Key Methods:**
- `configure(arView:mode:)` - Initialize AR session for face/body/bust scan
- `startScanning()` - Begin mesh capture
- `stopScanning()` - End capture and process mesh
- `resetScan()` - Clear all captured data

**Scan Modes:**
- `.face` - Face scanning with 25-50cm optimal distance
- `.body` - Full body 360° scanning
- `.bust` - Head and shoulders scanning

### 16.2 MeshProcessingService

Located at: `FigureScanner3D/Core/Services/MeshProcessingService.swift`

```swift
/// Service for processing and optimizing captured 3D meshes
actor MeshProcessingService {

    struct ProcessingOptions {
        var smoothingIterations: Int = 3
        var smoothingFactor: Float = 0.5
        var decimationRatio: Float = 0.5
        var fillHoles: Bool = true
        var removeNoise: Bool = true
        var noiseThreshold: Float = 0.002  // 2mm
    }

    // Processing Pipeline:
    // 1. Noise Removal - Remove outlier vertices
    // 2. Hole Filling - Close small holes in mesh
    // 3. Laplacian Smoothing - Smooth surface
    // 4. Normal Recalculation - Update vertex normals
    // 5. Decimation - Reduce vertex count if needed
    // 6. UV Generation - Create texture coordinates
}
```

**Processing Algorithms:**
- **Noise Removal**: Adjacency-based outlier detection
- **Hole Filling**: Boundary edge detection and fan triangulation
- **Laplacian Smoothing**: Iterative vertex averaging with neighbors
- **Decimation**: Vertex clustering with spatial grid

### 16.3 MeshExportService

Located at: `FigureScanner3D/Core/Services/MeshExportService.swift`

```swift
/// Service for exporting 3D meshes to various file formats
actor MeshExportService {

    enum ExportFormat: String, CaseIterable {
        case stl = "STL"   // Binary/ASCII, most compatible
        case obj = "OBJ"   // With texture coordinates and normals
        case ply = "PLY"   // Binary/ASCII, with colors
        case usdz = "USDZ" // Apple AR format (planned)
    }

    struct ExportOptions {
        var scale: Float = 1.0
        var centerMesh: Bool = true
        var binary: Bool = true
        var includeNormals: Bool = true
        var includeTextureCoords: Bool = true
    }
}
```

**Supported Formats:**
| Format | Binary | ASCII | Normals | Textures | Notes |
|--------|--------|-------|---------|----------|-------|
| STL | ✅ | ✅ | Face | ❌ | Best for 3D printing |
| OBJ | ❌ | ✅ | ✅ | ✅ | Industry standard |
| PLY | ✅ | ✅ | ✅ | ❌ | Good for point clouds |

### 16.4 Data Models

```swift
/// Captured mesh from LiDAR scanning
struct CapturedMesh {
    let id: UUID
    let vertices: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let faces: [[Int]]
    let scanMode: LiDARScanningService.ScanMode
    let captureDate: Date

    var vertexCount: Int
    var faceCount: Int
    var boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>)
    var dimensions: SIMD3<Float>
}

/// Processed mesh ready for export
struct ProcessedMesh {
    let vertices: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let faces: [[Int]]
    let textureCoordinates: [SIMD2<Float>]?
}
```

### 16.5 Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| LiDARScanningService | ✅ Implemented | Face scan mode complete |
| MeshProcessingService | ✅ Implemented | All algorithms working |
| MeshExportService | ✅ Implemented | STL, OBJ, PLY formats |
| FaceScanView | ✅ Implemented | Full UI with real-time feedback |
| BodyScanView | 🔄 Placeholder | Needs LiDAR integration |
| BustScanView | 🔄 Placeholder | Planned for v1.5 |
| MeshPreviewView | 🔄 Basic | Needs 3D rendering |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Dec 2024 | Engineering Team | Initial document |
| 1.1 | Dec 2024 | Engineering Team | Added implemented services documentation |

---

**End of Technical Architecture Document**
