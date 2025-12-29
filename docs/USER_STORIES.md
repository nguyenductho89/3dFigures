# User Stories - 3D Figure Scanner App

## Epic 1: Face Scanning

### US-101: Scan khuôn mặt cơ bản
**As a** người dùng
**I want to** scan khuôn mặt của tôi bằng camera LiDAR
**So that** tôi có thể tạo mô hình 3D khuôn mặt của mình

**Story Points**: 8

#### Acceptance Criteria:
- [ ] AC1: Hệ thống phát hiện được khuôn mặt trong khung hình trong vòng 2 giây
- [ ] AC2: Hiển thị khung hướng dẫn đặt khuôn mặt đúng vị trí
- [ ] AC3: Chỉ báo khoảng cách tối ưu (30-50cm) hiển thị real-time
- [ ] AC4: Quá trình scan hoàn tất trong 15-30 giây
- [ ] AC5: Mesh khuôn mặt được tạo với độ chi tiết ≥ 50,000 vertices
- [ ] AC6: Texture được capture và map chính xác lên mesh

---

### US-102: Hướng dẫn xoay đầu khi scan
**As a** người dùng
**I want to** được hướng dẫn xoay đầu đúng cách
**So that** scan được đầy đủ các góc của khuôn mặt

**Story Points**: 5

#### Acceptance Criteria:
- [ ] AC1: Hiển thị animation/arrow hướng dẫn xoay đầu
- [ ] AC2: Phát hiện góc xoay hiện tại của đầu
- [ ] AC3: Thông báo khi đã scan đủ góc (trái, giữa, phải)
- [ ] AC4: Progress bar hiển thị % hoàn thành
- [ ] AC5: Haptic feedback khi hoàn thành mỗi góc

---

### US-103: Cảnh báo điều kiện scan không tốt
**As a** người dùng
**I want to** được cảnh báo khi điều kiện ánh sáng/khoảng cách không phù hợp
**So that** tôi có thể điều chỉnh để có kết quả scan tốt nhất

**Story Points**: 3

#### Acceptance Criteria:
- [ ] AC1: Cảnh báo khi ánh sáng quá yếu (< 50 lux)
- [ ] AC2: Cảnh báo khi ánh sáng quá mạnh/chói
- [ ] AC3: Cảnh báo khi khoảng cách quá gần (< 20cm)
- [ ] AC4: Cảnh báo khi khoảng cách quá xa (> 60cm)
- [ ] AC5: Hiển thị indicator màu (xanh/vàng/đỏ) cho quality

---

## Epic 2: Body Scanning

### US-201: Scan toàn thân 360 độ
**As a** người dùng
**I want to** scan toàn bộ cơ thể một người
**So that** tôi có thể tạo figure 3D toàn thân

**Story Points**: 13

#### Acceptance Criteria:
- [ ] AC1: Phát hiện người đứng trong khung hình
- [ ] AC2: Hướng dẫn người scan đi vòng quanh đối tượng
- [ ] AC3: Tracking tiến trình scan theo góc (0° → 360°)
- [ ] AC4: Capture liên tục ở khoảng cách 1-2m
- [ ] AC5: Thời gian scan tối đa 3 phút
- [ ] AC6: Mesh body hoàn chỉnh với ≥ 200,000 vertices
- [ ] AC7: Ghép nối các phần mesh liền mạch

---

### US-202: Hướng dẫn scan theo chiều dọc
**As a** người dùng
**I want to** được hướng dẫn scan từ đầu xuống chân
**So that** không bỏ sót phần nào của cơ thể

**Story Points**: 5

#### Acceptance Criteria:
- [ ] AC1: Hiển thị indicator vùng đang scan (đầu/thân/chân)
- [ ] AC2: Hướng dẫn di chuyển camera lên/xuống
- [ ] AC3: Highlight vùng chưa được scan
- [ ] AC4: Thông báo hoàn thành từng section
- [ ] AC5: Cho phép scan lại vùng cụ thể nếu cần

---

### US-203: Phát hiện chuyển động của đối tượng
**As a** người dùng
**I want to** hệ thống phát hiện khi người được scan di chuyển
**So that** tôi có thể yêu cầu họ đứng yên để scan chính xác

**Story Points**: 5

#### Acceptance Criteria:
- [ ] AC1: Phát hiện chuyển động > 5cm trong 1 giây
- [ ] AC2: Pause quá trình scan khi phát hiện chuyển động
- [ ] AC3: Hiển thị cảnh báo "Vui lòng đứng yên"
- [ ] AC4: Tự động resume khi đối tượng đứng yên
- [ ] AC5: Lưu lại phần đã scan trước đó

---

## Epic 3: Bust Scanning

### US-301: Scan bán thân
**As a** người dùng
**I want to** scan phần bán thân (đầu đến vai)
**So that** tôi có thể tạo bust figure

**Story Points**: 8

#### Acceptance Criteria:
- [ ] AC1: Tự động xác định vùng từ đầu đến vai/ngực
- [ ] AC2: Hướng dẫn scan vòng quanh phần trên cơ thể
- [ ] AC3: Thời gian scan 30-60 giây
- [ ] AC4: Mesh bust với ≥ 100,000 vertices
- [ ] AC5: Cắt mesh tự động tại vị trí vai/ngực

