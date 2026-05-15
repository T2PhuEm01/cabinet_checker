# Hướng Dẫn Xuất Ảnh Lên Google Drive (Phiên Bản Mới)

## 📱 Tính Năng Mới - Không Cần Google Apps Script

✨ **Cập nhật:** Ứng dụng giờ có thể **upload ảnh trực tiếp lên Google Drive của bạn** mà không cần cấu hình Google Apps Script phức tạp!

---

## 🔐 Bước 1: Cấu Hình Google Cloud Console (Lần Đầu Tiên)

### 1. Tạo Google Cloud Project

1. Vào https://console.cloud.google.com
2. Nhấn **Select a Project** (Chọn Dự Án) ở góc trên cùng
3. Chọn **NEW PROJECT** (DỰ ÁN MỚI)
4. Nhập tên: **Cabinet Checker**
5. Nhấn **CREATE**
6. Chờ dự án được tạo (vài giây)

### 2. Bật Google Drive API

1. Ở thanh tìm kiếm, nhập: **Google Drive API**
2. Chọn kết quả **Google Drive API**
3. Nhấn nút **ENABLE** (BẬT)
4. Chờ API được bật

### 3. Tạo OAuth Consent Screen

1. Ở menu bên trái, chọn **OAuth consent screen** (Màn hình Đồng Ý OAuth)
2. Chọn **External** (Bên Ngoài)
3. Nhấn **CREATE**
4. Điền thông tin:
   - **App name:** Cabinet Checker
   - **User support email:** [Nhập email của bạn]
   - **Developer contact information:** [Nhập email của bạn]
5. Nhấn **SAVE AND CONTINUE**
6. Cứ **CONTINUE** cho đến khi xong (không cần thêm scopes)
7. Nhấn **SAVE AND CONTINUE** lần cuối
8. Nhấn **BACK TO DASHBOARD**

### 4. Tạo OAuth 2.0 Credentials

1. Ở menu bên trái, chọn **Credentials** (Thông Tin Xác Thực)
2. Nhấn **+ CREATE CREDENTIALS** (+ TẠO THÔNG TIN XÁC THỰC)
3. Chọn **OAuth 2.0 Client ID**
4. Chọn loại: **Android**
5. Trong mục **Package name**, nhập: 
   ```
   com.example.cabinet_checker
   ```
6. Nhân **Create**
7. **Sao chép Cert SHA-1** nếu được yêu cầu (chúng tôi sẽ cấu hình sau)
8. Nhấn **OK**

---

## 📱 Bước 2: Cấu Hình Android

Bạn cần cập nhật file `build.gradle` trong thư mục `android/app/`:

1. Mở file: `android/app/build.gradle.kts`
2. Tìm dòng: `package = "com.example.cabinet_checker"` 
3. **Ghi nhớ giá trị này - nó là Package Name**

### Cách Đơn Giản (Khuyến Nghị):

**Bỏ qua lấy SHA-1 trước.**  Hãy:

1. Build và chạy ứng dụng bình thường
2. Nhấn nút **Thư viện ảnh** 📸 để thử đăng nhập
3. Google sẽ hiển thị **lỗi kèm SHA-1**
4. Copy SHA-1 từ lỗi đó
5. Quay lại Google Cloud Console
6. Vào **Credentials** → **OAuth 2.0 Client ID (Android)**
7. Nhấn **Edit** (biểu tượng bút chì)
8. Paste SHA-1 vào
9. Nhấn **Save**
10. Quay lại app và thử đăng nhập lại

**✅ Xong!** Đơn giản hơn khi không cần lệnh terminal.

---

### Nếu muốn lấy trước (tùy chọn):

1. Mở Terminal (Command Prompt)
2. Di chuyển đến thư mục dự án
3. Chạy lệnh:
   ```bash
   ./gradlew signingReport
   ```
   (hoặc `gradlew signingReport` trên Windows)
4. Tìm **SHA-1** trong kết quả đầu ra
5. Thêm vào Google Cloud Console như bước 5-9 ở trên

---

## 🔧 Bước 3: Cấu Hình Ứng Dụng Flutter

### Update `android/app/build.gradle.kts`:

Tìm `android { ... }` section và thêm dòng sau:

```gradle
android {
    compileSdk 34
    ndkVersion "27.0.12077973"
    
    // Thêm dòng này
    defaultConfig {
        applicationId = "com.example.cabinet_checker"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        // ... rest of config
    }
    
    // ... rest of android config
}
```

