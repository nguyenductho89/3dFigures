# Product Backlog - 3D Figure Scanner App

## Backlog Overview

| Priority | Items | Story Points |
|----------|-------|--------------|
| P0 - Critical | 8 | 51 |
| P1 - High | 8 | 35 |
| P2 - Medium | 5 | 28 |
| P3 - Low | 2 | 8 |
| **Total** | **23** | **122** |

---

## P0 - Critical (Must Have for MVP)

| ID | User Story | Epic | Points | Dependencies | Status |
|----|------------|------|--------|--------------|--------|
| US-101 | Scan khuôn mặt cơ bản | Face Scanning | 8 | - | 📋 Backlog |
| US-201 | Scan toàn thân 360 độ | Body Scanning | 13 | - | 📋 Backlog |
| US-401 | Tự động xử lý mesh sau scan | Mesh Processing | 8 | US-101, US-201 | 📋 Backlog |
| US-501 | Xem trước model 3D | Preview | 5 | US-401 | 📋 Backlog |
| US-601 | Export file STL | Export | 5 | US-401 | 📋 Backlog |
| US-602 | Export file OBJ với texture | Export | 5 | US-401 | 📋 Backlog |
| US-901 | Kiểm tra thiết bị hỗ trợ | Compatibility | 2 | - | 📋 Backlog |
| US-701 | Lưu và quản lý các scan | Gallery | 5 | US-101, US-201 | 📋 Backlog |

**Total P0**: 51 points

---

## P1 - High (Important for Launch)

| ID | User Story | Epic | Points | Dependencies | Status |
|----|------------|------|--------|--------------|--------|
| US-102 | Hướng dẫn xoay đầu khi scan | Face Scanning | 5 | US-101 | 📋 Backlog |
| US-103 | Cảnh báo điều kiện scan không tốt | Face Scanning | 3 | US-101 | 📋 Backlog |
| US-202 | Hướng dẫn scan theo chiều dọc | Body Scanning | 5 | US-201 | 📋 Backlog |
| US-203 | Phát hiện chuyển động của đối tượng | Body Scanning | 5 | US-201 | 📋 Backlog |
| US-402 | Chỉnh sửa mesh thủ công | Mesh Processing | 8 | US-401 | 📋 Backlog |
| US-604 | Tùy chọn kích thước khi export | Export | 3 | US-601 | 📋 Backlog |
| US-606 | Share và lưu file | Export | 3 | US-601 | 📋 Backlog |
| US-802 | Hướng dẫn sử dụng trong app | Settings | 3 | - | 📋 Backlog |

**Total P1**: 35 points

---

## P2 - Medium (Nice to Have)

| ID | User Story | Epic | Points | Dependencies | Status |
|----|------------|------|--------|--------------|--------|
| US-301 | Scan bán thân | Bust Scanning | 8 | US-101, US-201 | 📋 Backlog |
| US-403 | Tạo đế cho figure | Mesh Processing | 5 | US-401 | 📋 Backlog |
| US-502 | Xem trước trong AR | Preview | 8 | US-501 | 📋 Backlog |
| US-603 | Export định dạng khác | Export | 5 | US-601 | 📋 Backlog |
| US-702 | Đặt tên cho scan | Gallery | 2 | US-701 | 📋 Backlog |

**Total P2**: 28 points

---

## P3 - Low (Future Enhancement)

| ID | User Story | Epic | Points | Dependencies | Status |
|----|------------|------|--------|--------------|--------|
| US-605 | Tạo model hollow | Export | 5 | US-601 | 📋 Backlog |
| US-801 | Cài đặt chất lượng scan | Settings | 3 | US-101 | 📋 Backlog |

**Total P3**: 8 points

---

## Backlog Item Details

### US-101: Scan khuôn mặt cơ bản
```
Priority: P0 - Critical
Points: 8
Sprint Target: Sprint 1

Technical Tasks:
├── Setup ARKit với LiDAR configuration
├── Implement face detection using Vision framework
├── Create scanning UI với guidance frame
├── Implement depth data capture từ LiDAR
├── Build point cloud to mesh conversion
├── Implement texture capture từ RGB camera
├── Create mesh stitching algorithm
└── Unit tests & integration tests

Definition of Done:
✓ Face detected trong 2 giây
✓ Mesh có ≥ 50,000 vertices
✓ Texture mapped chính xác
✓ Scan hoàn tất trong 30 giây
✓ Code reviewed và merged
✓ Tested trên iPhone 12 Pro, 13 Pro, 14 Pro
```

