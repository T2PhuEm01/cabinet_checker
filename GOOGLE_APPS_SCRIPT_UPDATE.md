# Google Apps Script Update - Export Photos by Issue Category

## Overview
You need to add a new handler function to your Google Apps Script to support organizing photos by issue category on Google Drive.

## Replace your Apps Script code with the following:

```javascript
// Configuration
const SPREADSHEET_ID = 'YOUR_SPREADSHEET_ID_HERE'; // Replace with your Google Sheet ID
const DRIVE_FOLDER_NAME = 'cabinet_checker_uploads';

/**
 * Main doPost handler - routes actions to appropriate handlers
 */
function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents);
    const action = String(payload.action || '').trim();

    if (!action) {
      return respond({ ok: false, error: 'Missing action' }, 400);
    }

    if (action === 'appendCabinetRecord') {
      return handleAppendCabinetRecord(payload);
    } else if (action === 'exportPhotosByIssueCategory') {
      return handleExportPhotosByIssueCategory(payload);
    } else {
      return respond({ ok: false, error: 'Unknown action: ' + action }, 400);
    }
  } catch (error) {
    return respond({ ok: false, error: error.toString() }, 500);
  }
}

/**
 * Handle regular cabinet record export to Google Sheets
 */
function handleAppendCabinetRecord(payload) {
  const exportSessionId = String(payload.exportSessionId || '').trim();
  if (!exportSessionId) {
    return respond({ ok: false, error: 'Missing exportSessionId' }, 400);
  }

  const sheetName = String(payload.sheetName || '').trim();
  if (!sheetName) {
    return respond({ ok: false, error: 'Missing sheetName' }, 400);
  }

  try {
    const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
    const sheet = getOrCreateSheetForExport_(ss, sheetName, exportSessionId);
    const folder = getOrCreateFolder_(DRIVE_FOLDER_NAME);
    const record = payload.record || {};
    const photos = payload.photos || [];

    // Save photos to Google Drive
    const photoLinks = [];
    for (let i = 0; i < photos.length; i++) {
      const photo = photos[i];
      const file = savePhotoToFolder_(folder, photo);
      if (file) {
        file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
        photoLinks.push(file.getUrl());
      }
    }

    // Append record to sheet
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
    return respond({ ok: true, message: 'Record saved successfully' }, 200);
  } catch (error) {
    return respond({ ok: false, error: error.toString() }, 500);
  }
}

/**
 * Handle export photos by issue category to Google Drive
 */
function handleExportPhotosByIssueCategory(payload) {
  try {
    const exportDate = String(payload.exportDate || '').trim();
    if (!exportDate) {
      return respond({ ok: false, error: 'Missing exportDate' }, 400);
    }

    const categoryPhotoData = payload.categoryPhotoData || {};
    if (Object.keys(categoryPhotoData).length === 0) {
      return respond({ ok: false, error: 'No cabinet photo data provided' }, 400);
    }

    // Create or get main folder for today's date
    const mainFolder = getOrCreateFolder_(DRIVE_FOLDER_NAME);
    const dateFolder = getOrCreateSubFolder_(mainFolder, exportDate);

    // Categories to process
    const categories = [
      'vỏ tủ không đạt',
      'nhãn không đạt',
      'cáp nhập tủ không đạt',
      'tủ sai vị trí',
      'Lắp đặt không chắc chắn/Nguy cơ rơi đổ (TLĐKCC/NCRĐ)',
    ];

    let totalPhotosProcessed = 0;

    // Process each category
    for (const category of categories) {
      const photos = categoryPhotoData[category] || [];
      if (photos.length === 0) continue;

      // Create category folder
      const categoryFolder = getOrCreateSubFolder_(dateFolder, category);

      // Save all photos for this category
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
            'Error saving photo ' +
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
        message: `Successfully exported ${totalPhotosProcessed} photos to Google Drive in ${Object.keys(categoryPhotoData).length} categories`,
      },
      200
    );
  } catch (error) {
    return respond({ ok: false, error: error.toString() }, 500);
  }
}

/**
 * Utility: Create folder if not exists
 */
function getOrCreateFolder_(name) {
  const it = DriveApp.getFoldersByName(name);
  if (it.hasNext()) {
    return it.next();
  }
  return DriveApp.createFolder(name);
}

/**
 * Utility: Create subfolder if not exists
 */
function getOrCreateSubFolder_(parentFolder, folderName) {
  const it = parentFolder.getFoldersByName(folderName);
  if (it.hasNext()) {
    return it.next();
  }
  return parentFolder.createFolder(folderName);
}

/**
 * Utility: Save photo from base64 to folder
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
    console.log('Error saving photo: ' + error.toString());
    return null;
  }
}

/**
 * Utility: Get or create sheet for export session
 */
function getOrCreateSheetForExport_(ss, requestedName, exportSessionId) {
  const sessionKey = 'EXPORT_SESSION_' + exportSessionId;
  const allSheets = ss.getSheets();

  // Look for sheet with exact name
  for (const sheet of allSheets) {
    if (sheet.getName() === requestedName) {
      return sheet;
    }
  }

  // Create new sheet if it doesn't exist
  return ss.insertSheet(requestedName);
}

/**
 * Utility: Send JSON response
 */
function respond(data, statusCode) {
  return ContentService.createTextOutput(JSON.stringify(data)).setMimeType(
    ContentService.MimeType.JSON
  );
}
```

## Steps to Update Your Apps Script:

1. **Open your Google Apps Script**:
   - Go to your Google Sheet
   - Click **Extensions** → **Apps Script**
   - Replace all code in `Code.gs` with the code above

2. **Update the Configuration**:
   - Replace `'YOUR_SPREADSHEET_ID_HERE'` with your actual Google Sheet ID
   - You can find it in the URL: `https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit`

3. **Deploy the Web App** (if not already done):
   - Click **Deploy** → **New Deployment**
   - Select **Type**: "Web app"
   - Execute as: Your email
   - Who has access: "Anyone"
   - Deploy and copy the URL

4. **Use the URL in Cabinet Checker**:
   - In the app, when exporting to Google Sheets, use this deployed URL
   - The same URL will now support both regular export and export-by-issue-category

## How It Works:

✅ When you click the **Photo Gallery** icon in the toolbar:
- The app collects all cabinets with issues
- Organizes photos by issue category
- Sends them to Google Drive via Google Apps Script
- Creates this folder structure on Google Drive:

```
cabinet_checker_uploads/
└── {today's_date}/
    ├── vỏ tủ không đạt/
    │   ├── TNH0024_1.jpg
    │   └── TNH0031_1.jpg
    ├── nhãn không đạt/
    │   └── TNH0025_1.jpg
    ├── cáp nhập tủ không đạt/
    │   └── TNH0026_1.jpg
    ├── tủ sai vị trí/
    │   └── TNH0027_1.jpg
    └── Lắp đặt không chắc chắn/Nguy cơ rơi đổ (TLĐKCC/NCRĐ)/
        └── TNH0028_1.jpg
```

## Features:

- ✅ Creates date-based folders automatically
- ✅ Creates category subfolders only if photos exist
- ✅ Shares photos with link (view-only access)
- ✅ Shows progress during upload
- ✅ Can cancel mid-export
- ✅ Handles errors gracefully
- ✅ Works alongside existing Google Sheets export

## Notes:

- The app requires the Google Apps Script URL to be configured
- If URL is not set, you'll see a message to configure it first
- Make sure all photos have proper permissions on Google Drive
- Category names must match Vietnamese text exactly as shown above
