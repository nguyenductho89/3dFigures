# PRD: 3D Figure Scanner App

## 1. Tổng quan sản phẩm

### 1.1 Mô tả
Ứng dụng iOS cho phép người dùng sử dụng camera LiDAR trên iPhone 12 Pro trở lên để scan khuôn mặt và toàn thân, tạo mô hình 3D chất lượng cao có thể xuất ra file để in 3D.

### 1.2 Mục tiêu
- Cho phép người dùng tự scan và tạo mô hình 3D của bản thân hoặc người khác
- Xuất file 3D tương thích với máy in 3D phổ biến
- Trải nghiệm đơn giản, dễ sử dụng cho người dùng phổ thông

### 1.3 Đối tượng người dùng
- Người dùng cá nhân muốn tạo tượng/figure của bản thân
- Người làm quà tặng cá nhân hóa
- Nghệ sĩ/designer cần scan nhanh mẫu 3D

---

## 2. Yêu cầu thiết bị

### 2.1 Thiết bị hỗ trợ
| Thiết bị | LiDAR | Hỗ trợ |
|----------|-------|--------|
| iPhone 12 Pro / Pro Max | ✅ | ✅ |
| iPhone 13 Pro / Pro Max | ✅ | ✅ |
| iPhone 14 Pro / Pro Max | ✅ | ✅ |
| iPhone 15 Pro / Pro Max | ✅ | ✅ |
| iPhone 16 Pro / Pro Max | ✅ | ✅ |
| iPad Pro (2020 trở lên) | ✅ | ✅ |

### 2.2 Yêu cầu hệ thống
- iOS 16.0 trở lên
- Dung lượng trống: 500MB+
- RAM: 6GB+ (khuyến nghị)

---

## 3. Tính năng chính

### 3.1 Chế độ Scan

#### 3.1.1 Face Scan (Scan khuôn mặt)
- **Mô tả**: Scan chi tiết khuôn mặt từ nhiều góc độ
- **Quy trình**:
  1. Đặt khuôn mặt trong khung hướng dẫn
  2. Xoay đầu từ từ theo hướng dẫn (trái → giữa → phải)
  3. Hệ thống tự động capture và ghép mesh
- **Khoảng cách tối ưu**: 30-50cm
- **Thời gian scan**: 15-30 giây
- **Output**: Mesh khuôn mặt với texture

#### 3.1.2 Body Scan (Scan toàn thân)
- **Mô tả**: Scan toàn bộ cơ thể để tạo figure
- **Quy trình**:
  1. Đối tượng đứng yên trên một điểm
  2. Người scan đi vòng quanh 360°
  3. Scan từ đầu xuống chân theo hướng dẫn
- **Khoảng cách tối ưu**: 1-2m
- **Thời gian scan**: 1-3 phút
- **Output**: Full body mesh với texture

#### 3.1.3 Bust Scan (Scan bán thân)
- **Mô tả**: Scan từ đầu đến ngực/vai
- **Thời gian scan**: 30-60 giây
- **Use case**: Tạo bust figure, avatar

### 3.2 Xử lý Mesh

#### 3.2.1 Auto Processing
- Hole filling (vá lỗ mesh)
- Noise reduction (giảm nhiễu)
- Mesh smoothing (làm mịn bề mặt)
- Texture enhancement (cải thiện texture)

#### 3.2.2 Manual Editing
- Crop/trim mesh (cắt bỏ phần không cần thiết)
- Scale adjustment (điều chỉnh kích thước)
- Base generation (tạo đế cho figure)
- Pose adjustment cơ bản

### 3.3 Export Options

#### 3.3.1 Định dạng file
| Format | Mô tả | Use case |
|--------|-------|----------|
| STL | Standard Tessellation Language | In 3D FDM/SLA |
| OBJ | Wavefront OBJ (với MTL) | In 3D có màu |
| GLB/GLTF | GL Transmission Format | AR/VR, Web |
| USDZ | Universal Scene Description | Apple AR |
| PLY | Polygon File Format | Point cloud |

#### 3.3.2 Tùy chọn export
- **Kích thước thực tế**: Tỷ lệ 1:1 hoặc custom scale
- **Độ phân giải mesh**: Low/Medium/High/Ultra
- **Có/không texture**: Tùy chọn xuất có màu
- **Hollow model**: Tạo model rỗng để tiết kiệm vật liệu in

### 3.4 Preview & AR

- Xem trước model 3D trong app
- AR Preview: Đặt model vào không gian thực
- Xem trước kích thước in thực tế

---

## 4. Luồng người dùng (User Flow)

```
┌─────────────┐
│   Mở App    │
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌─────────────┐
│ Chọn chế độ │────▶│ Face Scan   │
│    scan     │     ├─────────────┤
└──────┬──────┘     │ Body Scan   │
       │            ├─────────────┤
       │            │ Bust Scan   │
       │            └──────┬──────┘
       │                   │
       ▼                   ▼
┌─────────────┐     ┌─────────────┐
│  Hướng dẫn  │────▶│  Scanning   │
│   chuẩn bị  │     │  Process    │
└─────────────┘     └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  Processing │
                    │    Mesh     │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │   Preview   │
                    │   & Edit    │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │   Export    │
                    │    File     │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  Share /    │
                    │  Save       │
                    └─────────────┘
```

---

## 5. Yêu cầu kỹ thuật

### 5.1 Frameworks & APIs