### US-201: Scan toàn thân 360 độ
```
Priority: P0 - Critical
Points: 13
Sprint Target: Sprint 2

Technical Tasks:
├── Implement body detection
├── Create 360° tracking system
├── Build guidance UI cho người scan
├── Implement continuous mesh capture
├── Create mesh merging algorithm
├── Optimize memory usage cho large meshes
├── Implement texture stitching
└── Performance optimization & testing

Definition of Done:
✓ Full body captured 360°
✓ Mesh có ≥ 200,000 vertices
✓ Scan hoàn tất trong 3 phút
✓ Memory peak < 2GB
✓ Tested với multiple body types
```

### US-401: Tự động xử lý mesh sau scan
```
Priority: P0 - Critical
Points: 8
Sprint Target: Sprint 2

Technical Tasks:
├── Implement hole filling algorithm
├── Build noise reduction filter
├── Create mesh smoothing với configurable levels
├── Implement manifold check & repair
├── Build texture enhancement
├── Create processing pipeline với progress tracking
└── Optimize với Metal compute shaders

Definition of Done:
✓ Mesh output là manifold
✓ Processing < 30s (face), < 2 phút (body)
✓ No visible artifacts
✓ Original detail preserved
```

---

## Release Planning

### Release 1.0 (MVP)
**Target**: Sprint 4 completion
**Scope**: P0 items
**Points**: 51

| Sprint | Items | Points |
|--------|-------|--------|
| Sprint 1 | US-101, US-901 | 10 |
| Sprint 2 | US-201, US-401 | 21 |
| Sprint 3 | US-501, US-601, US-602 | 15 |
| Sprint 4 | US-701, Bug fixes, Polish | 5+ |

### Release 1.5
**Target**: Sprint 7 completion
**Scope**: P0 + P1 items
**Points**: 86 (cumulative)

### Release 2.0
**Target**: Sprint 10 completion
**Scope**: P0 + P1 + P2 items
**Points**: 114 (cumulative)

---

## Dependency Graph

```
                    ┌─────────┐
                    │ US-901  │ (Device Check)
                    └─────────┘
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
      ┌─────────┐   ┌─────────┐   ┌─────────┐
      │ US-101  │   │ US-201  │   │ US-802  │
      │  Face   │   │  Body   │   │ Tutorial│
      └────┬────┘   └────┬────┘   └─────────┘
           │             │
     ┌─────┴───┐   ┌─────┴───┐
     ▼         ▼   ▼         ▼
┌─────────┐┌─────────┐┌─────────┐┌─────────┐
│ US-102  ││ US-103  ││ US-202  ││ US-203  │
│ Guide   ││ Warning ││ V-Guide ││Movement │
└─────────┘└─────────┘└─────────┘└─────────┘
           │             │
           └──────┬──────┘
                  ▼
            ┌─────────┐
            │ US-401  │ (Mesh Processing)
            └────┬────┘
                 │
     ┌───────────┼───────────┐
     ▼           ▼           ▼
┌─────────┐┌─────────┐┌─────────┐
│ US-402  ││ US-403  ││ US-301  │
│  Edit   ││  Base   ││  Bust   │
└─────────┘└─────────┘└─────────┘
                 │
                 ▼
           ┌─────────┐
           │ US-501  │ (Preview)
           └────┬────┘
                │
          ┌─────┴─────┐
          ▼           ▼
    ┌─────────┐ ┌─────────┐
    │ US-502  │ │ US-601  │
    │   AR    │ │   STL   │
    └─────────┘ └────┬────┘
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐
   │ US-602  │ │ US-603  │ │ US-604  │
   │   OBJ   │ │  Other  │ │  Size   │
   └─────────┘ └─────────┘ └────┬────┘
                                │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
              ┌─────────┐ ┌─────────┐ ┌─────────┐
              │ US-605  │ │ US-606  │ │ US-701  │
              │ Hollow  │ │  Share  │ │ Gallery │
              └─────────┘ └─────────┘ └────┬────┘
                                           │
                                           ▼
                                     ┌─────────┐
                                     │ US-702  │
                                     │  Name   │
                                     └─────────┘
```

---

## Backlog Refinement Notes

### Technical Risks
| Risk | Impact | Mitigation | Owner |
|------|--------|------------|-------|
| LiDAR precision limits | High | Calibration, post-processing | Tech Lead |
| Memory constraints | High | Streaming mesh, Metal optimization | iOS Dev |
| Texture quality | Medium | Multi-exposure capture | iOS Dev |
| Large file exports | Medium | Compression, chunked writing | iOS Dev |

### Technical Debt Items
- [ ] Setup CI/CD pipeline
- [ ] Implement crash reporting (Crashlytics/Sentry)
- [ ] Setup analytics framework
- [ ] Create automated UI tests
- [ ] Performance profiling baseline

### Research Spikes
| Spike | Duration | Output |
|-------|----------|--------|
| LiDAR accuracy testing | 2 days | Accuracy report |
| Mesh algorithms comparison | 3 days | Algorithm selection |
| Export format compatibility | 2 days | Test matrix |
| Memory optimization strategies | 2 days | Technical approach |