---

## Epic 4: Mesh Processing

### US-401: Tự động xử lý mesh sau scan
**As a** người dùng
**I want to** mesh được tự động xử lý và làm sạch
**So that** tôi có model 3D sẵn sàng để in

**Story Points**: 8

#### Acceptance Criteria:
- [ ] AC1: Tự động vá các lỗ (holes) trong mesh
- [ ] AC2: Giảm nhiễu (noise reduction) tự động
- [ ] AC3: Làm mịn bề mặt (smoothing) ở mức phù hợp
- [ ] AC4: Thời gian xử lý < 30 giây cho face, < 2 phút cho body
- [ ] AC5: Hiển thị progress bar trong quá trình xử lý
- [ ] AC6: Mesh output là manifold (kín, có thể in 3D)

---

### US-402: Chỉnh sửa mesh thủ công
**As a** người dùng
**I want to** có thể chỉnh sửa mesh sau khi scan
**So that** tôi có thể cắt bỏ phần không cần thiết hoặc điều chỉnh

**Story Points**: 8

#### Acceptance Criteria:
- [ ] AC1: Công cụ crop để cắt bỏ phần mesh
- [ ] AC2: Công cụ scale để điều chỉnh kích thước
- [ ] AC3: Gesture xoay/zoom/pan để xem mesh từ mọi góc
- [ ] AC4: Undo/Redo cho các thao tác chỉnh sửa
- [ ] AC5: Preview thay đổi real-time

---

### US-403: Tạo đế cho figure
**As a** người dùng
**I want to** tự động tạo đế cho model
**So that** figure có thể đứng vững khi in ra

**Story Points**: 5

#### Acceptance Criteria:
- [ ] AC1: Tùy chọn tạo đế tròn/vuông/custom
- [ ] AC2: Tự động căn chỉnh model trên đế
- [ ] AC3: Điều chỉnh kích thước đế
- [ ] AC4: Điều chỉnh độ cao đế
- [ ] AC5: Preview đế trước khi apply

---

## Epic 5: Preview & Visualization

### US-501: Xem trước model 3D
**As a** người dùng
**I want to** xem trước model 3D sau khi scan
**So that** tôi có thể kiểm tra chất lượng trước khi export

**Story Points**: 5

#### Acceptance Criteria:
- [ ] AC1: Render model 3D với texture
- [ ] AC2: Xoay model bằng gesture
- [ ] AC3: Zoom in/out bằng pinch
- [ ] AC4: Xem ở chế độ wireframe
- [ ] AC5: Hiển thị thông tin mesh (vertices, faces, size)

---

### US-502: Xem trước trong AR
**As a** người dùng
**I want to** đặt model 3D vào không gian thực bằng AR
**So that** tôi có thể hình dung kích thước thực tế khi in

**Story Points**: 8

#### Acceptance Criteria:
- [ ] AC1: Phát hiện mặt phẳng trong không gian thực
- [ ] AC2: Đặt model lên mặt phẳng
- [ ] AC3: Scale model theo kích thước in thực tế
- [ ] AC4: Di chuyển và xoay model trong AR
- [ ] AC5: So sánh với các vật thể xung quanh

---

## Epic 6: Export & Sharing

### US-601: Export file STL
**As a** người dùng
**I want to** export model ra file STL
**So that** tôi có thể in 3D trên máy FDM/SLA

**Story Points**: 5

#### Acceptance Criteria:
- [ ] AC1: Export file STL binary format
- [ ] AC2: Tùy chọn đơn vị (mm, cm, inch)
- [ ] AC3: File output là manifold và watertight
- [ ] AC4: Thời gian export < 10 giây
- [ ] AC5: Hiển thị kích thước file trước khi export

---

### US-602: Export file OBJ với texture
**As a** người dùng
**I want to** export model ra file OBJ kèm texture
**So that** tôi có thể in 3D màu hoặc sử dụng trong phần mềm 3D khác

**Story Points**: 5

#### Acceptance Criteria:
- [ ] AC1: Export file OBJ + MTL + texture images
- [ ] AC2: Texture resolution options (1K, 2K, 4K)
- [ ] AC3: Pack thành file ZIP để dễ share
- [ ] AC4: UV mapping chính xác
- [ ] AC5: Compatible với Blender, Maya, 3ds Max

---

### US-603: Export định dạng khác (GLB, USDZ, PLY)
**As a** người dùng
**I want to** export ra nhiều định dạng file khác nhau
**So that** tôi có thể sử dụng model cho nhiều mục đích

**Story Points**: 5

#### Acceptance Criteria:
- [ ] AC1: Export GLB/GLTF cho web và game
- [ ] AC2: Export USDZ cho Apple AR
- [ ] AC3: Export PLY cho point cloud applications
- [ ] AC4: Mỗi format có options phù hợp
- [ ] AC5: Validate file sau khi export

---

