# Hướng Dẫn Xuất Ảnh Theo Danh Mục Lỗi Lên Google Drive

## 📱 Phần Ứng Dụng (Đã Xong)

Ứng dụng đã có tính năng xuất ảnh theo danh mục lỗi. Khi bạn nhấn nút **Thư viện ảnh** (icon những ảnh) ở thanh công cụ, ứng dụng sẽ:

1. Tự động tìm tất cả tủ có vấn đề
2. Sắp xếp ảnh theo danh mục lỗi:
   - **vỏ tủ không đạt** (vỏ hỏng)
   - **nhãn không đạt** (không có nhãn)
   - **cáp nhập tủ không đạt** (dây cáp chưa cố định)
   - **tủ sai vị trí** (tủ ở vị trí sai)
   - **Lắp đặt không chắc chắn/Nguy cơ rơi đổ (TLĐKCC/NCRĐ)** (tủ treo lơ lửng)
3. Tải lên Google Drive tự động

---

## 🔧 Phần Google Apps Script (Cần Cập Nhật)

### Bước 1: Mở Google Apps Script

1. Đăng nhập vào Google Drive của bạn
2. Tìm đến **Google Sheet** mà bạn đang dùng với ứng dụng
3. Nhấn vào **Extensions** (Tiện ích mở rộng) → **Apps Script**

![Hình ảnh: Quá trình mở Apps Script]

### Bước 2: Xóa Code Cũ

1. Trang Apps Script sẽ mở lên
2. Bạn sẽ thấy file `Code.gs` ở bên trái
3. **Bôi đen tất cả mã code hiện tại** (Ctrl+A)
4. **Xóa sạch** (Delete)

### Bước 3: Sao Chép Code Mới

Sao chép **toàn bộ code dưới đây** và dán vào `Code.gs`:

