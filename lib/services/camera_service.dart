import 'dart:io';

import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'download_path_service.dart';

class CameraService {
  final ImagePicker _imagePicker = ImagePicker();
  final DownloadPathService _downloadPathService = DownloadPathService();
  static const String _timestampPackage = 'com.jeyluta.timestampcamerafree';

  /// Mở system chooser của Android để người dùng chọn app camera trên máy.
  /// Trả về đường dẫn ảnh đã lưu vào thư mục app, hoặc null nếu huỷ.
  Future<String?> captureWithSystemChooser() async {
    if (!Platform.isAndroid) {
      // Trên iOS / các nền tảng khác không có chooser camera kiểu Android.
      return captureInApp();
    }

    try {
      debugPrint('[CameraChooser] invoke captureWithChooser');
      const platform = MethodChannel('camera_chooser');
      final String result =
          await platform.invokeMethod<String>('captureWithChooser') ?? '';

      debugPrint('[CameraChooser] native result path="$result"');
      if (result.isEmpty) return null; // Người dùng huỷ hoặc lỗi
      return _copyToAppFolder(result);
    } on PlatformException catch (e) {
      debugPrint(
        '[CameraChooser] lỗi code=${e.code}, message=${e.message}, details=${e.details}',
      );
      rethrow;
    }
  }

  /// Chụp ảnh bằng camera mặc định qua image_picker (không hiện chooser).
  Future<String?> captureInApp() async {
    final file = await _imagePicker.pickImage(source: ImageSource.camera);
    if (file == null) return null;
    return _copyToAppFolder(file.path);
  }

  /// Chọn ảnh từ thư viện.
  Future<String?> pickFromGallery() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return _copyToAppFolder(file.path);
  }

  Future<void> openTimestampCameraOrStore() async {
    if (!Platform.isAndroid) return;
    await LaunchApp.openApp(
      androidPackageName: _timestampPackage,
      iosUrlScheme: '',
      appStoreLink: '',
      openStore: true,
    );
  }

  Future<bool> openTimestampCameraOnly() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await LaunchApp.openApp(
        androidPackageName: _timestampPackage,
        iosUrlScheme: '',
        appStoreLink: '',
        openStore: false,
      );
      return result == 1;
    } catch (_) {
      return false;
    }
  }

  Future<String> _copyToAppFolder(String sourcePath) async {
    final sourceFile = File(sourcePath);
    final imagesDir = await _downloadPathService.getCabinetSubDirectory(
      'images',
    );
    final filename = sourcePath.split(Platform.pathSeparator).last;
    final targetPath =
        '${imagesDir.path}/${DateTime.now().millisecondsSinceEpoch}_$filename';
    final copied = await sourceFile.copy(targetPath);
    return copied.path;
  }
}
