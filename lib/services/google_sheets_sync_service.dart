import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../models/cabinet_record.dart';
import 'export_cancel_token.dart';

class GoogleSheetsSyncProgress {
  const GoogleSheetsSyncProgress({required this.value, required this.message});

  final double value;
  final String message;
}

typedef GoogleSheetsSyncProgressCallback =
    void Function(GoogleSheetsSyncProgress progress);

class GoogleSheetsSyncService {
  static const int _maxUploadAttempts = 3;
  static const Duration _singleRecordTimeout = Duration(seconds: 300);

  Future<int> syncRecords({
    required String appsScriptUrl,
    required String sheetName,
    required List<CabinetRecord> records,
    GoogleSheetsSyncProgressCallback? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCanceled();
    final uri = Uri.parse(appsScriptUrl.trim());
    _validateAppsScriptUri(uri);

    final normalizedSheetName = sheetName.trim();
    if (normalizedSheetName.isEmpty) {
      throw const FormatException('Tên trang tính không được để trống.');
    }

    if (records.isEmpty) return 0;

    final exportSessionId =
        '${DateTime.now().microsecondsSinceEpoch}_${records.length}';

    onProgress?.call(
      const GoogleSheetsSyncProgress(
        value: 0.02,
        message: 'Đang kết nối Google Apps Script...',
      ),
    );

    var successCount = 0;
    final total = records.length;

    for (var i = 0; i < total; i++) {
      cancelToken?.throwIfCanceled();
      final record = records[i];
      final photosPayload = <Map<String, dynamic>>[];
      final photoNames = <String>[];
      final photoLocalPaths = <String>[];

      for (
        var photoIndex = 0;
        photoIndex < record.photos.length;
        photoIndex++
      ) {
        final photo = record.photos[photoIndex];
        cancelToken?.throwIfCanceled();
        final file = File(photo.path);
        if (!file.existsSync()) continue;
        late final List<int> bytes;
        try {
          bytes = await _awaitCancellable(file.readAsBytes(), cancelToken);
        } on FileSystemException {
          continue;
        }
        final fileName = _buildPhotoFileName(
          cabinetCode: record.id,
          sourcePath: file.path,
          photoIndex: photoIndex,
          photoCount: record.photos.length,
        );
        photoNames.add(fileName);
        photoLocalPaths.add(photo.path);
        photosPayload.add(<String, dynamic>{
          'name': fileName,
          'mimeType': _guessMimeType(fileName),
          'base64': base64Encode(bytes),
          // Backward-compatible aliases for older Apps Script payload parsers.
          'data': base64Encode(bytes),
          'content': base64Encode(bytes),
          'path': photo.path,
          'capturedAt': photo.capturedAt.toIso8601String(),
          'latitude': photo.latitude,
          'longitude': photo.longitude,
          'source': photo.source,
        });
      }

      final body = <String, dynamic>{
        'action': 'appendCabinetRecord',
        'sheetName': normalizedSheetName,
        'exportSessionId': exportSessionId,
        'record': <String, dynamic>{
          'id': record.id,
          'name': record.name,
          'route': record.route,
          'latitudeRef': record.latitudeRef,
          'longitudeRef': record.longitudeRef,
          'latitudeActual': record.latitudeActual,
          'longitudeActual': record.longitudeActual,
          'distanceToUserMeters': record.distanceToUserMeters,
          'coordinateDeviationMeters': record.coordinateDeviationMeters,
          'inspectionStatus': record.inspectionStatus.labelVi,
          'wrongPosition': record.wrongPosition ? 'Có' : 'Không',
          'hangingCable': record.hangingCable ? 'Có' : 'Không',
          'unfixedCable': record.unfixedCable ? 'Có' : 'Không',
          'otherIssue': record.otherIssue,
          'otherIssueType': record.otherIssueType,
          'isPassed': record.isPassed ? 'Đạt' : 'Không đạt',
          'severity': record.severity.labelVi,
          'notes': record.notes,
          'inspectorName': record.inspectorName,
          'lastCheckedAt': record.lastCheckedAt?.toIso8601String(),
          // Compatibility fields some scripts use to render photo columns.
          'photoCount': record.photos.length,
          'photoNames': photoNames,
          'photoLocalPaths': photoLocalPaths,
        },
        'photoCount': record.photos.length,
        'photoNames': photoNames,
        'photoLocalPaths': photoLocalPaths,
        'photos': photosPayload,
      };

      await _uploadRecordWithRetry(
        uri: uri,
        body: body,
        expectedPhotoCount: photosPayload.length,
        cancelToken: cancelToken,
        onRetry: (attempt, maxAttempts) {
          onProgress?.call(
            GoogleSheetsSyncProgress(
              value: (0.03 + ((i / total) * 0.9)).clamp(0.03, 0.94),
              message:
                  'Bản ghi ${i + 1}/$total lỗi tạm thời, thử lại lần $attempt/$maxAttempts...',
            ),
          );
        },
      );

      successCount += 1;
      final done = i + 1;
      final value = 0.05 + ((done / total) * 0.9);
      onProgress?.call(
        GoogleSheetsSyncProgress(
          value: value.clamp(0.05, 0.95),
          message: 'Đang đẩy dữ liệu lên Google Sheets... ($done/$total)',
        ),
      );
    }

    onProgress?.call(
      const GoogleSheetsSyncProgress(
        value: 1.0,
        message: 'Hoàn tất đồng bộ Google Sheets.',
      ),
    );

    return successCount;
  }

  Future<void> _uploadRecordWithRetry({
    required Uri uri,
    required Map<String, dynamic> body,
    required int expectedPhotoCount,
    ExportCancelToken? cancelToken,
    void Function(int attempt, int maxAttempts)? onRetry,
  }) async {
    for (var attempt = 1; attempt <= _maxUploadAttempts; attempt++) {
      cancelToken?.throwIfCanceled();
      try {
        final response = await _postJson(
          uri,
          body,
          cancelToken: cancelToken,
        ).timeout(_singleRecordTimeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _validateSuccessfulBody(
            uri: uri,
            body: response.body,
            expectedPhotoCount: expectedPhotoCount,
          );
          return;
        }

        if (_isRetryableStatus(response.statusCode) &&
            attempt < _maxUploadAttempts) {
          onRetry?.call(attempt + 1, _maxUploadAttempts);
          await _awaitRetryDelay(attempt, cancelToken);
          continue;
        }

        throw HttpException(_buildHttpErrorMessage(uri, response));
      } on ExportCanceledException {
        rethrow;
      } on TimeoutException {
        if (attempt >= _maxUploadAttempts) {
          rethrow;
        }
        onRetry?.call(attempt + 1, _maxUploadAttempts);
        await _awaitRetryDelay(attempt, cancelToken);
      } on SocketException {
        if (attempt >= _maxUploadAttempts) {
          rethrow;
        }
        onRetry?.call(attempt + 1, _maxUploadAttempts);
        await _awaitRetryDelay(attempt, cancelToken);
      }
    }
  }

  Future<void> _awaitRetryDelay(int attempt, ExportCancelToken? cancelToken) {
    final delaySeconds = attempt.clamp(1, 4);
    return _awaitCancellable(
      Future<void>.delayed(Duration(seconds: delaySeconds)),
      cancelToken,
    );
  }

  Future<_HttpResponseData> _postJson(
    Uri uri,
    Map<String, dynamic> body, {
    ExportCancelToken? cancelToken,
  }) async {
    final client = HttpClient();
    void closeClientOnCancel() {
      client.close(force: true);
    }

    cancelToken?.addListener(closeClientOnCancel);
    try {
      cancelToken?.throwIfCanceled();
      final payload = utf8.encode(jsonEncode(body));
      var currentUri = uri;
      var currentMethod = 'POST';
      var redirectCount = 0;

      while (true) {
        cancelToken?.throwIfCanceled();
        final request = currentMethod == 'POST'
            ? await _awaitCancellable(client.postUrl(currentUri), cancelToken)
            : await _awaitCancellable(client.getUrl(currentUri), cancelToken);
        if (currentMethod == 'POST') {
          request.headers.contentType = ContentType.json;
          request.add(payload);
        }

        final response = await _awaitCancellable(request.close(), cancelToken);
        final statusCode = response.statusCode;
        final location = response.headers.value(HttpHeaders.locationHeader);

        if (_isRedirectStatus(statusCode) && location != null) {
          redirectCount += 1;
          if (redirectCount > 5) {
            final responseBody = await _awaitCancellable(
              utf8.decoder.bind(response).join(),
              cancelToken,
            );
            return _HttpResponseData(
              statusCode: statusCode,
              body: responseBody,
            );
          }

          currentUri = currentUri.resolve(location);
          currentMethod =
              (statusCode == HttpStatus.temporaryRedirect ||
                  statusCode == HttpStatus.permanentRedirect)
              ? currentMethod
              : 'GET';
          continue;
        }

        final responseBody = await _awaitCancellable(
          utf8.decoder.bind(response).join(),
          cancelToken,
        );
        return _HttpResponseData(statusCode: statusCode, body: responseBody);
      }
    } on ExportCanceledException {
      rethrow;
    } on SocketException {
      if (cancelToken?.isCanceled ?? false) {
        throw const ExportCanceledException();
      }
      rethrow;
    } on HttpException {
      if (cancelToken?.isCanceled ?? false) {
        throw const ExportCanceledException();
      }
      rethrow;
    } finally {
      cancelToken?.removeListener(closeClientOnCancel);
      client.close(force: true);
    }
  }

  Future<T> _awaitCancellable<T>(Future<T> future, ExportCancelToken? token) {
    if (token == null) return future;
    return Future.any(<Future<T>>[
      future,
      token.whenCanceled.then<T>((_) => throw const ExportCanceledException()),
    ]);
  }

  void _validateSuccessfulBody({
    required Uri uri,
    required String body,
    required int expectedPhotoCount,
  }) {
    if (body.trim().isEmpty) return;
    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      } else if (raw is Map) {
        decoded = Map<String, dynamic>.from(raw);
      }
    } catch (_) {
      return;
    }
    if (decoded == null) return;