```javascript
// ===== CẤU HÌNH =====
const SPREADSHEET_ID = 'YOUR_SPREADSHEET_ID_HERE'; // THAY BẰNG ID CỦA GOOGLE SHEET CỦA BẠN
const DRIVE_FOLDER_NAME = 'cabinet_checker_uploads';

/**
 * Hàm chính - xử lý tất cả yêu cầu từ ứng dụng
 */
function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents);
    const action = String(payload.action || '').trim();

    if (!action) {
      return respond({ ok: false, error: 'Thiếu action' }, 400);
    }

    if (action === 'appendCabinetRecord') {
      return handleAppendCabinetRecord(payload);
    } else if (action === 'exportPhotosByIssueCategory') {
      return handleExportPhotosByIssueCategory(payload);
    } else {
      return respond({ ok: false, error: 'Action không hợp lệ: ' + action }, 400);
    }
  } catch (error) {
    return respond({ ok: false, error: error.toString() }, 500);
  }
}

/**
 * Xử lý xuất dữ liệu tủ thông thường lên Google Sheets
 */
function handleAppendCabinetRecord(payload) {
  const exportSessionId = String(payload.exportSessionId || '').trim();
  if (!exportSessionId) {
    return respond({ ok: false, error: 'Thiếu exportSessionId' }, 400);
  }

  const sheetName = String(payload.sheetName || '').trim();
  if (!sheetName) {
    return respond({ ok: false, error: 'Thiếu tên trang tính' }, 400);
  }

  try {
    const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
    const sheet = getOrCreateSheetForExport_(ss, sheetName, exportSessionId);
    const folder = getOrCreateFolder_(DRIVE_FOLDER_NAME);
    const record = payload.record || {};
    const photos = payload.photos || [];

    // Lưu các ảnh vào Google Drive
    const photoLinks = [];
    for (let i = 0; i < photos.length; i++) {
      const photo = photos[i];
      const file = savePhotoToFolder_(folder, photo);
      if (file) {
        file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
        photoLinks.push(file.getUrl());
      }
    }

    // Thêm dòng dữ liệu vào trang tính
    const newRow = [
      record.id || '',
      record.name || '',
      record.route || '',
      record.latitudeRef || '',
      record.longitudeRef || '',
      record.latitudeActual || '',
      record.longitudeActual || '',
      record.distanceToUserMeters || '',
      record.coordinateDeviationMeters || '',
      record.inspectionStatus || '',
      record.wrongPosition || '',
      record.hangingCable || '',
      record.unfixedCable || '',
      record.shellPassed || '',
      record.hasLabel || '',
      record.saggingPassed || '',
      record.cleanedPassed || '',
      record.subscriberCableNotSagging || '',
      record.needsProcessing || '',
      record.otherIssue || '',
      record.otherIssueType || '',
      record.isPassed || '',
      record.severity || '',
      record.notes || '',
      record.inspectorName || '',
      record.lastCheckedAt || '',
      photoLinks.join(' | ') || '',
    ];

    sheet.appendRow(newRow);
    return respond({ ok: true, message: 'Lưu dữ liệu thành công' }, 200);
  } catch (error) {
    return respond({ ok: false, error: error.toString() }, 500);
  }
}

/**
 * Xử lý xuất ảnh theo danh mục lỗi lên Google Drive
 * Đây là hàm MỚI dành cho tính năng này
 */
function handleExportPhotosByIssueCategory(payload) {
  try {
    const exportDate = String(payload.exportDate || '').trim();
    if (!exportDate) {
      return respond({ ok: false, error: 'Thiếu ngày xuất' }, 400);
    }

    const categoryPhotoData = payload.categoryPhotoData || {};
    if (Object.keys(categoryPhotoData).length === 0) {
      return respond({ ok: false, error: 'Không có dữ liệu ảnh tủ' }, 400);
    }

    // Tạo folder chính theo ngày hôm nay
    const mainFolder = getOrCreateFolder_(DRIVE_FOLDER_NAME);
    const dateFolder = getOrCreateSubFolder_(mainFolder, exportDate);

    // Các danh mục lỗi
    const categories = [
      'vỏ tủ không đạt',
      'nhãn không đạt',
      'cáp nhập tủ không đạt',
      'tủ sai vị trí',
      'Lắp đặt không chắc chắn/Nguy cơ rơi đổ (TLĐKCC/NCRĐ)',
    ];

    let totalPhotosProcessed = 0;

    // Xử lý từng danh mục
    for (const category of categories) {
      const photos = categoryPhotoData[category] || [];
      if (photos.length === 0) continue;

      // Tạo folder cho danh mục
      const categoryFolder = getOrCreateSubFolder_(dateFolder, category);

      // Lưu tất cả ảnh của danh mục này
      for (let i = 0; i < photos.length; i++) {
        const photo = photos[i];
        try {
          const file = savePhotoToFolder_(categoryFolder, photo);
          if (file) {
            file.setSharing(
              DriveApp.Access.ANYONE_WITH_LINK,
              DriveApp.Permission.VIEW
            );
            totalPhotosProcessed++;
          }
        } catch (photoError) {
          console.log(
            'Lỗi lưu ảnh ' +
              photo.name +
              ': ' +
              photoError.toString()
          );
        }
      }
    }

    return respond(
      {
        ok: true,
        message: `Xuất thành công ${totalPhotosProcessed} ảnh lên Google Drive trong ${Object.keys(categoryPhotoData).length} danh mục`,
      },
      200
    );
  } catch (error) {
    return respond({ ok: false, error: error.toString() }, 500);
  }
}

/**
 * Tiện ích: Tạo folder nếu chưa exists
 */
function getOrCreateFolder_(name) {
  const it = DriveApp.getFoldersByName(name);
  if (it.hasNext()) {
    return it.next();
  }
  return DriveApp.createFolder(name);
}

/**
 * Tiện ích: Tạo subfolder nếu chưa exists
 */
function getOrCreateSubFolder_(parentFolder, folderName) {
  const it = parentFolder.getFoldersByName(folderName);
  if (it.hasNext()) {
    return it.next();
  }
  return parentFolder.createFolder(folderName);
}

/**
 * Tiện ích: Lưu ảnh từ base64 vào folder
 */
function savePhotoToFolder_(folder, photoData) {
  try {
    const fileName = String(photoData.name || 'photo');
    const mimeType = String(photoData.mimeType || 'image/jpeg');
    const base64Data = String(photoData.base64 || '');

    if (!base64Data) {
      return null;
    }

    const blob = Utilities.newBlob(
      Utilities.base64Decode(base64Data),
      mimeType,
      fileName
    );
    return folder.createFile(blob);
  } catch (error) {
    console.log('Lỗi lưu ảnh: ' + error.toString());
    return null;
  }
}

/**
 * Tiện ích: Lấy hoặc tạo trang tính cho phiên xuất
 */
function getOrCreateSheetForExport_(ss, requestedName, exportSessionId) {
  const sessionKey = 'EXPORT_SESSION_' + exportSessionId;
  const allSheets = ss.getSheets();

  // Tìm trang tính có tên chính xác
  for (const sheet of allSheets) {
    if (sheet.getName() === requestedName) {
      return sheet;
    }
  }

  // Tạo trang tính mới nếu chưa tồn tại
  return ss.insertSheet(requestedName);
}

/**
 * Tiện ích: Gửi phản hồi JSON
 */
function respond(data, statusCode) {
  return ContentService.createTextOutput(JSON.stringify(data)).setMimeType(
    ContentService.MimeType.JSON
  );
}
```

### Bước 4: Cập Nhật Spreadsheet ID

**Quan trọng:** Bạn phải thay `YOUR_SPREADSHEET_ID_HERE` bằng ID thực của Google Sheet của mình.