---

## 🎯 Bước 4: Cài Đặt Dependencies

### Lệnh tự động:

Terminal tại thư mục dự án, chạy:

```bash
flutter pub get
```

Nó sẽ tự động cài đặt 2 package mới:
- `google_sign_in` (để đăng nhập Google)
- `googleapis` (để sử dụng Google Drive API)

### Hoặc thủ công:

1. Mở Terminal
2. Chạy:
   ```bash
   flutter pub add google_sign_in
   flutter pub add googleapis
   ```

---

## 📱 Bước 5: Sử Dụng Ứng Dụng

### Lần Đầu Tiên:

1. **Khởi động ứng dụng**
2. Nhấn nút **Thư viện ảnh** 📸 (trong thanh công cụ)
3. Ứng dụng sẽ:
   - Hiển thị cửa sổ **Đăng nhập Google**
   - Yêu cầu bạn chọn tài khoản Google
   - **Cấp quyền** cho ứng dụng truy cập Google Drive
4. **Nhấn "Cho phép"** (Allow) khi được hỏi
5. Ứng dụng bắt đầu xuất ảnh

### Lần Tiếp Theo:

1. Nhấn nút **Thư viện ảnh** 📸
2. Ứng dụng tự động dùng tài khoản đã đăng nhập
3. Chờ cho đến khi thấy thông báo **"Xuất thành công!"**

---

## 📂 Cấu Trúc Thư Mục Trên Google Drive

Sau khi xuất, Google Drive sẽ tạo:

```
Google Drive
└── Cabinet Checker - Ảnh Tũ/
    └── 14/05/2026/
        ├── vỏ tủ không đạt/
        │   ├── TNH0024_1.jpg
        │   ├── TNH0024_2.jpg
        │   └── TNH0031_1.jpg
        │
        ├── nhãn không đạt/
        │   └── TNH0025_1.jpg
        │
        ├── cáp nhập tủ không đạt/
        │   └── TNH0026_1.jpg
        │
        ├── tủ sai vị trí/
        │   └── TNH0027_1.jpg
        │
        └── Lắp đặt không chắc chắn/Nguy cơ rơi đổ (TLĐKCC/NCRĐ)/
            └── TNH0028_1.jpg
```

---

## ⚙️ Đổi Tài Khoản Google

Nếu muốn đăng nhập bằng tài khoản Google khác:

1. Vào **Settings** (Cài đặt) ứng dụng
2. Tìm **Tài khoản Google**
3. Nhấn **Đăng xuất** hoặc **Thay Đổi Tài Khoản**
4. Lần tiếp theo xuất, ứng dụng sẽ hỏi tài khoản mới

---

## ⚠️ Xử Lý Lỗi

### Lỗi: "Đăng nhập Google thất bại"

**Cách sửa:**
1. Kiểm tra kết nối Internet
2. Kiểm tra có tài khoản Google không
3. Cài lại ứng dụng

### Lỗi: "Permission Denied" hoặc "Chưa cấp quyền"

**Cách sửa:**
1. Vào **Settings** → **Apps** → **Cabinet Checker**
2. Chọn **Permissions** (Quyền)
3. Cấp quyền cho **Camera** và **Storage**
4. Thử lại

### Không thấy ảnh trên Google Drive

**Cách sửa:**
1. Kiểm tra có bản ghi nào có vấn đề không (có dấu ✓ ở mục lỗi)
2. Kiểm tra bản ghi đó có ảnh không
3. Nếu không, hãy thêm ảnh vào bản ghi có vấn đề
4. Thử xuất lại

### Xuất chậm hoặc bị gián đoạn

**Cách sửa:**
1. Kiểm tra kết nối Internet (Wi-Fi tốt hơn)
2. Không tắt ứng dụng trong khi xuất
3. Nếu vẫn lỗi, nhấn **Hủy** rồi thử lại

---

## ✅ Xong!

Đã hoàn tất setup. Bây giờ bạn có thể:

✅ Xuất ảnh trực tiếp lên Google Drive (mới)
✅ Ảnh tự động sắp xếp theo danh mục lỗi (mới)
✅ Không cần Google Apps Script (đơn giản!)
✅ Có thể đổi tài khoản khi cần

**Bắt đầu sử dụng ngay!** 🎉
