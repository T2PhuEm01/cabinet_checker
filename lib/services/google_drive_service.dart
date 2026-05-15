import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/cabinet_record.dart';
import 'export_cancel_token.dart';

class GoogleDriveProgress {
  const GoogleDriveProgress({required this.value, required this.message});

  final double value;
  final String message;
}

typedef GoogleDriveProgressCallback =
    void Function(GoogleDriveProgress progress);

class GoogleDriveService {
  static const String _SCOPES = drive.DriveApi.driveScope;
  static const String _ROOT_FOLDER_NAME = 'Cabinet Checker';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: <String>[_SCOPES]);

  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;

  bool get isSignedIn => _currentUser != null;

  /// Đăng nhập Google
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser != null;
    } catch (error) {
      _currentUser = null;
      rethrow;
    }
  }

  /// Đăng xuất Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
    } catch (_) {
      _currentUser = null;
    }
  }

  /// Disconnect (xóa quyền truy cập)
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      _currentUser = null;
    } catch (_) {
      _currentUser = null;
    }
  }

  /// Upload ảnh theo danh mục lỗi lên Google Drive
  Future<void> exportPhotosByIssueToGoogleDrive({
    required List<CabinetRecord> records,
    DateTime? checkedDate,
    GoogleDriveProgressCallback? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCanceled();

    if (_currentUser == null) {
      throw StateError('Chưa đăng nhập Google. Vui lòng đăng nhập trước.');
    }

    onProgress?.call(
      const GoogleDriveProgress(
        value: 0.02,
        message: 'Đang kết nối Google Drive...',
      ),
    );

    try {
      final authHeaders = await _currentUser!.authHeaders;
      final driveApi = drive.DriveApi(
        _GoogleSignInHttpClient(_currentUser!, authHeaders),
      );

      // Issue categories
      final issueCategories = <String, bool Function(CabinetRecord)>{
        'Vỏ tủ không đạt': (r) => !r.shellPassed,
        'Nhãn không đạt': (r) => !r.hasLabel,
        'Cáp nhập tủ không đạt': (r) =>
            r.unfixedCable || !r.subscriberCableNotSagging,
        'Tủ sai vị trí': (r) => r.wrongPosition,
        'Lắp đặt không chắc chắn/Nguy cơ rơi đổ (TLĐKCC/NCRĐ)': (r) =>
            r.hangingCable,
      };

      // Apply optional checked date filter (match by date only)
      var filteredRecords = records;
      if (checkedDate != null) {
        final nd = DateTime(
          checkedDate.year,
          checkedDate.month,
          checkedDate.day,
        );
        filteredRecords = filteredRecords.where((r) {
          final checkedAt = r.lastCheckedAt;
          if (checkedAt == null) return false;
          return checkedAt.year == nd.year &&
              checkedAt.month == nd.month &&
              checkedAt.day == nd.day;
        }).toList();
      }

      // Group records by issue
      final recordsByCategory = <String, List<CabinetRecord>>{};
      for (final category in issueCategories.keys) {
        recordsByCategory[category] = <CabinetRecord>[];
      }

      for (final record in filteredRecords) {
        cancelToken?.throwIfCanceled();
        for (final entry in issueCategories.entries) {
          if (entry.value(record) && record.photos.isNotEmpty) {
            recordsByCategory[entry.key]!.add(record);
          }
        }
      }

      onProgress?.call(
        const GoogleDriveProgress(
          value: 0.05,
          message: 'Đang kiểm tra thư mục trên Google Drive...',
        ),
      );

      // Create/get root folder
      final rootFolder = await _getOrCreateRootFolder(driveApi);

      // Create date folder (use checkedDate if provided, otherwise today)
      final dateForFolder = checkedDate != null
          ? DateTime(checkedDate.year, checkedDate.month, checkedDate.day)
          : DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy').format(dateForFolder);
      final dateFolder = await _getOrCreateFolder(
        driveApi,
        dateStr,
        rootFolder.id!,
      );

      // Count total photos
      var totalPhotos = 0;
      for (final entry in recordsByCategory.entries) {
        for (final record in entry.value) {
          totalPhotos += record.photos.length;
        }
      }

      if (totalPhotos == 0) {
        onProgress?.call(
          const GoogleDriveProgress(
            value: 1.0,
            message: 'Không có ảnh để xuất.',
          ),
        );
        return;
      }

      // Upload photos by category
      var uploadedPhotos = 0;
      for (final entry in recordsByCategory.entries) {
        cancelToken?.throwIfCanceled();
        final categoryName = entry.key;
        final recordsInCategory = entry.value;

        if (recordsInCategory.isEmpty) continue;

        onProgress?.call(
          GoogleDriveProgress(
            value: 0.1 + ((uploadedPhotos / totalPhotos) * 0.2),
            message: 'Đang tạo thư mục: $categoryName',
          ),
        );

        // Create category folder
        final categoryFolder = await _getOrCreateFolder(
          driveApi,
          categoryName,
          dateFolder.id!,
        );

        // Upload photos for this category
        for (final record in recordsInCategory) {
          cancelToken?.throwIfCanceled();

          for (
            var photoIndex = 0;
            photoIndex < record.photos.length;
            photoIndex++
          ) {
            cancelToken?.throwIfCanceled();
            final photo = record.photos[photoIndex];
            final file = File(photo.path);

            if (!file.existsSync()) continue;

            final fileName = _buildPhotoFileName(
              cabinetCode: record.id,
              sourcePath: file.path,
              photoIndex: photoIndex,
              photoCount: record.photos.length,
            );

            onProgress?.call(
              GoogleDriveProgress(
                value: 0.3 + ((uploadedPhotos / totalPhotos) * 0.65),
                message:
                    'Đang tải: $categoryName\n$fileName ($uploadedPhotos/$totalPhotos)',
              ),
            );

            try {
              await _uploadFileToFolder(
                driveApi,
                file,
                fileName,
                categoryFolder.id!,
              );
              uploadedPhotos++;
            } catch (e) {
              // Log error but continue with next photo
              continue;
            }
          }
        }
      }

      onProgress?.call(
        const GoogleDriveProgress(
          value: 1.0,
          message: 'Hoàn tất! Tất cả ảnh đã được tải lên Google Drive.',
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Tạo/lấy folder gốc
  Future<drive.File> _getOrCreateRootFolder(drive.DriveApi driveApi) async {
    final query =
        "name='$_ROOT_FOLDER_NAME' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final fileList = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      pageSize: 1,
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first;
    }

    // Create new root folder
    final folder = drive.File(
      name: _ROOT_FOLDER_NAME,
      mimeType: 'application/vnd.google-apps.folder',
    );

    return await driveApi.files.create(folder);
  }

  /// Tạo/lấy subfolder
  Future<drive.File> _getOrCreateFolder(
    drive.DriveApi driveApi,
    String folderName,
    String parentId,
  ) async {
    final query =
        "name='$folderName' and mimeType='application/vnd.google-apps.folder' and '$parentId' in parents and trashed=false";
    final fileList = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      pageSize: 1,
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first;
    }

    // Create new folder
    final folder = drive.File(
      name: folderName,
      mimeType: 'application/vnd.google-apps.folder',
      parents: <String>[parentId],
    );

    return await driveApi.files.create(folder);
  }

  /// Upload ảnh lên folder
  Future<drive.File> _uploadFileToFolder(
    drive.DriveApi driveApi,
    File localFile,
    String fileName,
    String parentId,
  ) async {
    final fileMetadata = drive.File(
      name: fileName,
      parents: <String>[parentId],
    );

    final media = drive.Media(localFile.openRead(), localFile.lengthSync());

    return await driveApi.files.create(fileMetadata, uploadMedia: media);
  }

  /// Xây dựng tên file ảnh
  String _buildPhotoFileName({
    required String cabinetCode,
    required String sourcePath,
    required int photoIndex,
    required int photoCount,
  }) {
    final safeCabinetCode = cabinetCode.replaceAll(
      RegExp(r'[\\/:*?"<>|\s]+'),
      '_',
    );
    final extension = _extractFileExtension(sourcePath);
    if (photoCount <= 1) {
      return '$safeCabinetCode$extension';
    }
    return '${safeCabinetCode}_${photoIndex + 1}$extension';
  }

  /// Lấy extension file
  String _extractFileExtension(String sourcePath) {
    final filename = sourcePath.split(Platform.pathSeparator).last;
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == filename.length - 1) return '';
    return filename.substring(dotIndex);
  }
}

/// HTTP client cho Google Sign In
class _GoogleSignInHttpClient extends http.BaseClient {
  final GoogleSignInAccount _googleSignInAccount;
  final Map<String, String> _authHeaders;
  final http.Client _inner = http.Client();

  _GoogleSignInHttpClient(this._googleSignInAccount, this._authHeaders);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(_authHeaders);
    return _inner.send(request);
  }
}
