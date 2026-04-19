import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

VisualDensity get minimumVisualDensity =>
    const VisualDensity(horizontal: -4, vertical: -4);

void editTextFocusDisable(BuildContext context) {
  FocusScope.of(context).requestFocus(FocusNode());
}

String getEnumString(dynamic enumValue) {
  String string = enumValue.toString();
  try {
    string = string.split(".").last;
    return string;
  } catch (_) {}
  return "";
}

Future<String> htmlString(String path) async {
  String fileText = await rootBundle.loadString(path);
  String htmlStr = Uri.dataFromString(
    fileText,
    mimeType: 'text/html',
    encoding: Encoding.getByName('utf-8'),
  ).toString();
  return htmlStr;
}

///package_info_plus: ^3.0.1
Future<String> getAppId() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.packageName;
}

Future<String> getAppName() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.appName;
}

bool isTextScaleGetterThanOne(BuildContext context) {
  return [
    const TextScaler.linear(1.1),
    const TextScaler.linear(1.2),
    const TextScaler.linear(1.3),
    const TextScaler.linear(1.4),
    const TextScaler.linear(1.5),
  ].contains(MediaQuery.of(context).textScaler);
}

void navigationTo(
  BuildContext context, {
  StatefulWidget? sFull,
  bool removeCurrent = false,
  StatelessWidget? sLess,
  Function(dynamic)? onResult,
}) async {
  dynamic result;
  if (removeCurrent) {
    result = await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (BuildContext context) => sFull ?? sLess!),
    );
  } else {
    result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (BuildContext context) => sFull ?? sLess!),
    );
  }
  if (onResult != null) onResult(result);
}
