import 'dart:io';

import 'package:flutter/services.dart';

class ExportNotificationService {
  static const MethodChannel _channel = MethodChannel(
    'cabinet_checker/export_notification',
  );

  Future<void> show({
    required String title,
    required String text,
    int? progress,
    bool indeterminate = false,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('showExportNotification', {
        'title': title,
        'text': text,
        'progress': progress,
        'indeterminate': indeterminate,
      });
    } catch (_) {
      // Keep export flow running even if notification update fails.
    }
  }

  Future<void> update({
    required String title,
    required String text,
    int? progress,
    bool indeterminate = false,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('updateExportNotification', {
        'title': title,
        'text': text,
        'progress': progress,
        'indeterminate': indeterminate,
      });
    } catch (_) {
      // Keep export flow running even if notification update fails.
    }
  }

  Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('cancelExportNotification');
    } catch (_) {
      // Ignore native errors on cleanup.
    }
  }
}
