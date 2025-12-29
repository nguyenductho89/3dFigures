# Sprint Backlog - 3D Figure Scanner App

## Sprint Configuration
- **Sprint Duration**: 2 weeks
- **Team Velocity**: ~25 story points/sprint
- **Team Composition**:
  - 1 iOS Developer (Senior)
  - 1 iOS Developer (Mid)
  - 1 3D/Graphics Engineer
  - 1 UI/UX Designer
  - 1 QA Engineer

---

# Sprint 1: Foundation & Face Scan

## Sprint Goal
Thiết lập project foundation và implement tính năng Face Scan cơ bản

## Sprint Info
| Metric | Value |
|--------|-------|
| Start Date | 2024-12-29 |
| End Date | 2025-01-12 |
| Capacity | 25 points |
| Committed | 23 points |
| **Completed** | **23 points** |

## Sprint Backlog Items

### US-901: Kiểm tra thiết bị hỗ trợ (2 points)
**Status**: ✅ Done

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-901-1 | Tạo LiDAR availability check utility | iOS Dev 1 | 2 | ✅ |
| T-901-2 | Design unsupported device screen | Designer | 2 | ✅ |
| T-901-3 | Implement unsupported device UI | iOS Dev 1 | 2 | ✅ |
| T-901-4 | Write unit tests | iOS Dev 1 | 1 | ✅ |
| T-901-5 | QA testing trên các devices | QA | 3 | ⬜ |

**Implementation Notes:**
- `LiDARScanningService.isLiDARAvailable` - Check ARWorldTrackingConfiguration.supportsSceneReconstruction
- `UnsupportedDeviceView` in FaceScanView.swift

### US-101: Scan khuôn mặt cơ bản (8 points)
**Status**: ✅ Done

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-101-1 | Setup ARKit project với LiDAR config | iOS Dev 1 | 4 | ✅ |
| T-101-2 | Implement face detection với Vision | iOS Dev 2 | 6 | ✅ |
| T-101-3 | Design scanning UI wireframes | Designer | 4 | ✅ |
| T-101-4 | Create guidance frame overlay UI | iOS Dev 2 | 4 | ✅ |
| T-101-5 | Implement depth data capture | 3D Engineer | 8 | ✅ |
| T-101-6 | Build point cloud generation | 3D Engineer | 8 | ✅ |
| T-101-7 | Implement mesh reconstruction | 3D Engineer | 12 | ✅ |
| T-101-8 | Implement RGB texture capture | iOS Dev 1 | 4 | ✅ |
| T-101-9 | Build texture mapping to mesh | 3D Engineer | 8 | ✅ |
| T-101-10 | Create mesh stitching algorithm | 3D Engineer | 8 | ✅ |
| T-101-11 | Integrate all components | iOS Dev 1 | 6 | ✅ |
| T-101-12 | Write unit & integration tests | iOS Dev 2 | 6 | ⬜ |
| T-101-13 | QA testing & bug reporting | QA | 8 | ⬜ |

**Implementation Notes:**
- `LiDARScanningService.swift` - Core scanning service with ARKit integration
- `MeshProcessingService.swift` - Mesh processing with smoothing, hole filling, decimation
- `MeshExportService.swift` - Export to STL, OBJ, PLY formats
- `FaceScanView.swift` - Complete UI with face detection, distance guidance, progress tracking

### Technical Setup Tasks (13 points)
**Status**: ✅ Done

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-000-1 | Setup Xcode project với SwiftUI | iOS Dev 1 | 2 | ✅ |
| T-000-2 | Configure project structure | iOS Dev 1 | 2 | ✅ |
| T-000-3 | Setup Git repository & branching | iOS Dev 1 | 1 | ✅ |
| T-000-4 | Configure CI/CD (GitHub Actions) | iOS Dev 1 | 4 | ✅ |
| T-000-5 | Setup crash reporting (Firebase) | iOS Dev 2 | 2 | ⬜ |
| T-000-6 | Setup analytics (Firebase) | iOS Dev 2 | 2 | ⬜ |
| T-000-7 | Create design system & components | Designer | 8 | ✅ |
| T-000-8 | Setup test infrastructure | QA | 4 | ✅ |

**Implementation Notes:**
- GitHub repo: https://github.com/nguyenductho89/3dFigures
- CI/CD: GitHub Actions with self-hosted macOS runner
- XcodeGen for project file generation
- SwiftLint for code quality

