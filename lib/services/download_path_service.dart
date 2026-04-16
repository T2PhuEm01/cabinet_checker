import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum ExportLocationType { downloads, documents, custom }

class DownloadPathService {
  Future<Directory> getCabinetSubDirectory(
    String subFolder, {
    ExportLocationType locationType = ExportLocationType.downloads,
    String? customPath,
  }) async {
    if (locationType == ExportLocationType.custom && customPath != null) {
      final dir = Directory(customPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    }

    final baseDir = await _resolveBaseDirectory(locationType);
    final dir = Directory('${baseDir.path}/cabinet_checker/$subFolder');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<Directory> _resolveBaseDirectory(
    ExportLocationType locationType,
  ) async {
    if (locationType == ExportLocationType.documents) {
      return getApplicationDocumentsDirectory();
    }

    // On Android, always target public Download so users can see exported files.
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    }

    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return downloads;
    }

    return getApplicationDocumentsDirectory();
  }
}
