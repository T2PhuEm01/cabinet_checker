import 'cabinet_record.dart';

class CabinetDataset {
  CabinetDataset({
    required this.id,
    required this.fileName,
    required this.importedAt,
    required this.records,
  });

  final String id;
  final String fileName;
  final DateTime importedAt;
  final List<CabinetRecord> records;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'importedAt': importedAt.toIso8601String(),
      'records': records.map((record) => record.toMap()).toList(),
    };
  }

  factory CabinetDataset.fromMap(Map<String, dynamic> map) {
    final rawRecords = map['records'] as List<dynamic>? ?? <dynamic>[];
    return CabinetDataset(
      id: map['id'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      importedAt:
          DateTime.tryParse(map['importedAt'] as String? ?? '') ??
          DateTime.now(),
      records: rawRecords
          .whereType<Map<String, dynamic>>()
          .map(CabinetRecord.fromMap)
          .toList(),
    );
  }
}

class CabinetWorkspaceState {
  CabinetWorkspaceState({
    required this.datasets,
    this.selectedDatasetId,
    this.exportLocation = 'downloads',
    this.customExportPath,
    this.googleAppsScriptUrl,
  });

  final List<CabinetDataset> datasets;
  final String? selectedDatasetId;
  final String exportLocation;
  final String? customExportPath;
  final String? googleAppsScriptUrl;

  Map<String, dynamic> toMap() {
    return {
      'selectedDatasetId': selectedDatasetId,
      'exportLocation': exportLocation,
      'customExportPath': customExportPath,
      'googleAppsScriptUrl': googleAppsScriptUrl,
      'datasets': datasets.map((dataset) => dataset.toMap()).toList(),
    };
  }

  factory CabinetWorkspaceState.fromMap(Map<String, dynamic> map) {
    final rawDatasets = map['datasets'] as List<dynamic>? ?? <dynamic>[];
    return CabinetWorkspaceState(
      selectedDatasetId: map['selectedDatasetId'] as String?,
      exportLocation: map['exportLocation'] as String? ?? 'downloads',
      customExportPath: map['customExportPath'] as String?,
      googleAppsScriptUrl: map['googleAppsScriptUrl'] as String?,
      datasets: rawDatasets
          .whereType<Map<String, dynamic>>()
          .map(CabinetDataset.fromMap)
          .toList(),
    );
  }
}