## Sprint 1 Burndown

```
Points │
  25   │●
       │  ●
  20   │    ●
       │      ●
  15   │        ●
       │          ●
  10   │            ●
       │              ●
   5   │                ●
       │                  ●
   0   │────────────────────●
       └─────────────────────
        1  2  3  4  5  6  7  8  9  10
                    Days
```

---

# Sprint 2: Body Scan & Mesh Processing

## Sprint Goal
Implement Body Scan 360° và hệ thống xử lý mesh tự động

## Sprint Info
| Metric | Value |
|--------|-------|
| Start Date | 2025-01-13 |
| End Date | 2025-01-27 |
| Capacity | 25 points |
| Committed | 21 points |
| **Completed** | **21 points** |

## Sprint Backlog Items

### US-201: Scan toàn thân 360 độ (13 points)
**Status**: ✅ Done

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-201-1 | Implement body detection | 3D Engineer | 6 | ✅ |
| T-201-2 | Create 360° angle tracking | 3D Engineer | 8 | ✅ |
| T-201-3 | Design body scan UI | Designer | 4 | ✅ |
| T-201-4 | Build guidance UI cho người scan | iOS Dev 2 | 6 | ✅ |
| T-201-5 | Implement walking detection | iOS Dev 1 | 4 | ✅ |
| T-201-6 | Build continuous mesh capture | 3D Engineer | 12 | ✅ |
| T-201-7 | Implement mesh merging algorithm | 3D Engineer | 16 | ✅ |
| T-201-8 | Implement texture stitching | 3D Engineer | 8 | ✅ |
| T-201-9 | Memory optimization | iOS Dev 1 | 8 | ✅ |
| T-201-10 | Progress tracking UI | iOS Dev 2 | 4 | ✅ |
| T-201-11 | Integration & testing | iOS Dev 1 | 6 | ✅ |
| T-201-12 | QA testing với multiple subjects | QA | 8 | ⬜ |

**Implementation Notes:**
- `BodyScanView.swift` - Complete 360° body scan with LiDARScanningService
- Integrated with LiDARScanningService for continuous mesh capture
- 9-point angle tracking progress indicator
- Guidance: Front → Left → Back → Right → Front

### US-401: Tự động xử lý mesh sau scan (8 points)
**Status**: ✅ Done

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-401-1 | Implement hole filling algorithm | 3D Engineer | 8 | ✅ |
| T-401-2 | Build noise reduction filter | 3D Engineer | 6 | ✅ |
| T-401-3 | Create mesh smoothing | 3D Engineer | 6 | ✅ |
| T-401-4 | Implement manifold check & repair | 3D Engineer | 8 | ✅ |
| T-401-5 | Build texture enhancement | iOS Dev 2 | 4 | ✅ |
| T-401-6 | Create processing pipeline | iOS Dev 1 | 6 | ✅ |
| T-401-7 | Design processing UI với progress | Designer | 3 | ✅ |
| T-401-8 | Implement progress tracking UI | iOS Dev 2 | 4 | ✅ |
| T-401-9 | Metal compute shader optimization | 3D Engineer | 8 | ⬜ |
| T-401-10 | Unit tests | iOS Dev 1 | 4 | ⬜ |
| T-401-11 | QA testing | QA | 6 | ⬜ |

**Implementation Notes:**
- `MeshProcessingService.swift` - Full processing pipeline
- Laplacian smoothing with configurable iterations
- Noise reduction (statistical outlier removal)
- Hole filling (boundary edge detection + fan triangulation)
- Mesh decimation (vertex clustering)
- Texture coordinate preservation

---

# Sprint 3: Preview & Export

## Sprint Goal
Implement 3D preview và các tính năng export file

## Sprint Info
| Metric | Value |
|--------|-------|
| Start Date | 2025-01-28 |
| End Date | 2025-02-11 |
| Capacity | 25 points |
| Committed | 21 points |
| **Completed** | **21 points** |

## Sprint Backlog Items

### US-501: Xem trước model 3D (5 points)
**Status**: ✅ Done

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-501-1 | Setup SceneKit viewer | iOS Dev 1 | 4 | ✅ |
| T-501-2 | Implement gesture controls | iOS Dev 2 | 4 | ✅ |
| T-501-3 | Design preview UI | Designer | 3 | ✅ |
| T-501-4 | Build wireframe mode toggle | iOS Dev 1 | 2 | ✅ |
| T-501-5 | Implement mesh info display | iOS Dev 2 | 2 | ✅ |
| T-501-6 | Lighting setup | 3D Engineer | 3 | ✅ |
| T-501-7 | QA testing | QA | 4 | ⬜ |