| Component | Technology |
|-----------|------------|
| 3D Scanning | ARKit + LiDAR |
| Depth Capture | AVFoundation + ARKit |
| Mesh Processing | Model I/O, Metal |
| 3D Rendering | SceneKit / RealityKit |
| AR Preview | ARKit + RealityKit |
| Export | Model I/O |

### 5.2 ARKit Capabilities
- `ARWorldTrackingConfiguration`
- `ARFaceTrackingConfiguration` (cho Face Scan)
- `ARBodyTrackingConfiguration` (optional)
- Scene Reconstruction với LiDAR
- Mesh classification

### 5.3 Data Flow
```
LiDAR Sensor
     │
     ▼
ARKit Depth Data + RGB Camera
     │
     ▼
Point Cloud Generation
     │
     ▼
Mesh Reconstruction
     │
     ▼
Texture Mapping
     │
     ▼
Post Processing
     │
     ▼
Export to File
```

### 5.4 Performance Requirements
- Scan capture: 30 FPS minimum
- Mesh processing: < 30 giây cho face, < 2 phút cho body
- Export: < 10 giây
- App memory: < 2GB peak

---

## 6. UI/UX Requirements

### 6.1 Màn hình chính

#### Home Screen
- Logo và tên app
- 3 nút chính: Face Scan, Body Scan, Bust Scan
- Gallery (các scan đã lưu)
- Settings

#### Scan Screen
- Camera view full screen
- Guidance overlay (khung hướng dẫn)
- Progress indicator
- Real-time mesh preview (optional)
- Lighting quality indicator
- Distance indicator

#### Preview Screen
- 3D viewer với gesture controls (rotate, zoom, pan)
- Toolbar: Edit, AR View, Export
- Mesh quality info
- Kích thước model

#### Export Screen
- Format selection
- Scale/size options
- Quality settings
- Export button
- Share options

### 6.2 Design Guidelines
- Dark mode support
- Haptic feedback khi hoàn thành scan
- Voice guidance (optional)
- Accessibility support

---

## 7. Xử lý lỗi & Edge Cases

### 7.1 Điều kiện ánh sáng
- Cảnh báo khi ánh sáng quá yếu/mạnh
- Hướng dẫn điều chỉnh ánh sáng

### 7.2 Movement Detection
- Phát hiện đối tượng di chuyển
- Pause và hướng dẫn đứng yên

### 7.3 Incomplete Scan
- Phát hiện vùng chưa scan
- Highlight và hướng dẫn scan bổ sung

### 7.4 Device Compatibility
- Check LiDAR availability khi mở app
- Thông báo rõ ràng nếu thiết bị không hỗ trợ

---

## 8. Monetization (Optional)

### 8.1 Freemium Model
**Free tier:**
- 3 scans/tháng
- Export STL only
- Watermark trên preview

**Premium tier:**
- Unlimited scans
- Tất cả định dạng export
- Advanced editing tools
- Cloud storage
- No watermark

### 8.2 Giá đề xuất
- Monthly: $4.99/tháng
- Yearly: $29.99/năm
- Lifetime: $79.99

---

## 9. Metrics & Analytics

### 9.1 KPIs
- Daily/Monthly Active Users
- Scans completed per user
- Export success rate
- Average scan quality score
- Conversion rate (free → premium)

### 9.2 Events to Track
- App open
- Scan started/completed/failed
- Export format selected
- Share action
- Premium upgrade

---

## 10. Roadmap

### Phase 1: MVP (v1.0)
- [ ] Face Scan cơ bản
- [ ] Body Scan cơ bản
- [ ] Export STL, OBJ
- [ ] Basic preview

### Phase 2: Enhanced (v1.5)
- [ ] Improved mesh quality
- [ ] AR Preview
- [ ] More export formats
- [ ] Basic editing tools

### Phase 3: Advanced (v2.0)
- [ ] Multi-person scan
- [ ] Cloud processing
- [ ] AI-powered mesh enhancement
- [ ] Integration với 3D printing services

### Phase 4: Platform (v3.0)
- [ ] Social features (share, gallery)
- [ ] Marketplace cho templates
- [ ] API cho developers
- [ ] Android version

---

## 11. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| LiDAR accuracy limitations | High | Guided scanning, post-processing |
| Large file sizes | Medium | Compression, cloud storage |
| Complex UI overwhelms users | Medium | Progressive disclosure, tutorials |
| Privacy concerns (face data) | High | Local processing, clear privacy policy |
| 3D print quality issues | Medium | Print guidelines, partner printers |

---

## 12. Success Criteria

### Launch Criteria
- Scan success rate > 80%
- Export success rate > 95%
- App crash rate < 1%
- App Store rating > 4.0

### Growth Criteria (6 months)
- 100K+ downloads
- 10K+ monthly active users
- 5% premium conversion
- Average 3+ scans per active user

---

## Appendix

### A. Glossary
- **LiDAR**: Light Detection and Ranging - công nghệ đo khoảng cách bằng laser
- **Mesh**: Lưới đa giác 3D tạo nên bề mặt model
- **Texture**: Hình ảnh màu sắc áp lên bề mặt mesh
- **STL**: Định dạng file 3D phổ biến cho in 3D
- **Point Cloud**: Tập hợp các điểm trong không gian 3D

### B. References
- [ARKit Documentation](https://developer.apple.com/documentation/arkit)
- [LiDAR Scanner API](https://developer.apple.com/documentation/arkit/arkit_in_ios/content_anchors/visualizing_and_interacting_with_a_reconstructed_scene)
- [Model I/O Framework](https://developer.apple.com/documentation/modelio)
