# cabinet_checker

## Đồng bộ lên Google Sheets (Phương án 1)

App đã hỗ trợ tùy chọn xuất `Đẩy lên Google Sheets` trong hộp thoại xuất báo cáo.
Luồng này gửi từng bản ghi lên Google Apps Script, bao gồm ảnh gốc dạng base64 để Script lưu vào Google Drive và ghi link vào Google Sheet.

### 1) Tạo Google Apps Script

1. Tạo một Google Sheet mới.
2. Vào `Extensions` -> `Apps Script`.
3. Dán toàn bộ script dưới đây vào file `Code.gs`.
4. Sửa `SPREADSHEET_ID` theo ID sheet của bạn.

```javascript
const SPREADSHEET_ID = '1zh2omuE3zE_F-ka_BucCZRhi7ByLOUe70ruECdZULUE';
const SHEET_NAME = 'Cabinets';
const DRIVE_FOLDER_NAME = 'cabinet_checker_uploads';

function doPost(e) {
	try {
		const payload = JSON.parse(e.postData.contents || '{}');
		if (payload.action !== 'appendCabinetRecord') {
			return json_({ ok: false, error: 'Unsupported action' }, 400);
		}

		const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
		const sheet = getOrCreateSheet_(ss, SHEET_NAME);
		ensureHeader_(sheet);

		const record = payload.record || {};
		const photos = Array.isArray(payload.photos) ? payload.photos : [];

		const folder = getOrCreateFolder_(DRIVE_FOLDER_NAME);
		const photoLinks = [];

		photos.forEach((p) => {
			const name = p.name || ('photo_' + Date.now() + '.jpg');
			const mimeType = p.mimeType || 'application/octet-stream';
			const base64 = p.base64 || '';
			if (!base64) return;

			const bytes = Utilities.base64Decode(base64);
			const blob = Utilities.newBlob(bytes, mimeType, name);
			const file = folder.createFile(blob);
			file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
			photoLinks.push(file.getUrl());
		});

		const row = [
			new Date(),
			record.id || '',
			record.name || '',
			record.route || '',
			record.latitudeRef ?? '',
			record.longitudeRef ?? '',
			record.latitudeActual ?? '',
			record.longitudeActual ?? '',
			record.coordinateDeviationMeters ?? '',
			record.distanceToUserMeters ?? '',
			record.inspectionStatus || '',
			record.wrongPosition ? 'Co' : 'Khong',
			record.hangingCable ? 'Co' : 'Khong',
			record.unfixedCable ? 'Co' : 'Khong',
			record.otherIssueType || '',
			record.isPassed ? 'Dat' : 'Khong dat',
			record.severity || '',
			record.lastCheckedAt || '',
			record.inspectorName || '',
			record.notes || '',
			photoLinks.length,
			'',
		];

		sheet.appendRow(row);
		const appendedRow = sheet.getLastRow();
		sheet.getRange(appendedRow, 1, 1, 22).setVerticalAlignment('middle');
		sheet.getRange(appendedRow, 22).setRichTextValue(buildPhotoLinksRichText_(photoLinks));
		sheet.setRowHeight(appendedRow, 36);
		return json_({ ok: true, photosUploaded: photoLinks.length }, 200);
	} catch (err) {
		return json_({ ok: false, error: String(err) }, 500);
	}
}

function getOrCreateSheet_(ss, name) {
	const found = ss.getSheetByName(name);
	if (found) return found;
	return ss.insertSheet(name);
}

function ensureHeader_(sheet) {
	if (sheet.getLastRow() > 0) return;
	sheet.appendRow([
		'Ngày tạo',
		'Mã tủ',
		'Tên tủ',
		'Tuyến',
		'Lat chuẩn',
		'Lng chuẩn',
		'Lat thực tế',
		'Lng thực tế',
		'Sai số (m)',
		'Khoảng cách tới bạn (m)',
		'Trạng thái',
		'Lỗi vị trí',
		'Lỗi treo lơ lửng',
		'Lỗi cố định cáp',
		'Lỗi khác',
		'Đạt/Không đạt',
		'Mức độ',
		'Thời gian kiểm tra',
		'Người kiểm tra',
		'Ghi chú',
		'Số ảnh',
		'Link ảnh',
	]);
		sheet.setColumnWidth(22, 320);
}

function getOrCreateFolder_(name) {
	const it = DriveApp.getFoldersByName(name);
	if (it.hasNext()) return it.next();
	return DriveApp.createFolder(name);
}

function buildPhotoLinksRichText_(links) {
	if (!links || links.length === 0) {
		return SpreadsheetApp.newRichTextValue().setText('').build();
	}

	const labels = links.map((_, i) => 'Ảnh ' + (i + 1));
	const text = labels.join(' | ');
	const builder = SpreadsheetApp.newRichTextValue().setText(text);

	let cursor = 0;
	for (let i = 0; i < links.length; i++) {
		const label = labels[i];
		builder.setLinkUrl(cursor, cursor + label.length, links[i]);
		cursor += label.length;
		if (i < links.length - 1) {
			cursor += 3;
		}
	}

	return builder.build();
}

function json_(obj, status) {
	return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
```

### 2) Deploy Web App

1. Nhấn `Deploy` -> `New deployment`.
2. Chọn loại `Web app`.
3. `Execute as`: `Me`.
4. `Who has access`: chọn mức phù hợp, khuyến nghị `Anyone` để app mobile gọi được.
5. Bấm `Deploy`, copy URL kết thúc bằng `/exec`.

### 3) Dùng trong app

1. Bấm `Xuất báo cáo`.
2. Chọn `Nơi xuất dữ liệu` = `Đẩy lên Google Sheets`.
3. Dán URL Apps Script `/exec`.
4. Chọn bộ lọc và xuất.

Nếu cần bảo mật chặt hơn hoặc dữ liệu lớn, chuyển sang phương án 2 (backend riêng + service account + queue/retry).