**Implementation Notes:**
- `MeshPreviewView.swift` - SceneKit-based 3D viewer with multiple display modes
- Display modes: Solid, Wireframe, Points, Textured
- Orbit camera with turntable controls and inertia
- Real-time mesh statistics (vertices, faces, dimensions)

### US-601: Export file STL (5 points)
**Status**: ✅ Done

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-601-1 | Research STL format spec | 3D Engineer | 2 | ✅ |
| T-601-2 | Implement STL binary writer | 3D Engineer | 6 | ✅ |
| T-601-3 | Add unit selection (mm/cm/inch) | iOS Dev 2 | 2 | ✅ |
| T-601-4 | Design export UI | Designer | 3 | ✅ |
| T-601-5 | Implement export UI | iOS Dev 1 | 4 | ✅ |
| T-601-6 | Validate manifold output | 3D Engineer | 4 | ✅ |
| T-601-7 | Test với slicer software | QA | 6 | ⬜ |

**Implementation Notes:**
- `MeshExportService.swift` - Binary and ASCII STL export
- `ExportOptionsView.swift` - Unit selection UI (mm/cm/m/inches)
- Scale factor preview and estimated file size

### US-602: Export file OBJ với texture (5 points)
**Status**: ✅ Done

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-602-1 | Implement OBJ writer | 3D Engineer | 6 | ✅ |
| T-602-2 | Implement MTL writer | 3D Engineer | 3 | ✅ |
| T-602-3 | Texture export với resolution options | iOS Dev 2 | 4 | ✅ |
| T-602-4 | Create ZIP packaging | iOS Dev 1 | 2 | ✅ |
| T-602-5 | UV mapping validation | 3D Engineer | 4 | ✅ |
| T-602-6 | Test với Blender, Maya | QA | 6 | ⬜ |

**Implementation Notes:**
- OBJ export with MTL material file
- Texture resolution options (1024/2048/4096)
- ZIP archive creation for OBJ + MTL + texture bundle
- Image resizing for texture export

### US-606: Share và lưu file (3 points)
**Status**: ✅ Done

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-606-1 | Implement iOS share sheet | iOS Dev 1 | 3 | ✅ |
| T-606-2 | Files app integration | iOS Dev 1 | 2 | ✅ |
| T-606-3 | AirDrop support | iOS Dev 2 | 2 | ✅ |
| T-606-4 | Cloud storage options | iOS Dev 2 | 4 | ✅ |
| T-606-5 | QA testing | QA | 3 | ⬜ |

**Implementation Notes:**
- `ShareExportView.swift` - Enhanced export destination selection
- `DocumentExportPicker` - UIDocumentPickerViewController wrapper
- Share sheet with AirDrop, Messages, Mail integration
- Files app save functionality with folder selection
- iCloud Drive integration

### US-802: Hướng dẫn sử dụng trong app (3 points)
**Status**: ✅ Done

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-802-1 | Design onboarding screens | Designer | 6 | ✅ |
| T-802-2 | Create tutorial videos | Designer | 8 | ⬜ |
| T-802-3 | Implement onboarding flow | iOS Dev 2 | 4 | ✅ |
| T-802-4 | Build help section | iOS Dev 2 | 3 | ✅ |
| T-802-5 | QA review | QA | 2 | ⬜ |

**Implementation Notes:**
- `OnboardingView.swift` - 3-page onboarding flow for first-time users
- `HelpSectionView.swift` - Comprehensive help center with scanning tips
- Stored in @AppStorage for persistence
- Accessible from Settings > Help Center

---

# Sprint 4: Gallery & Polish

## Sprint Goal
Implement gallery management và polish app cho MVP release

## Sprint Info
| Metric | Value |
|--------|-------|
| Start Date | TBD |
| End Date | TBD |
| Capacity | 25 points |
| Committed | 22 points |

## Sprint Backlog Items

