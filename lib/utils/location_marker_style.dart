import 'package:flutter/material.dart';

import '../models/cabinet_record.dart';

enum LocationMarkerIconType { pin, circle, flag }

extension LocationMarkerIconTypeLabel on LocationMarkerIconType {
  String get label {
    switch (this) {
      case LocationMarkerIconType.pin:
        return 'Ghim';
      case LocationMarkerIconType.circle:
        return 'Chấm tròn';
      case LocationMarkerIconType.flag:
        return 'Cờ';
    }
  }

  IconData get iconData {
    switch (this) {
      case LocationMarkerIconType.pin:
        return Icons.location_on;
      case LocationMarkerIconType.circle:
        return Icons.circle;
      case LocationMarkerIconType.flag:
        return Icons.flag;
    }
  }
}

class LocationMarkerStyle {
  const LocationMarkerStyle({required this.color, required this.statusLabel});

  final Color color;
  final String statusLabel;
}

LocationMarkerStyle getLocationMarkerStyle(CabinetRecord record) {
  final hasIssue =
      !record.isPassed ||
      record.wrongPosition ||
      record.hangingCable ||
      record.unfixedCable ||
      record.otherIssue;

  if (record.inspectionStatus == InspectionStatus.recheckNeeded) {
    return const LocationMarkerStyle(
      color: Colors.red,
      statusLabel: 'Không tìm thấy',
    );
  }

  if (record.inspectionStatus == InspectionStatus.checked && hasIssue) {
    return const LocationMarkerStyle(
      color: Colors.amber,
      statusLabel: 'Đã kiểm nhưng không đạt',
    );
  }

  if (record.inspectionStatus == InspectionStatus.checked) {
    return const LocationMarkerStyle(
      color: Colors.green,
      statusLabel: 'Đã kiểm đạt',
    );
  }

  return const LocationMarkerStyle(
    color: Colors.blue,
    statusLabel: 'Chưa kiểm',
  );
}
