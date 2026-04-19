import 'dart:io';
import 'dart:convert';
import 'dart:isolate';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:image/image.dart' as img;

import '../models/cabinet_record.dart';
import 'export_cancel_token.dart';
import 'download_path_service.dart';

class ExportProgress {
  const ExportProgress({required this.value, required this.message});

  final double value;
  final String message;
}

typedef ExportProgressCallback = void Function(ExportProgress progress);

enum ExportImageMode { original, balanced, compact }

extension ExportImageModeLabel on ExportImageMode {
  String get labelVi {
    switch (this) {
      case ExportImageMode.original:
        return 'Giữ chất lượng cao';
      case ExportImageMode.balanced:
        return 'Cân bằng';
      case ExportImageMode.compact:
        return 'Nhẹ';
    }
  }
}

class ExportService {
  final DownloadPathService _downloadPathService = DownloadPathService();

  Future<(String csvPath, String xlsxPath)> exportRecords(
    List<CabinetRecord> records,
    ExportLocationType locationType, {
    String? customPath,
    ExportImageMode imageMode = ExportImageMode.balanced,
    ExportProgressCallback? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCanceled();
    onProgress?.call(
      const ExportProgress(
        value: 0.02,
        message: 'Đang chuẩn bị thư mục xuất...',
      ),
    );

    final exportDir = await _downloadPathService.getCabinetSubDirectory(
      'exports',
      locationType: locationType,
      customPath: customPath,
    );
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final csvPath = '${exportDir.path}/cabinet_report_$stamp.csv';
    final xlsxPath = '${exportDir.path}/cabinet_report_$stamp.xlsx';

    // Keep original photo references; no extra image folder generation.
    final photoInfoMap = <String, List<String>>{};
    final photoPathMap = <String, List<String>>{};
    final totalRecordCount = records.isEmpty ? 1 : records.length;
    for (final record in records) {
      cancelToken?.throwIfCanceled();
      final photoNames = <String>[];
      final photoPaths = <String>[];
      for (final photo in record.photos) {
        cancelToken?.throwIfCanceled();
        final sourceFile = File(photo.path);
        if (sourceFile.existsSync()) {
          photoNames.add(sourceFile.path.split(Platform.pathSeparator).last);
          photoPaths.add(sourceFile.path);
        }
      }
      photoInfoMap[record.id] = photoNames;
      photoPathMap[record.id] = photoPaths;

      final prepared = photoInfoMap.length;
      final progressValue = 0.04 + ((prepared / totalRecordCount) * 0.08);
      onProgress?.call(
        ExportProgress(
          value: progressValue.clamp(0.04, 0.12),
          message: 'Đang chuẩn bị dữ liệu ảnh... ($prepared/${records.length})',
        ),
      );
    }

    onProgress?.call(
      const ExportProgress(value: 0.15, message: 'Đang tạo file CSV...'),
    );
    final rows = _buildRows(records, photoInfoMap, photoPathMap);
    final csvText = const ListToCsvConverter().convert(rows);
    await File(csvPath).writeAsString(csvText, encoding: utf8);

    onProgress?.call(
      const ExportProgress(value: 0.22, message: 'Đang tạo file XLSX...'),
    );
    cancelToken?.throwIfCanceled();
    await _buildXlsxWithEmbeddedImages(
      xlsxPath: xlsxPath,
      records: records,
      photoPathMap: photoPathMap,
      imageMode: imageMode,
      onProgress: onProgress,
      startProgress: 0.22,
      endProgress: 0.94,
      cancelToken: cancelToken,
    );

    onProgress?.call(
      const ExportProgress(
        value: 0.96,
        message: 'Đang hoàn tất dữ liệu xuất...',
      ),
    );
    return (csvPath, xlsxPath);
  }

  List<List<dynamic>> _buildRows(
    List<CabinetRecord> records,
    Map<String, List<String>> photoInfoMap,
    Map<String, List<String>> photoPathMap,
  ) {
    final rows = <List<dynamic>>[
      <dynamic>[
        'STT',
        'Ma tu',
        'Ten tu',
        'Tuyen',
        'Lat chuan',
        'Lng chuan',
        'Lat thuc te',
        'Lng thuc te',
        'Sai so (m)',
        'Khoang cach toi ban (m)',
        'Trang thai',
        'Loi vi tri',
        'Loi treo lo lung',
        'Loi co dinh cap',
        'Loi khac',
        'Muc do',
        'So anh',
        'Danh sach anh',
        'Duong dan anh',
        'Thoi gian kiem tra',
        'Nguoi kiem tra',
        'Ghi chu',
      ],
    ];

    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      final photoNames = photoInfoMap[record.id] ?? [];
      final photoList = photoNames.join(' | ');
      final photoPaths = photoPathMap[record.id] ?? [];
      final photoPathList = photoPaths.join(' | ');
      rows.add(<dynamic>[
        i + 1,
        record.id,
        record.name,
        record.route,
        record.latitudeRef,
        record.longitudeRef,
        record.latitudeActual ?? '',
        record.longitudeActual ?? '',
        record.coordinateDeviationMeters?.toStringAsFixed(1) ?? '',
        record.distanceToUserMeters?.toStringAsFixed(1) ?? '',
        record.inspectionStatus.labelVi,
        record.wrongPosition ? 'Có' : 'Không',
        record.hangingCable ? 'Có' : 'Không',
        record.unfixedCable ? 'Có' : 'Không',
        record.otherIssue ? record.otherIssueType : 'Không',
        record.severity.labelVi,
        record.photos.length,
        photoList,
        photoPathList,
        record.lastCheckedAt?.toIso8601String() ?? '',
        record.inspectorName,
        record.notes,
      ]);
    }
    return rows;
  }

