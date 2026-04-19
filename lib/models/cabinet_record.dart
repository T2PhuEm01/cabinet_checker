import 'dart:convert';

enum InspectionStatus { notChecked, checked, recheckNeeded }

enum SeverityLevel { none, low, medium, high }

extension InspectionStatusDisplay on InspectionStatus {
  String get labelVi {
    switch (this) {
      case InspectionStatus.notChecked:
        return 'Chưa kiểm';
      case InspectionStatus.checked:
        return 'Đã kiểm';
      case InspectionStatus.recheckNeeded:
        return 'Cần kiểm lại';
    }
  }
}

extension SeverityLevelDisplay on SeverityLevel {
  String get labelVi {
    switch (this) {
      case SeverityLevel.none:
        return 'Bình thường';
      case SeverityLevel.low:
        return 'Thấp';
      case SeverityLevel.medium:
        return 'Trung bình';
      case SeverityLevel.high:
        return 'Cao';
    }
  }
}

class CabinetPhoto {
  CabinetPhoto({
    required this.path,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.source = 'camera',
  });

  final String path;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final String source;

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'capturedAt': capturedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'source': source,
    };
  }

  factory CabinetPhoto.fromMap(Map<String, dynamic> map) {
    return CabinetPhoto(
      path: map['path'] as String? ?? '',
      capturedAt:
          DateTime.tryParse(map['capturedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      source: map['source'] as String? ?? 'camera',
    );
  }
}

class CabinetRecord {
  CabinetRecord({
    required this.id,
    required this.name,
    required this.latitudeRef,
    required this.longitudeRef,
    this.route = '',
    this.latitudeActual,
    this.longitudeActual,
    this.distanceToUserMeters,
    this.coordinateDeviationMeters,
    this.inspectionStatus = InspectionStatus.notChecked,
    this.wrongPosition = false,
    this.hangingCable = false,
    this.unfixedCable = false,
    this.otherIssue = false,
    this.otherIssueType = '',
    this.isPassed = false,
    this.severity = SeverityLevel.none,
    this.notes = '',
    this.inspectorName = '',
    this.lastCheckedAt,
    List<CabinetPhoto>? photos,
  }) : photos = photos ?? <CabinetPhoto>[];

  final String id;
  final String name;
  final double latitudeRef;
  final double longitudeRef;
  final String route;
  double? latitudeActual;
  double? longitudeActual;
  double? distanceToUserMeters;
  double? coordinateDeviationMeters;
  InspectionStatus inspectionStatus;
  bool wrongPosition;
  bool hangingCable;
  bool unfixedCable;
  bool otherIssue;
  String otherIssueType;
  bool isPassed;
  SeverityLevel severity;
  String notes;
  String inspectorName;
  DateTime? lastCheckedAt;
  final List<CabinetPhoto> photos;

  CabinetRecord copyWith({
    String? id,
    String? name,
    double? latitudeRef,
    double? longitudeRef,
    String? route,
    double? latitudeActual,
    double? longitudeActual,
    double? distanceToUserMeters,
    double? coordinateDeviationMeters,
    InspectionStatus? inspectionStatus,
    bool? wrongPosition,
    bool? hangingCable,
    bool? unfixedCable,
    bool? otherIssue,
    String? otherIssueType,
    bool? isPassed,
    SeverityLevel? severity,
    String? notes,
    String? inspectorName,
    DateTime? lastCheckedAt,
    List<CabinetPhoto>? photos,
  }) {
    return CabinetRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      latitudeRef: latitudeRef ?? this.latitudeRef,
      longitudeRef: longitudeRef ?? this.longitudeRef,
      route: route ?? this.route,
      latitudeActual: latitudeActual ?? this.latitudeActual,
      longitudeActual: longitudeActual ?? this.longitudeActual,
      distanceToUserMeters: distanceToUserMeters ?? this.distanceToUserMeters,
      coordinateDeviationMeters:
          coordinateDeviationMeters ?? this.coordinateDeviationMeters,
      inspectionStatus: inspectionStatus ?? this.inspectionStatus,
      wrongPosition: wrongPosition ?? this.wrongPosition,
      hangingCable: hangingCable ?? this.hangingCable,
      unfixedCable: unfixedCable ?? this.unfixedCable,
      otherIssue: otherIssue ?? this.otherIssue,
      otherIssueType: otherIssueType ?? this.otherIssueType,
      isPassed: isPassed ?? this.isPassed,
      severity: severity ?? this.severity,
      notes: notes ?? this.notes,
      inspectorName: inspectorName ?? this.inspectorName,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      photos: photos ?? List<CabinetPhoto>.from(this.photos),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitudeRef': latitudeRef,
      'longitudeRef': longitudeRef,
      'route': route,
      'latitudeActual': latitudeActual,
      'longitudeActual': longitudeActual,
      'distanceToUserMeters': distanceToUserMeters,
      'coordinateDeviationMeters': coordinateDeviationMeters,
      'inspectionStatus': inspectionStatus.name,
      'wrongPosition': wrongPosition,
      'hangingCable': hangingCable,
      'unfixedCable': unfixedCable,
      'otherIssue': otherIssue,
      'otherIssueType': otherIssueType,
      'isPassed': isPassed,
      'severity': severity.labelVi,
      'notes': notes,
      'inspectorName': inspectorName,
      'lastCheckedAt': lastCheckedAt?.toIso8601String(),
      'photos': photos.map((photo) => photo.toMap()).toList(),
    };
  }

  factory CabinetRecord.fromMap(Map<String, dynamic> map) {
    InspectionStatus status = InspectionStatus.notChecked;
    final rawStatus = map['inspectionStatus'] as String?;
    if (rawStatus != null) {
      status = InspectionStatus.values.firstWhere(
        (value) => value.name == rawStatus,
        orElse: () => InspectionStatus.notChecked,
      );
    }

    SeverityLevel severity = SeverityLevel.none;
    final rawSeverity = map['severity'] as String?;
    if (rawSeverity != null) {
      severity = SeverityLevel.values.firstWhere(
        (value) => value.name == rawSeverity || value.labelVi == rawSeverity,
        orElse: () => SeverityLevel.none,
      );
    }

    final rawPhotos = map['photos'] as List<dynamic>? ?? <dynamic>[];

    return CabinetRecord(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      latitudeRef: (map['latitudeRef'] as num?)?.toDouble() ?? 0,
      longitudeRef: (map['longitudeRef'] as num?)?.toDouble() ?? 0,
      route: map['route'] as String? ?? '',
      latitudeActual: (map['latitudeActual'] as num?)?.toDouble(),
      longitudeActual: (map['longitudeActual'] as num?)?.toDouble(),
      distanceToUserMeters: (map['distanceToUserMeters'] as num?)?.toDouble(),
      coordinateDeviationMeters: (map['coordinateDeviationMeters'] as num?)
          ?.toDouble(),
      inspectionStatus: status,
      wrongPosition: map['wrongPosition'] as bool? ?? false,
      hangingCable: map['hangingCable'] as bool? ?? false,
      unfixedCable: map['unfixedCable'] as bool? ?? false,
      otherIssue: map['otherIssue'] as bool? ?? false,
      otherIssueType: map['otherIssueType'] as String? ?? '',
      isPassed: map['isPassed'] as bool? ?? false,
      severity: severity,
      notes: map['notes'] as String? ?? '',
      inspectorName: map['inspectorName'] as String? ?? '',
      lastCheckedAt: DateTime.tryParse(map['lastCheckedAt'] as String? ?? ''),
      photos: rawPhotos
          .whereType<Map>()
          .map((item) => CabinetPhoto.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  static String encodeList(List<CabinetRecord> records) {
    return jsonEncode(records.map((record) => record.toMap()).toList());
  }

  static List<CabinetRecord> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((item) => CabinetRecord.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