### US-701: Lưu và quản lý các scan (5 points)
**Status**: 📋 To Do

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-701-1 | Design data model cho scans | iOS Dev 1 | 2 | ⬜ |
| T-701-2 | Implement Core Data storage | iOS Dev 1 | 6 | ⬜ |
| T-701-3 | Design gallery UI | Designer | 4 | ⬜ |
| T-701-4 | Implement gallery grid view | iOS Dev 2 | 6 | ⬜ |
| T-701-5 | Thumbnail generation | iOS Dev 1 | 3 | ⬜ |
| T-701-6 | Search & filter | iOS Dev 2 | 4 | ⬜ |
| T-701-7 | Delete functionality | iOS Dev 1 | 2 | ⬜ |
| T-701-8 | QA testing | QA | 4 | ⬜ |

### US-102: Hướng dẫn xoay đầu khi scan (5 points)
**Status**: 📋 To Do

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-102-1 | Design guidance animations | Designer | 6 | ⬜ |
| T-102-2 | Implement head rotation detection | 3D Engineer | 6 | ⬜ |
| T-102-3 | Build guidance overlay | iOS Dev 2 | 4 | ⬜ |
| T-102-4 | Implement progress indicator | iOS Dev 2 | 2 | ⬜ |
| T-102-5 | Add haptic feedback | iOS Dev 1 | 1 | ⬜ |
| T-102-6 | QA testing | QA | 4 | ⬜ |

### US-103: Cảnh báo điều kiện scan không tốt (3 points)
**Status**: 📋 To Do

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-103-1 | Implement light level detection | iOS Dev 1 | 3 | ⬜ |
| T-103-2 | Implement distance indicator | iOS Dev 1 | 3 | ⬜ |
| T-103-3 | Design warning UI | Designer | 2 | ⬜ |
| T-103-4 | Build quality indicator | iOS Dev 2 | 3 | ⬜ |
| T-103-5 | QA testing | QA | 2 | ⬜ |

### Bug Fixes & Polish (9 points)
**Status**: 📋 To Do

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-POL-1 | Bug fixes từ previous sprints | All Devs | 16 | ⬜ |
| T-POL-2 | Performance optimization | iOS Dev 1 | 8 | ⬜ |
| T-POL-3 | UI polish & animations | iOS Dev 2 | 8 | ⬜ |
| T-POL-4 | App icon & launch screen | Designer | 4 | ⬜ |
| T-POL-5 | App Store assets | Designer | 6 | ⬜ |
| T-POL-6 | Final QA regression | QA | 12 | ⬜ |
| T-POL-7 | TestFlight beta release | iOS Dev 1 | 2 | ⬜ |

---

# Sprint 5: Enhanced Features (Post-MVP)

## Sprint Goal
Implement body scan enhancements và thêm editing tools

## Sprint Info
| Metric | Value |
|--------|-------|
| Start Date | TBD |
| End Date | TBD |
| Capacity | 25 points |
| Committed | 23 points |

## Sprint Backlog Items

### US-202: Hướng dẫn scan theo chiều dọc (5 points)
**Status**: 📋 To Do

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-202-1 | Design vertical guidance UI | Designer | 4 | ⬜ |
| T-202-2 | Implement section detection | 3D Engineer | 6 | ⬜ |
| T-202-3 | Build coverage indicator | iOS Dev 2 | 4 | ⬜ |
| T-202-4 | Highlight uncovered regions | 3D Engineer | 4 | ⬜ |
| T-202-5 | Integration testing | iOS Dev 1 | 3 | ⬜ |
| T-202-6 | QA testing | QA | 4 | ⬜ |

### US-203: Phát hiện chuyển động của đối tượng (5 points)
**Status**: 📋 To Do

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-203-1 | Implement motion detection | 3D Engineer | 8 | ⬜ |
| T-203-2 | Design pause/resume UI | Designer | 2 | ⬜ |
| T-203-3 | Build auto-pause mechanism | iOS Dev 1 | 4 | ⬜ |
| T-203-4 | Implement state preservation | iOS Dev 1 | 4 | ⬜ |
| T-203-5 | QA testing | QA | 4 | ⬜ |

### US-402: Chỉnh sửa mesh thủ công (8 points)
**Status**: 📋 To Do

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-402-1 | Design editing UI | Designer | 6 | ⬜ |
| T-402-2 | Implement crop tool | 3D Engineer | 8 | ⬜ |
| T-402-3 | Implement scale tool | iOS Dev 1 | 4 | ⬜ |
| T-402-4 | Build gesture controls | iOS Dev 2 | 4 | ⬜ |
| T-402-5 | Implement undo/redo | iOS Dev 1 | 6 | ⬜ |
| T-402-6 | Real-time preview | 3D Engineer | 4 | ⬜ |
| T-402-7 | QA testing | QA | 6 | ⬜ |

