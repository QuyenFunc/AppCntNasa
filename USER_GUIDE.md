

## 1. Realtime (EarthScope)

### Kết nối NTRIP
**Panel kết nối** ở đầu màn hình:
- **Đèn trạng thái**: Xanh = đã kết nối, Đỏ = chưa kết nối
- **Nút Connect/Disconnect**: Kết nối hoặc ngắt kết nối
- **Nút mở rộng**: Hiện form cấu hình chi tiết

**Cấu hình kết nối**:
- **Quick Setup**: Chọn máy chủ có sẵn (EarthScope, RTK2GO, EUREF, BKG)
- **Thủ công**: Nhập Host, Port, Mountpoint, Username/Password
- **Sourcetable**: Xem danh sách mountpoint có sẵn
- **Export Log**: Xuất nhật ký kết nối

### 3 Tab con:

**Map**: Hiển thị vị trí trạm GNSS trên bản đồ

**Stations**: 
- Tìm kiếm mountpoint theo tên/vị trí
- Lọc theo Public, Multi-GNSS, Real-time
- Danh sách mountpoint với thông tin ID, vị trí, định dạng, loại dữ liệu
- Nhấn Connect để kết nối

**Charts**: Biểu đồ thời gian thực
- **Auto Refresh**: Bật/tắt tự động cập nhật
- **Refresh Interval**: Chọn 1, 2, 5, hoặc 10 giây
- **Biểu đồ Bitrate**: Tốc độ truyền dữ liệu
- **Frame Count**: Số frame nhận được  
- **RTCM Message Types**: Phân bố loại thông điệp
- **Statistics**: Thống kê tổng quan

---

## 2. Offline (Earthdata)

### Xác thực NASA Earthdata
Panel đầu màn hình để đăng nhập tài khoản NASA Earthdata.

### 3 Tab con:

**Search**: Tìm kiếm dữ liệu
- **Station ID**: Mã 4 ký tự trạm GNSS (ALGO, GODE, USNO...)
- **Start/End Date**: Chọn khoảng thời gian
- **Data Type**: Chọn loại dữ liệu:
  - **RINEX** 📻: Dữ liệu quan sát GNSS thô
  - **Orbit** 🎯: Quỹ đạo chính xác vệ tinh
  - **Clock** ⏰: Hiệu chỉnh đồng hồ vệ tinh  
  - **Ephemeris** 🛰️: Thông số quỹ đạo từ vệ tinh
  - **Ionosphere** 🌌: Dữ liệu tầng điện ly
- **Popular Stations**: Chọn nhanh trạm phổ biến
- **Search Results**: Danh sách file tìm được, nhấn Download để tải

**Downloads**: Quản lý file đang tải và đã tải

**Viewer**: Mở và xem nội dung file đã tải

---

## 3. NASA Worldview

### Điều khiển chính
**Thanh trên**:
- **Search** 🔍: Tìm địa điểm và di chuyển bản đồ
- **Layers** 📋: Mở panel quản lý lớp vệ tinh

**Panel Layers** (bên phải):
- **Search layers**: Tìm lớp vệ tinh
- **Date picker** 📅: Chọn ngày xem (dữ liệu từ 7 ngày trước)
- **Layer list**: Danh sách lớp vệ tinh
  - Checkbox để bật/tắt lớp
  - Slider điều chỉnh độ trong suốt

**Nút điều khiển** (góc trái):
- **+/-**: Phóng to/thu nhỏ
- **🎯**: Về vị trí mặc định
- **⏮️**: Chuyển về ngày trước

### Thao tác bản đồ
- **Kéo**: Di chuyển bản đồ
- **Chụm/mở rộng**: Thu phóng bản đồ

---

## 4. NASA FIRMS (Cháy rừng)

### Điều khiển chính
**Thanh trên**:
- **Search** 🔍: Tìm khu vực dễ cháy
- **Filter** 📋: Mở panel bộ lọc
- **Menu** ⋮: Statistics, API Info

**Panel Filter** (bên phải):
- **Data Source**: Chọn nguồn (VIIRS SNPP, VIIRS NOAA-20, MODIS)
- **Time Range**: Slider chọn 1-10 ngày
- **Hiển thị markers**: 
  - Bật "Hiển thị tất cả" để xem hết (có thể lag)
  - Tắt để chỉ hiển thị ưu tiên (tối ưu)

### Thông tin cháy
- **Markers màu sắc**: 
  - Đỏ đậm = Cực mạnh
  - Đỏ = Mạnh  
  - Cam = Trung bình
  - Vàng = Yếu
  - Xám = Không xác định
- **Nhấn marker**: Xem chi tiết đám cháy
- **Panel thông tin** (dưới cùng): Số lượng cháy, độ tin cậy, nguồn dữ liệu

