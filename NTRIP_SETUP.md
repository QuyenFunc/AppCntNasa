# NASA GNSS Client - NTRIP Setup Guide

## ✅ Đã sửa lỗi 401 Authentication

### 🔧 **Các thay đổi đã thực hiện:**

1. **NASA API Service** - Chuyển từ Basic Auth sang Bearer Token
   - Sử dụng `https://cmr.earthdata.nasa.gov` thay vì `urs.earthdata.nasa.gov`
   - Dùng `Authorization: Bearer TOKEN` thay vì Basic Auth
   - Thêm methods `getGranules()` và `getCollections()`

2. **NTRIP Client mới** - Kết nối thật với RTCM stream
   - File: `lib/services/ntrip_client.dart`
   - Hỗ trợ TCP (2101) và TLS (443)
   - Parse RTCM3 messages và thống kê real-time
   - Method `getSourcetable()` để lấy danh sách mountpoints

3. **NTRIP Connect Screen** - UI để test kết nối
   - File: `lib/screens/ntrip_connect_screen.dart`
   - Form nhập host/port/mountpoint/credentials
   - Hiển thị throughput, message count, statistics
   - Button "Get Sourcetable" để xem available streams

4. **Android Permissions** - Thêm network permissions
   - `INTERNET` và `ACCESS_NETWORK_STATE`
   - File export permissions

## 🚀 **Cách sử dụng:**

### **1. Lấy NASA Bearer Token:**
```
1. Vào https://urs.earthdata.nasa.gov/
2. Login vào account
3. Profile → Applications → Generate Token
4. Copy Bearer token
5. Paste vào JWT field trong app
```

### **2. Test NTRIP Connection:**
```
1. Trong login screen, nhấn "Test NTRIP Connection"
2. Nhập thông tin caster:
   - Host: products.igs-ip.net
   - Port: 2101 (TCP) hoặc 443 (TLS)
   - Mountpoint: BCEP00BKG0
   - Username/Password: credentials từ NTRIP provider
3. Nhấn "Get Sourcetable" để xem available streams
4. Nhấn "Connect" để test stream
```

### **3. Test với cURL trước:**
```bash
# TCP (port 2101)
curl -v --user USER:PASS "http://products.igs-ip.net:2101/BCEP00BKG0"

# TLS (port 443)  
curl -v --user USER:PASS "https://products.igs-ip.net/BCEP00BKG0"
```

## 📋 **Kết quả:**

✅ **Không còn lỗi 401** - Bearer token authentication  
✅ **NTRIP client hoàn chỉnh** - Real RTCM stream parsing  
✅ **UI test connection** - Debug credentials dễ dàng  
✅ **Android permissions** - Network access đầy đủ  
✅ **Sourcetable support** - Xem available mountpoints  

## 🔍 **Debug 401 errors:**

1. **NASA API 401** → Cần Bearer token hợp lệ từ Earthdata
2. **NTRIP 401** → Cần username/password đúng từ NTRIP provider
3. **Test cURL trước** → Verify credentials work outside app

App bây giờ sử dụng đúng authentication methods cho từng service!