### US-604: Tùy chọn kích thước khi export
**As a** người dùng
**I want to** điều chỉnh kích thước model khi export
**So that** model phù hợp với kích thước in mong muốn

**Story Points**: 3

#### Acceptance Criteria:
- [ ] AC1: Input chiều cao mong muốn (cm/inch)
- [ ] AC2: Tự động scale proportional
- [ ] AC3: Preset sizes (5cm, 10cm, 15cm, 20cm, 30cm)
- [ ] AC4: Custom size input
- [ ] AC5: Hiển thị kích thước XYZ sau khi scale

---

### US-605: Tạo model hollow
**As a** người dùng
**I want to** tạo model rỗng bên trong
**So that** tiết kiệm vật liệu khi in 3D

**Story Points**: 5

#### Acceptance Criteria:
- [ ] AC1: Tùy chọn bật/tắt hollow
- [ ] AC2: Điều chỉnh độ dày wall (1-3mm)
- [ ] AC3: Tự động tạo drain holes
- [ ] AC4: Preview cross-section
- [ ] AC5: Estimate material savings

---

### US-606: Share và lưu file
**As a** người dùng
**I want to** share file qua các app khác hoặc lưu vào Files
**So that** tôi có thể gửi cho dịch vụ in 3D hoặc lưu trữ

**Story Points**: 3

#### Acceptance Criteria:
- [ ] AC1: Share sheet iOS native
- [ ] AC2: Lưu vào Files app
- [ ] AC3: Gửi qua AirDrop
- [ ] AC4: Share qua email, Messages
- [ ] AC5: Upload lên cloud (iCloud, Dropbox, Google Drive)

---

## Epic 7: Gallery & Management

### US-701: Lưu và quản lý các scan
**As a** người dùng
**I want to** lưu các scan đã thực hiện vào gallery
**So that** tôi có thể xem lại và export sau

**Story Points**: 5

#### Acceptance Criteria:
- [ ] AC1: Tự động lưu sau khi scan thành công
- [ ] AC2: Thumbnail preview cho mỗi scan
- [ ] AC3: Hiển thị ngày tạo, loại scan
- [ ] AC4: Tìm kiếm và filter
- [ ] AC5: Xóa scan không cần thiết

---

### US-702: Đặt tên cho scan
**As a** người dùng
**I want to** đặt tên cho mỗi scan
**So that** tôi dễ dàng phân biệt và tìm kiếm

**Story Points**: 2

#### Acceptance Criteria:
- [ ] AC1: Prompt đặt tên sau khi scan
- [ ] AC2: Đổi tên scan trong gallery
- [ ] AC3: Tên mặc định theo timestamp
- [ ] AC4: Validate tên (không trống, không ký tự đặc biệt)

---

## Epic 8: Settings & Preferences

### US-801: Cài đặt chất lượng scan
**As a** người dùng
**I want to** điều chỉnh chất lượng scan
**So that** cân bằng giữa chất lượng và thời gian xử lý

**Story Points**: 3

#### Acceptance Criteria:
- [ ] AC1: Tùy chọn Low/Medium/High/Ultra quality
- [ ] AC2: Hiển thị estimated scan time
- [ ] AC3: Hiển thị estimated file size
- [ ] AC4: Remember last setting
- [ ] AC5: Recommend setting based on device

---

### US-802: Hướng dẫn sử dụng trong app
**As a** người dùng mới
**I want to** xem hướng dẫn sử dụng app
**So that** tôi biết cách scan đúng cách

**Story Points**: 3

#### Acceptance Criteria:
- [ ] AC1: Onboarding tutorial khi mở app lần đầu
- [ ] AC2: Video hướng dẫn cho từng loại scan
- [ ] AC3: Tips hiển thị trong quá trình scan
- [ ] AC4: Help section trong Settings
- [ ] AC5: Skip option cho users có kinh nghiệm

---

## Epic 9: Device Compatibility

### US-901: Kiểm tra thiết bị hỗ trợ
**As a** người dùng
**I want to** biết thiết bị của tôi có hỗ trợ app không
**So that** tôi không tải app về mà không dùng được

**Story Points**: 2

#### Acceptance Criteria:
- [ ] AC1: Check LiDAR availability khi mở app
- [ ] AC2: Thông báo rõ ràng nếu không có LiDAR
- [ ] AC3: Danh sách thiết bị hỗ trợ trong App Store description
- [ ] AC4: Graceful degradation message
- [ ] AC5: Link đến trang support

---

## User Story Summary

| Epic | Stories | Total Points |
|------|---------|--------------|
| Epic 1: Face Scanning | 3 | 16 |
| Epic 2: Body Scanning | 3 | 23 |
| Epic 3: Bust Scanning | 1 | 8 |
| Epic 4: Mesh Processing | 3 | 21 |
| Epic 5: Preview & Visualization | 2 | 13 |
| Epic 6: Export & Sharing | 6 | 26 |
| Epic 7: Gallery & Management | 2 | 7 |
| Epic 8: Settings & Preferences | 2 | 6 |
| Epic 9: Device Compatibility | 1 | 2 |
| **Total** | **23** | **122** |
