# cabinet_checker

## Đồng bộ lên Google Sheets (Phương án 1)

App đã hỗ trợ tùy chọn xuất `Đẩy lên Google Sheets` trong hộp thoại xuất báo cáo.
Luồng này gửi từng bản ghi lên Google Apps Script, bao gồm ảnh gốc dạng base64 để Script lưu vào Google Drive và ghi link vào Google Sheet.

### 1) Tạo Google Apps Script

1. Tạo một Google Sheet mới.
2. Vào `Extensions` -> `Apps Script`.
3. Dán toàn bộ script dưới đây vào file `Code.gs`.
4. Script này đang dùng chung cố định file Google Sheet đã chốt trong biến `SPREADSHEET_ID`.

```javascript
const SPREADSHEET_ID = '1QTIKhT5CYQQb2PFSvjP9XE2RcxtunHCylBgA9B5YcaQ';
const DRIVE_FOLDER_NAME = 'cabinet_checker_uploads';

function doPost(e) {
	try {
		const payload = JSON.parse(e.postData.contents || '{}');
		if (payload.action !== 'appendCabinetRecord') {
			return json_({ ok: false, error: 'Unsupported action' }, 400);
		}

		const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
		const exportSessionId = String(payload.exportSessionId || '').trim();
		const requestedSheetName = String(payload.sheetName || '').trim();
		if (!exportSessionId) {
			return json_({ ok: false, error: 'Missing exportSessionId' }, 400);
		}
		if (!requestedSheetName) {
			return json_({ ok: false, error: 'Missing sheetName' }, 400);
		}

		const record = payload.record || {};
		const photos = Array.isArray(payload.photos) ? payload.photos : [];

		const lock = LockService.getScriptLock();
		lock.waitLock(30000);
		let sheet;
		try {
			sheet = getOrCreateSheetForExport_(ss, requestedSheetName, exportSessionId);
			ensureHeader_(sheet);
		} finally {
			lock.releaseLock();
		}

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
			normalizeInspectionStatus_(record.inspectionStatus),
			normalizeYesNo_(record.wrongPosition),
			normalizeYesNo_(record.hangingCable),
			normalizeYesNo_(record.unfixedCable),
			record.otherIssueType || '',
			normalizePassStatus_(record.isPassed),
			normalizeSeverityLabel_(record.severity),
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
		formatSheetLayout_(sheet, 22);
		return json_({ ok: true, photosUploaded: photoLinks.length, sheetName: sheet.getName() }, 200);
	} catch (err) {
		return json_({ ok: false, error: String(err) }, 500);
	}
}

function getOrCreateSheetForExport_(ss, requestedName, exportSessionId) {
	const props = PropertiesService.getScriptProperties();
	const sessionKey = 'EXPORT_SESSION_' + exportSessionId;
	const mappedSheetId = props.getProperty(sessionKey);

	if (mappedSheetId) {
		const mapped = ss
			.getSheets()
			.find((s) => String(s.getSheetId()) === String(mappedSheetId));
		if (mapped) return mapped;
	}

	const baseName = sanitizeSheetName_(requestedName);
	const uniqueName = makeUniqueSheetName_(ss, baseName);
	const created = ss.insertSheet(uniqueName);
	props.setProperty(sessionKey, String(created.getSheetId()));
	return created;
}

function ensureHeader_(sheet) {
	if (sheet.getLastRow() > 0) return;
	const headers = [
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
	];

	sheet.appendRow(headers);
	const headerRange = sheet.getRange(1, 1, 1, headers.length);
	headerRange.setFontWeight('bold');
	headerRange.setHorizontalAlignment('center');
	headerRange.setVerticalAlignment('middle');

	formatSheetLayout_(sheet, headers.length);
}

function formatSheetLayout_(sheet, columnCount) {
	const lastRow = sheet.getLastRow();
	if (lastRow <= 0) return;

	// ===== Toàn bộ bảng =====
	const fullRange = sheet.getRange(1, 1, lastRow, columnCount);

	fullRange.setBorder(true, true, true, true, true, true);
	fullRange.setVerticalAlignment('middle');
	fullRange.setWrap(true); // tự xuống dòng

	// ===== Header =====
	const headerRange = sheet.getRange(1, 1, 1, columnCount);

	headerRange
		.setFontWeight('bold')
		.setBackground('#d9ead3') // xanh nhạt
		.setHorizontalAlignment('center')
		.setVerticalAlignment('middle');

	sheet.setRowHeight(1, 42);

	// ===== Freeze header =====
	sheet.setFrozenRows(1);

	// ===== Auto resize toàn bộ cột =====
	sheet.autoResizeColumns(1, columnCount);

	// ===== Set width cố định các cột quan trọng =====

	// Ngày tạo
	sheet.setColumnWidth(1, 140);

	// Mã tủ
	sheet.setColumnWidth(2, 120);

	// Tên tủ
	sheet.setColumnWidth(3, 180);

	// Tuyến
	sheet.setColumnWidth(4, 150);

	// Lat/Lng
	sheet.setColumnWidth(5, 130);
	sheet.setColumnWidth(6, 130);
	sheet.setColumnWidth(7, 130);
	sheet.setColumnWidth(8, 130);

	// Sai số + khoảng cách
	sheet.setColumnWidth(9, 130);
	sheet.setColumnWidth(10, 150);

	// Trạng thái
	sheet.setColumnWidth(11, 140);

	// Các lỗi (Co/Khong)
	sheet.setColumnWidth(12, 120);
	sheet.setColumnWidth(13, 120);
	sheet.setColumnWidth(14, 120);

	// Lỗi khác
	sheet.setColumnWidth(15, 160);

	// Đạt / Không đạt
	sheet.setColumnWidth(16, 140);

	// Mức độ
	sheet.setColumnWidth(17, 120);

	// Thời gian kiểm tra
	sheet.setColumnWidth(18, 170);

	// Người kiểm tra
	sheet.setColumnWidth(19, 160);

	// Ghi chú (quan trọng)
	sheet.setColumnWidth(20, 260);

	// Số ảnh
	sheet.setColumnWidth(21, 90);

	// Link ảnh (quan trọng nhất)
	const linkColumnIndex = 22;

	if (columnCount >= linkColumnIndex) {
		sheet.setColumnWidth(linkColumnIndex, 340);
	}

	// ===== Set chiều cao dòng dữ liệu =====
	if (lastRow > 1) {
		sheet.setRowHeights(2, lastRow - 1, 36);
	}

  // ===== Canh giữa các cột trạng thái =====
  if (lastRow > 1) {
    sheet.getRange(2, 11, lastRow - 1, 7)
      .setHorizontalAlignment('center');
  }


  // ===== Tô màu Đạt / Không đạt =====
  const statusRange = sheet.getRange(2, 16, Math.max(lastRow - 1, 1), 1);

  let rules = sheet.getConditionalFormatRules();

  // Tránh tạo rule trùng lặp
  if (rules.length === 0) {

    const passRule =
      SpreadsheetApp.newConditionalFormatRule()
				.whenTextEqualTo('Đạt')
        .setBackground('#d9ead3') // xanh nhạt
        .setRanges([statusRange])
        .build();

    const failRule =
      SpreadsheetApp.newConditionalFormatRule()
				.whenTextEqualTo('Không đạt')
        .setBackground('#f4cccc') // đỏ nhạt
        .setRanges([statusRange])
        .build();

    rules.push(passRule);
    rules.push(failRule);

    sheet.setConditionalFormatRules(rules);
  }
}

function sanitizeSheetName_(name) {
	const cleaned = String(name || '')
		.replace(/[\\\\\/\?\*\[\]:]/g, ' ')
		.replace(/\s+/g, ' ')
		.trim();
	if (!cleaned) {
		const now = new Date();
		return (
			'BaoCao_' +
			now.getFullYear() +
			('0' + (now.getMonth() + 1)).slice(-2) +
			('0' + now.getDate()).slice(-2) +
			'_' +
			('0' + now.getHours()).slice(-2) +
			('0' + now.getMinutes()).slice(-2)
		).slice(0, 100);
	}
	return cleaned.slice(0, 100);
}

function makeUniqueSheetName_(ss, baseName) {
	let candidate = baseName;
	let index = 2;
	while (ss.getSheetByName(candidate)) {
		const suffix = '_' + index;
		candidate = baseName.slice(0, 100 - suffix.length) + suffix;
		index += 1;
	}
	return candidate;
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

function normalizeYesNo_(value) {
	if (value === true) return 'Có';
	if (value === false) return 'Không';
	const normalized = String(value || '').trim().toLowerCase();
	if (!normalized) return 'Không';
	if (normalized === 'true' || normalized === '1' || normalized === 'co' || normalized === 'có' || normalized === 'yes') {
		return 'Có';
	}
	if (normalized === 'false' || normalized === '0' || normalized === 'khong' || normalized === 'không' || normalized === 'no') {
		return 'Không';
	}
	return normalized.includes('có') || normalized.includes('co') ? 'Có' : 'Không';
}

function normalizePassStatus_(value) {
	if (value === true) return 'Đạt';
	if (value === false) return 'Không đạt';
	const normalized = String(value || '').trim().toLowerCase();
	if (!normalized) return 'Không đạt';
	if (normalized === 'đạt' || normalized === 'dat' || normalized === 'true' || normalized === '1' || normalized === 'yes') {
		return 'Đạt';
	}
	if (normalized === 'không đạt' || normalized === 'khong dat' || normalized === 'false' || normalized === '0' || normalized === 'no') {
		return 'Không đạt';
	}
	return normalized.includes('đạt') || normalized.includes('dat') ? 'Đạt' : 'Không đạt';
}

function normalizeSeverityLabel_(value) {
	const normalized = String(value || '').trim();
	if (!normalized) return 'Bình thường';
	const lower = normalized.toLowerCase();
	if (lower === 'none' || lower === 'bình thường' || lower === 'binh thuong') return 'Bình thường';
	if (lower === 'low' || lower === 'thấp' || lower === 'thap') return 'Thấp';
	if (lower === 'medium' || lower === 'trung bình' || lower === 'trung binh') return 'Trung bình';
	if (lower === 'high' || lower === 'cao') return 'Cao';
	return normalized;
}

function normalizeInspectionStatus_(value) {
	const normalized = String(value || '').trim();
	if (!normalized) return 'Chưa kiểm';
	const lower = normalized.toLowerCase();
	if (lower === 'notchecked' || lower === 'not checked' || lower === 'chưa kiểm' || lower === 'chua kiem') return 'Chưa kiểm';
	if (lower === 'checked' || lower === 'đã kiểm' || lower === 'da kiem') return 'Đã kiểm';
	if (lower === 'recheckneeded' || lower === 'recheck needed' || lower === 'cần kiểm lại' || lower === 'can kiem lai') return 'Cần kiểm lại';
	return normalized;
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
4. Nhập `Tên trang tính cho lần xuất này` (app sẽ tự tạo tab mới trong cùng file Sheet).
5. Chọn bộ lọc và xuất.

Nếu cần bảo mật chặt hơn hoặc dữ liệu lớn, chuyển sang phương án 2 (backend riêng + service account + queue/retry).