    final ok = decoded['ok'];
    if (ok == false) {
      final error = (decoded['error'] ?? 'Unknown Apps Script error')
          .toString();
      throw HttpException('Google Apps Script báo lỗi: $error');
    }

    if (expectedPhotoCount <= 0) return;
    final photosUploaded = _asInt(decoded['photosUploaded']);
    if (photosUploaded != null && photosUploaded == 0) {
      throw HttpException(
        'Không tạo được link ảnh trên Google Drive dù bản ghi có ảnh. '
        'Hãy kiểm tra quyền Drive trong Apps Script và dùng bản script mới nhất. URL hiện tại: $uri',
      );
    }
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _buildPhotoFileName({
    required String cabinetCode,
    required String sourcePath,
    required int photoIndex,
    required int photoCount,
  }) {
    final safeCabinetCode = _sanitizeFileName(cabinetCode);
    final extension = _extractFileExtension(sourcePath);
    if (photoCount <= 1) {
      return '$safeCabinetCode$extension';
    }
    return '${safeCabinetCode}_${photoIndex + 1}$extension';
  }

  String _sanitizeFileName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'cabinet';
    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  }

  String _extractFileExtension(String sourcePath) {
    final filename = sourcePath.split(Platform.pathSeparator).last;
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == filename.length - 1) return '';
    return filename.substring(dotIndex);
  }

  bool _isRedirectStatus(int statusCode) {
    return statusCode == HttpStatus.movedPermanently ||
        statusCode == HttpStatus.found ||
        statusCode == HttpStatus.seeOther ||
        statusCode == HttpStatus.temporaryRedirect ||
        statusCode == HttpStatus.permanentRedirect;
  }

  bool _isRetryableStatus(int statusCode) {
    return statusCode == HttpStatus.requestTimeout ||
        statusCode == HttpStatus.tooManyRequests ||
        statusCode == HttpStatus.internalServerError ||
        statusCode == HttpStatus.badGateway ||
        statusCode == HttpStatus.serviceUnavailable ||
        statusCode == HttpStatus.gatewayTimeout;
  }

  void _validateAppsScriptUri(Uri uri) {
    if (!uri.hasScheme || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw const FormatException('URL Apps Script không hợp lệ.');
    }

    final host = uri.host.toLowerCase();
    final isGoogleScriptHost =
        host == 'script.google.com' || host.endsWith('.script.google.com');
    if (!isGoogleScriptHost) {
      throw const FormatException(
        'URL không phải Google Apps Script. Dùng URL dạng https://script.google.com/macros/s/.../exec',
      );
    }

    final path = uri.path.toLowerCase();
    if (!path.contains('/macros/s/') || !path.endsWith('/exec')) {
      throw const FormatException(
        'URL Apps Script phải là bản Web App kết thúc bằng /exec.',
      );
    }
  }

  String _buildHttpErrorMessage(Uri uri, _HttpResponseData response) {
    final code = response.statusCode;
    final body = response.body;
    final isHtml = body.contains('<!DOCTYPE html>') || body.contains('<html');
    final notFoundPage = body.contains('Không tìm thấy trang');

    if ((code == 401 || code == 403) && isHtml) {
      return 'Google Apps Script trả về $code (không có quyền truy cập). '
          'Hãy Deploy Web App với quyền Anyone và dùng đúng URL /exec. URL hiện tại: $uri';
    }

    if (code == 405 || (isHtml && notFoundPage)) {
      return 'Google Apps Script trả về $code (URL sai hoặc chưa deploy Web App). '
          'Cần URL dạng https://script.google.com/macros/s/.../exec. URL hiện tại: $uri';
    }

    final snippet = body.length > 300 ? '${body.substring(0, 300)}...' : body;
    return 'Google Apps Script trả về lỗi $code: $snippet';
  }

  String _guessMimeType(String fileName) {
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) return 'image/jpeg';
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.webp')) return 'image/webp';
    if (ext.endsWith('.heic')) return 'image/heic';
    return 'application/octet-stream';
  }
}

class _HttpResponseData {
  const _HttpResponseData({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}
