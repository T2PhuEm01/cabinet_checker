import 'dart:async';

class ExportCanceledException implements Exception {
  const ExportCanceledException([this.message = 'Đã hủy xuất dữ liệu.']);

  final String message;

  @override
  String toString() => message;
}

class ExportCancelToken {
  bool _isCanceled = false;
  final Completer<void> _cancelCompleter = Completer<void>();
  final List<void Function()> _listeners = <void Function()>[];

  bool get isCanceled => _isCanceled;
  Future<void> get whenCanceled => _cancelCompleter.future;

  void cancel() {
    if (_isCanceled) return;
    _isCanceled = true;
    if (!_cancelCompleter.isCompleted) {
      _cancelCompleter.complete();
    }
    final listenersSnapshot = List<void Function()>.from(_listeners);
    for (final listener in listenersSnapshot) {
      listener();
    }
  }

  void addListener(void Function() listener) {
    if (_isCanceled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void throwIfCanceled() {
    if (_isCanceled) {
      throw const ExportCanceledException();
    }
  }
}