  Future<void> _buildXlsxWithEmbeddedImages({
    required String xlsxPath,
    required List<CabinetRecord> records,
    required Map<String, List<String>> photoPathMap,
    required ExportImageMode imageMode,
    ExportProgressCallback? onProgress,
    required double startProgress,
    required double endProgress,
    ExportCancelToken? cancelToken,
  }) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Cabinets';

    final headers = <String>[
      'STT',
      'Ma tu',
      'Ten tu',
      'Tuyen',
      'Lat chuan',
      'Lng chuan',
      'Lat thuc te',
      'Lng thuc te',
      'Sai so (m)',
      'Khoang cach toi ban (m)',
      'Trang thai',
      'Loi vi tri',
      'Loi treo lo lung',
      'Loi co dinh cap',
      'Loi khac',
      'Muc do',
      'So anh',
      'Danh sach anh',
      'Thoi gian kiem tra',
      'Nguoi kiem tra',
      'Ghi chu',
      'Hinh anh',
    ];

    final headerStyle = workbook.styles.add('headerStyle');
    headerStyle.bold = true;
    headerStyle.fontColor = '#FFFFFF';
    headerStyle.backColor = '#2F5597';
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;
    headerStyle.wrapText = true;
    headerStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

    final bodyStyle = workbook.styles.add('bodyStyle');
    bodyStyle.hAlign = xlsio.HAlignType.left;
    bodyStyle.vAlign = xlsio.VAlignType.top;
    bodyStyle.wrapText = true;
    bodyStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