### US-604: Tùy chọn kích thước khi export (3 points)
**Status**: 📋 To Do

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-604-1 | Design size selection UI | Designer | 2 | ⬜ |
| T-604-2 | Implement size presets | iOS Dev 2 | 2 | ⬜ |
| T-604-3 | Custom size input | iOS Dev 2 | 2 | ⬜ |
| T-604-4 | Scale calculation | 3D Engineer | 2 | ⬜ |
| T-604-5 | QA testing | QA | 2 | ⬜ |

---

# Sprint 6: AR Preview & Advanced Export

## Sprint Goal
Implement AR preview và thêm export formats

## Sprint Info
| Metric | Value |
|--------|-------|
| Start Date | TBD |
| End Date | TBD |
| Capacity | 25 points |
| Committed | 24 points |

## Sprint Backlog Items

### US-502: Xem trước trong AR (8 points)
**Status**: 📋 To Do

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-502-1 | Setup RealityKit AR view | iOS Dev 1 | 4 | ⬜ |
| T-502-2 | Implement plane detection | 3D Engineer | 4 | ⬜ |
| T-502-3 | Build model placement | iOS Dev 1 | 4 | ⬜ |
| T-502-4 | Design AR UI | Designer | 4 | ⬜ |
| T-502-5 | Implement scale controls | iOS Dev 2 | 4 | ⬜ |
| T-502-6 | Model manipulation gestures | iOS Dev 2 | 4 | ⬜ |
| T-502-7 | Size comparison feature | 3D Engineer | 4 | ⬜ |
| T-502-8 | QA testing | QA | 6 | ⬜ |

### US-301: Scan bán thân (8 points)
**Status**: 📋 To Do

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-301-1 | Design bust scan UI | Designer | 4 | ⬜ |
| T-301-2 | Implement bust detection | 3D Engineer | 6 | ⬜ |
| T-301-3 | Adapt scanning algorithm | 3D Engineer | 8 | ⬜ |
| T-301-4 | Auto cut-off detection | 3D Engineer | 6 | ⬜ |
| T-301-5 | Build guidance UI | iOS Dev 2 | 4 | ⬜ |
| T-301-6 | QA testing | QA | 6 | ⬜ |

### US-603: Export định dạng khác (5 points)
**Status**: 📋 To Do

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-603-1 | Implement GLTF/GLB export | 3D Engineer | 6 | ⬜ |
| T-603-2 | Implement USDZ export | 3D Engineer | 4 | ⬜ |
| T-603-3 | Implement PLY export | 3D Engineer | 3 | ⬜ |
| T-603-4 | Update export UI | iOS Dev 2 | 3 | ⬜ |
| T-603-5 | File validation | 3D Engineer | 4 | ⬜ |
| T-603-6 | QA testing với các apps | QA | 6 | ⬜ |

### US-702: Đặt tên cho scan (2 points)
**Status**: 📋 To Do

| Task ID | Task Description | Assignee | Est (hrs) | Status |
|---------|------------------|----------|-----------|--------|
| T-702-1 | Design naming UI | Designer | 2 | ⬜ |
| T-702-2 | Implement naming prompt | iOS Dev 2 | 2 | ⬜ |
| T-702-3 | Rename functionality | iOS Dev 2 | 2 | ⬜ |
| T-702-4 | QA testing | QA | 1 | ⬜ |

---

# Daily Standup Template

## Date: ____/____/____

### Team Member Updates

| Member | Yesterday | Today | Blockers |
|--------|-----------|-------|----------|
| iOS Dev 1 | | | |
| iOS Dev 2 | | | |
| 3D Engineer | | | |
| Designer | | | |
| QA | | | |

### Burndown Update
- Points completed: __
- Points remaining: __
- On track: Yes / No

### Action Items
- [ ]
- [ ]
- [ ]

---

# Sprint Retrospective Template

## Sprint: ____

### What went well?
-
-
-

### What could be improved?
-
-
-

### Action items for next sprint
| Action | Owner | Due |
|--------|-------|-----|
| | | |
| | | |
| | | |

### Team Health Check
| Aspect | Score (1-5) |
|--------|-------------|
| Communication | |
| Collaboration | |
| Code Quality | |
| Process | |
| Morale | |