**Cách lấy Spreadsheet ID:**

1. Mở Google Sheet của bạn
2. Nhìn vào URL của Sheet, ví dụ:
   ```
   https://docs.google.com/spreadsheets/d/1GhIj5nKxYzAbW9vQp7rTfZsX1A2B3C4D5E6F7G8H9I/edit
   ```
3. Phần **in đậm** là ID:
   ```
   1GhIj5nKxYzAbW9vQp7rTfZsX1A2B3C4D5E6F7G8H9I
   ```
4. Sao chép ID đó và **dán vào dòng 2** của code:
   ```javascript
   const SPREADSHEET_ID = '1GhIj5nKxYzAbW9vQp7rTfZsX1A2B3C4D5E6F7G8H9I';
   ```

### Bước 5: Lưu Code

1. Nhấn **Ctrl+S** hoặc nhấn nút **Lưu** (💾)
2. Hệ thống sẽ yêu cầu cấp quyền, hãy **Cho phép** (Allow)

### Bước 6: Deploy Web App

1. Nhấn nút **Deploy** ở góc trên cùng
2. Chọn **New Deployment** (Bản triển khai mới)
3. Chọn loại: **Type** → **Web app**
4. Điền thông tin:
   - **Execute as:** Chọn tài khoản Google của bạn
   - **Who has access:** Chọn "Anyone"
5. Nhấn **Deploy**

### Bước 7: Sao Chép URL Deployment

1. Khi deploy xong, hệ thống sẽ hiển thị một popup
2. **Sao chép URL** được cung cấp (nó bắt đầu bằng `https://script.google.com/macros/s/...`)
3. **Lưu lại URL này** để sử dụng trong ứng dụng

---

## 📱 Sử Dụng Ứng Dụng

### Lần Đầu Đầu Tiên:

1. Mở ứng dụng Cabinet Checker
2. Nhấn nút **Tải file về máy** (icon mũi tên xuống) → **Đẩy lên Google Sheets**
3. Dán URL Apps Script từ Bước 7 vào ô "Apps Script URL"
4. Nhập tên trang tính Google Sheet (ví dụ: "Kiểm Tra Tủ 2026")
5. Nhấn **Xuất** → Chờ cho đến khi hoàn tất

### Lần Tiếp Theo:

Khi bạn muốn xuất ảnh theo danh mục lỗi:

1. Kiểm tra lại dữ liệu đã kiểm tra
2. Nhấn nút **Thư viện ảnh** (icon những ảnh) ở thanh công cụ
3. Ứng dụng sẽ:
   - Tự động tìm tất cả tủ có vấn đề
   - Sắp xếp ảnh theo danh mục lỗi
   - Tải lên Google Drive
4. Chờ cho đến khi thấy thông báo "Xuất thành công!"

---

## 📂 Cấu Trúc Thư Mục Trên Google Drive

Sau khi xuất, Google Drive sẽ tạo ra cấu trúc thư mục như sau:

```
Google Drive (của bạn)
└── cabinet_checker_uploads/
    └── 2026-05-14/
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

## ⚠️ Các Vấn Đề Thường Gặp

### Lỗi: "Không kết nối được Google Apps Script"

**Nguyên nhân:** URL không đúng hoặc chưa deploy

**Cách sửa:**
1. Kiểm tra lại URL được deploy (Bước 7)
2. Đảm bảo URL bắt đầu bằng `https://script.google.com/macros/s/`
3. Đảm bảo URL kết thúc bằng `/exec`

### Lỗi: "Thiếu URL Google Apps Script"

**Nguyên nhân:** Chưa cấu hình Apps Script trong ứng dụng

**Cách sửa:**
1. Nhấn nút **Tải file về máy** → **Đẩy lên Google Sheets**
2. Nhập URL Apps Script vào ô "Apps Script URL"
3. Nhấn **Xuất** một lần để lưu URL

### Không thấy ảnh trên Google Drive

**Nguyên nhân:** Có thể là:
- Chưa có tủ nào có vấn đề
- Tủ có vấn đề nhưng không có ảnh

**Cách sửa:**
1. Kiểm tra lại các bản ghi - có tủ nào có dấu ✓ ở mục lỗi không?
2. Có ảnh minh chứng không?
3. Nếu có vấn đề, hãy xóa ứng dụng khỏi đệm (Clear Cache) và thử lại

---

## ✅ Thành công! 

Đã hoàn tất setup. Bây giờ bạn có thể:
- ✅ Xuất dữ liệu lên Google Sheets (như trước)
- ✅ **Xuất ảnh theo danh mục lỗi lên Google Drive** (tính năng MỚI)
- ✅ Tất cả ảnh tự động được tổ chức vào các folder theo ngày và loại lỗi

**Hãy bắt đầu sử dụng tính năng mới ngay!**
