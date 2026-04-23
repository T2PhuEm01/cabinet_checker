import 'package:flutter/services.dart';

class IosBackgroundTaskService {
  static const MethodChannel _channel = MethodChannel(
    'cabinet_checker/ios_background_task',
  );

  Future<bool> beginExportTask() async {
    try {
      final result = await _channel.invokeMethod<bool>('beginExportTask');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> endExportTask() async {
    try {
      await _channel.invokeMethod<void>('endExportTask');
    } catch (_) {
      // Ignore native errors and continue normal flow.
    }
  }
}
