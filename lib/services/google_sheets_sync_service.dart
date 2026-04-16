import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

import '../models/cabinet_record.dart';

class GoogleSheetsSyncProgress {
  const GoogleSheetsSyncProgress({required this.value, required this.message});

  final double value;
  final String message;
}

typedef GoogleSheetsSyncProgressCallback =
    void Function(GoogleSheetsSyncProgress progress);

class GoogleSheetsSyncService {
  Future<int> syncRecords({
    required String appsScriptUrl,
    required List<CabinetRecord> records,
    GoogleSheetsSyncProgressCallback? onProgress,
  }) async {
    final uri = Uri.parse(appsScriptUrl.trim());
    _validateAppsScriptUri(uri);

    if (records.isEmpty) return 0;

    onProgress?.call(
      const GoogleSheetsSyncProgress(
        value: 0.02,
        message: 'Đang kết nối Google Apps Script...',
      ),
    );

    var successCount = 0;
    final total = records.length;

    for (var i = 0; i < total; i++) {
      final record = records[i];
      final photosPayload = <Map<String, dynamic>>[];

      for (final photo in record.photos) {
        final file = File(photo.path);
        if (!file.existsSync()) continue;
        final bytes = await file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        final fileName = file.path.split(Platform.pathSeparator).last;
        photosPayload.add(<String, dynamic>{
          'name': fileName,
          'mimeType': _guessMimeType(fileName),
          'base64': base64Encode(bytes),
          'width': decoded?.width,
          'height': decoded?.height,
          'capturedAt': photo.capturedAt.toIso8601String(),
          'latitude': photo.latitude,
          'longitude': photo.longitude,
          'source': photo.source,
        });
      }

      final body = <String, dynamic>{
        'action': 'appendCabinetRecord',
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
          'wrongPosition': record.wrongPosition,
          'hangingCable': record.hangingCable,
          'unfixedCable': record.unfixedCable,
          'otherIssue': record.otherIssue,
          'otherIssueType': record.otherIssueType,
          'isPassed': record.isPassed,
          'severity': record.severity.name,
          'notes': record.notes,
          'inspectorName': record.inspectorName,
          'lastCheckedAt': record.lastCheckedAt?.toIso8601String(),
        },
        'photos': photosPayload,
      };

      final response = await _postJson(
        uri,
        body,
      ).timeout(const Duration(seconds: 180));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(_buildHttpErrorMessage(uri, response));
      }

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

  Future<_HttpResponseData> _postJson(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient();
    try {
      final payload = utf8.encode(jsonEncode(body));
      var currentUri = uri;
      var currentMethod = 'POST';
      var redirectCount = 0;

      while (true) {
        final request = currentMethod == 'POST'
            ? await client.postUrl(currentUri)
            : await client.getUrl(currentUri);
        if (currentMethod == 'POST') {
          request.headers.contentType = ContentType.json;
          request.add(payload);
        }

        final response = await request.close();
        final statusCode = response.statusCode;
        final location = response.headers.value(HttpHeaders.locationHeader);

        if (_isRedirectStatus(statusCode) && location != null) {
          redirectCount += 1;
          if (redirectCount > 5) {
            final responseBody = await utf8.decoder.bind(response).join();
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

        final responseBody = await utf8.decoder.bind(response).join();
        return _HttpResponseData(statusCode: statusCode, body: responseBody);
      }
    } finally {
      client.close(force: true);
    }
  }

  bool _isRedirectStatus(int statusCode) {
    return statusCode == HttpStatus.movedPermanently ||
        statusCode == HttpStatus.found ||
        statusCode == HttpStatus.seeOther ||
        statusCode == HttpStatus.temporaryRedirect ||
        statusCode == HttpStatus.permanentRedirect;
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