    final centerStyle = workbook.styles.add('centerStyle');
    centerStyle.hAlign = xlsio.HAlignType.center;
    centerStyle.vAlign = xlsio.VAlignType.center;
    centerStyle.wrapText = true;
    centerStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.getRangeByIndex(1, c + 1);
      cell.setText(headers[c]);
      cell.cellStyle = headerStyle;
    }
    sheet.getRangeByIndex(1, 1, 1, headers.length).rowHeight = 28;

    final widths = <double>[
      7, // STT
      16, // Ma tu
      24, // Ten tu
      16, // Tuyen
      12, // Lat chuan
      12, // Lng chuan
      12, // Lat thuc te
      12, // Lng thuc te
      12, // Sai so
      15, // Khoang cach
      14, // Trang thai
      10, // Loi vi tri
      12, // Loi treo
      12, // Loi co dinh
      16, // Loi khac
      10, // Muc do
      8, // So anh
      20, // Danh sach anh
      22, // Thoi gian
      18, // Nguoi kiem tra
      28, // Ghi chu
      46, // Hinh anh
    ];
    for (var i = 0; i < widths.length; i++) {
      sheet.getRangeByIndex(1, i + 1).columnWidth = widths[i];
    }

    for (var i = 0; i < records.length; i++) {
      cancelToken?.throwIfCanceled();
      final row = i + 2;
      final record = records[i];
      final photoPaths = photoPathMap[record.id] ?? <String>[];
      final photoNames = photoPaths
          .map((path) => path.split(Platform.pathSeparator).last)
          .toList();

      final values = <String>[
        '${i + 1}',
        record.id,
        record.name,
        record.route,
        '${record.latitudeRef}',
        '${record.longitudeRef}',
        '${record.latitudeActual ?? ''}',
        '${record.longitudeActual ?? ''}',
        record.coordinateDeviationMeters?.toStringAsFixed(1) ?? '',
        record.distanceToUserMeters?.toStringAsFixed(1) ?? '',
        record.inspectionStatus.labelVi,
        record.wrongPosition ? 'Có' : 'Không',
        record.hangingCable ? 'Có' : 'Không',
        record.unfixedCable ? 'Có' : 'Không',
        record.otherIssue ? record.otherIssueType : 'Không',
        record.severity.labelVi,
        '${record.photos.length}',
        photoNames.join(' | '),
        record.lastCheckedAt?.toIso8601String() ?? '',
        record.inspectorName,
        record.notes,
        '', // image collage cell
      ];

      for (var c = 0; c < values.length; c++) {
        final cell = sheet.getRangeByIndex(row, c + 1);
        cell.setText(values[c]);
        cell.cellStyle = (c == 0 || c == 16 || c == 21)
            ? centerStyle
            : bodyStyle;
      }

      final hasPhoto = photoPaths.isNotEmpty;
      sheet.getRangeByIndex(row, 1, row, headers.length).rowHeight = hasPhoto
          ? 128
          : 24;

      if (hasPhoto) {
        cancelToken?.throwIfCanceled();
        final collage = await _createPhotoCollage(photoPaths, imageMode);
        if (collage != null) {
          final collageBytes = collage['bytes'];
          final collageWidth = collage['width'];
          final collageHeight = collage['height'];
          if (collageBytes is List<int> &&
              collageWidth is int &&
              collageHeight is int) {
            final picture = sheet.pictures.addStream(row, 22, collageBytes);
            picture.width = collageWidth;
            picture.height = collageHeight;
            sheet.getRangeByIndex(row, 1, row, headers.length).rowHeight =
                (collageHeight + 8).toDouble();
          }
        }
      }

      final recordProgress = records.isEmpty
          ? endProgress
          : startProgress +
                (((i + 1) / records.length) * (endProgress - startProgress));
      onProgress?.call(
        ExportProgress(
          value: recordProgress.clamp(startProgress, endProgress),
          message: 'Đang tạo XLSX... (${i + 1}/${records.length})',
        ),
      );
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    await File(xlsxPath).writeAsBytes(bytes, flush: true);
  }

  Future<Map<String, Object>?> _createPhotoCollage(
    List<String> photoPaths,
    ExportImageMode imageMode,
  ) async {
    if (photoPaths.isEmpty) return null;
    return Isolate.run(
      () => _createPhotoCollageWorker(photoPaths, imageMode.index),
    );
  }
}

Map<String, Object>? _createPhotoCollageWorker(
  List<String> photoPaths,
  int imageModeIndex,
) {
  final validImages = <img.Image>[];
  for (final path in photoPaths) {
    try {
      final bytes = File(path).readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        validImages.add(decoded);
      }
    } catch (_) {
      // Skip invalid images
    }
  }
  if (validImages.isEmpty) return null;

  final imageMode = ExportImageMode.values[imageModeIndex];
  final (thumbWidth, thumbHeight, gap, quality) = switch (imageMode) {
    ExportImageMode.original => (240, 180, 8, 96),
    ExportImageMode.balanced => (160, 120, 6, 92),
    ExportImageMode.compact => (110, 82, 4, 85),
  };

  final count = validImages.length;
  final canvasWidth = (thumbWidth * count) + (gap * (count - 1));
  final canvasHeight = thumbHeight;
  final canvas = img.Image(
    width: canvasWidth,
    height: canvasHeight,
    numChannels: 4,
  );
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

  for (var i = 0; i < count; i++) {
    final source = validImages[i];

    final widthScale = thumbWidth / source.width;
    final heightScale = thumbHeight / source.height;
    final fitScale = widthScale < heightScale ? widthScale : heightScale;
    final fitWidth = (source.width * fitScale).round().clamp(1, thumbWidth);
    final fitHeight = (source.height * fitScale).round().clamp(1, thumbHeight);

    final resized = img.copyResize(
      source,
      width: fitWidth,
      height: fitHeight,
      interpolation: img.Interpolation.cubic,
    );

    final tile = img.Image(
      width: thumbWidth,
      height: thumbHeight,
      numChannels: 4,
    );
    img.fill(tile, color: img.ColorRgb8(255, 255, 255));
    final offsetX = ((thumbWidth - fitWidth) / 2).round();
    final offsetY = ((thumbHeight - fitHeight) / 2).round();
    img.compositeImage(tile, resized, dstX: offsetX, dstY: offsetY);

    final x = i * (thumbWidth + gap);
    img.compositeImage(canvas, tile, dstX: x, dstY: 0);
  }

  return {
    'bytes': img.encodeJpg(canvas, quality: quality),
    'width': canvasWidth,
    'height': canvasHeight,
  };
}
