import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NetworkCheck {
  static bool _offlineMessageShown = false;

  static Future<bool> isOnline({bool showError = true}) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    List checkList = [
      ConnectivityResult.mobile,
      ConnectivityResult.wifi,
      ConnectivityResult.vpn,
    ];
    if (Platform.isIOS) checkList.add(ConnectivityResult.other);
    if (checkList.any((item) => connectivityResult.contains(item))) {
      _offlineMessageShown = false;
      return true;
    } else {
      if (showError && !_offlineMessageShown)
        _showStatusMessage(
          "Vui lòng kiểm tra kết nối Internet và chạy lại ứng dụng.".tr,
        );
      _offlineMessageShown = true;
      return false;
    }
  }
}

void _showStatusMessage(String message) {
  final context = Get.context;
  if (context == null) return;

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 10)),
  );
}
