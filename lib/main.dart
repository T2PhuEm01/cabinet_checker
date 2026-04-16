import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'models/cabinet_dataset.dart';
import 'models/cabinet_record.dart';
import 'pages/cabinet_detail_page.dart';
import 'pages/map_page.dart';
import 'services/export_service.dart';
import 'services/google_sheets_sync_service.dart';
import 'services/kmz_service.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';
import 'services/download_path_service.dart';
import 'utils/location_marker_style.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cabinet Checker',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum ExportRecordStatusFilter { all, checked, notChecked, recheckNeeded }

enum ExportDestination { files, googleSheets }

extension ExportDestinationLabel on ExportDestination {
  String get labelVi {
    switch (this) {
      case ExportDestination.files:
        return 'Tải file về máy';
      case ExportDestination.googleSheets:
        return 'Đẩy lên Google Sheets';
    }
  }
}

extension ExportRecordStatusFilterLabel on ExportRecordStatusFilter {
  String get labelVi {
    switch (this) {
      case ExportRecordStatusFilter.all:
        return 'Tất cả';
      case ExportRecordStatusFilter.checked:
        return 'Đã kiểm';
      case ExportRecordStatusFilter.notChecked:
        return 'Chưa kiểm';
      case ExportRecordStatusFilter.recheckNeeded:
        return 'Cần kiểm lại';
    }
  }
}

class ExportOptions {
  const ExportOptions({
    required this.destination,
    required this.statusFilter,
    required this.imageMode,
    this.appsScriptUrl,
    this.fromDate,
    this.toDate,
  });

  final ExportDestination destination;
  final ExportRecordStatusFilter statusFilter;
  final ExportImageMode imageMode;
  final String? appsScriptUrl;
  final DateTime? fromDate;
  final DateTime? toDate;
}

class _HomePageState extends State<HomePage> {
  final KmzService _kmzService = KmzService();
  final StorageService _storageService = StorageService();
  final LocationService _locationService = LocationService();
  final ExportService _exportService = ExportService();
  final GoogleSheetsSyncService _googleSheetsSyncService =
      GoogleSheetsSyncService();

  List<CabinetDataset> _datasets = <CabinetDataset>[];
  String? _selectedDatasetId;
  List<CabinetRecord> _records = <CabinetRecord>[];
  Position? _currentPosition;
  bool _isBusy = false;
  InspectionStatus? _statusFilter;
  double? _radiusFilter;
  bool _sortAsc = true;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _mapRadiusController = TextEditingController();
  final TextEditingController _mapCabinetIdsController =
      TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  final ScrollController _tableScrollController = ScrollController();
  bool _showScrollToTop = false;
  String _defaultInspectorName = '';
  LocationMarkerIconType _locationIconType = LocationMarkerIconType.pin;
  ExportLocationType _exportLocationType = ExportLocationType.downloads;
  String? _customExportPath;
  String? _googleAppsScriptUrl;
  static const List<double> _columnWidthsDesktop = <double>[
    48, // Icon vi tri
    56, // STT
    140, // Ma tu
    200, // Ten tu
    130, // Lat
    130, // Lng
    120, // Khoang cach
    100, // Sai so
    120, // Trang thai
    100, // Muc do
    70, // Anh
  ];

  static const List<double> _columnWidthsTablet = <double>[
    44, // Icon vi tri
    50, // STT
    110, // Ma tu
    150, // Ten tu
    100, // Lat
    100, // Lng
    100, // Khoang cach
    80, // Sai so
    100, // Trang thai
    80, // Muc do
    60, // Anh
  ];

  static const List<double> _columnWidthsMobile = <double>[
    40, // Icon vi tri
    40, // STT
    80, // Ma tu
    100, // Ten tu
    80, // Lat
    80, // Lng
    80, // Khoang cach
    70, // Sai so
    80, // Trang thai
    70, // Muc do
    50, // Anh
  ];

  @override
  void initState() {
    super.initState();
    _tableScrollController.addListener(_onTableScroll);
    _initApp();
  }

  Future<void> _initApp() async {
    await _loadSavedData();
    if (!mounted) return;
    await _requestLocationOnStartup();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tableScrollController
      ..removeListener(_onTableScroll)
      ..dispose();
    _searchController.dispose();
    _mapRadiusController.dispose();
    _mapCabinetIdsController.dispose();
    super.dispose();
  }

  void _showStatusMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  List<double> _getResponsiveColumnWidths(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1024) {
      return _columnWidthsDesktop;
    } else if (screenWidth >= 600) {
      return _columnWidthsTablet;
    } else {
      return _columnWidthsMobile;
    }
  }

  bool _isMobileLayout(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  void _onTableScroll() {
    final shouldShow =
        _tableScrollController.hasClients &&
        _tableScrollController.offset > 600;
    if (shouldShow != _showScrollToTop && mounted) {
      setState(() {
        _showScrollToTop = shouldShow;
      });
    }
  }

  Future<void> _loadSavedData() async {
    setState(() {
      _isBusy = true;
    });
    final workspace = await _storageService.loadWorkspace();
    final selectedId = workspace.selectedDatasetId;
    final selectedDataset = workspace.datasets
        .cast<CabinetDataset?>()
        .firstWhere(
          (dataset) => dataset?.id == selectedId,
          orElse: () =>
              workspace.datasets.isNotEmpty ? workspace.datasets.first : null,
        );
    setState(() {
      _datasets = workspace.datasets;
      _selectedDatasetId = selectedDataset?.id;
      _records = selectedDataset?.records ?? <CabinetRecord>[];
      _defaultInspectorName = _detectInspectorName(_records);
      _exportLocationType = workspace.exportLocation == 'documents'
          ? ExportLocationType.documents
          : workspace.exportLocation == 'custom'
          ? ExportLocationType.custom
          : ExportLocationType.downloads;
      _customExportPath = workspace.customExportPath;
      _googleAppsScriptUrl = workspace.googleAppsScriptUrl;
      _isBusy = false;
    });
  }

  Future<void> _requestLocationOnStartup() async {
    try {
      _currentPosition = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _calculateDistanceAndSort();
      });
      _showStatusMessage('Đã cấp quyền vị trí và cập nhật khoảng cách.');
    } catch (_) {
      if (!mounted) return;
      _showStatusMessage('Hãy cấp quyền vị trí để sắp xếp tủ gần nhất.');
    }
  }

  Future<void> _importKmz() async {
    setState(() {
      _isBusy = true;
    });
    _showStatusMessage('Đang import KMZ/KML...');
    try {
      final imported = await _kmzService.importKmz();
      if (imported == null) {
        setState(() {
          _isBusy = false;
        });
        _showStatusMessage('Đã huỷ import.');
        return;
      }
      if (imported.records.isEmpty) {
        setState(() {
          _isBusy = false;
        });
        _showStatusMessage('Không có dữ liệu hợp lệ từ file import.');
        return;
      }
      final dataset = CabinetDataset(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: imported.fileName,
        importedAt: DateTime.now(),
        records: imported.records,
      );
      _datasets = <CabinetDataset>[..._datasets, dataset];
      _selectedDatasetId = dataset.id;
      _records = dataset.records;
      if (_currentPosition != null) {
        _calculateDistanceAndSort();
      }
      await _persistWorkspace();
      setState(() {
        _isBusy = false;
      });
      _showStatusMessage(
        'Import file ${dataset.fileName} thành công ${_records.length} tủ.',
      );
    } catch (error) {
      setState(() {
        _isBusy = false;
      });
      _showStatusMessage('Import lỗi: $error');
    }
  }

  Future<void> _refreshCurrentLocation() async {
    setState(() {
      _isBusy = true;
    });
    _showStatusMessage('Đang lấy vị trí hiện tại...');
    try {
      _currentPosition = await _locationService.getCurrentPosition();
      _calculateDistanceAndSort();
      setState(() {
        _isBusy = false;
      });
      _showStatusMessage('Đã cập nhật khoảng cách theo vị trí hiện tại.');
    } catch (error) {
      setState(() {
        _isBusy = false;
      });
      _showStatusMessage('Lỗi vị trí: $error');
    }
  }

  void _calculateDistanceAndSort() {
    if (_currentPosition == null) return;
    for (final record in _records) {
      final distance = _locationService.distanceBetween(
        startLat: _currentPosition!.latitude,
        startLng: _currentPosition!.longitude,
        endLat: record.latitudeRef,
        endLng: record.longitudeRef,
      );
      record.distanceToUserMeters = distance;
      if (record.latitudeActual != null && record.longitudeActual != null) {
        record.coordinateDeviationMeters = _locationService.distanceBetween(
          startLat: record.latitudeRef,
          startLng: record.longitudeRef,
          endLat: record.latitudeActual!,
          endLng: record.longitudeActual!,
        );
      }
    }
    _records.sort((a, b) {
      final ad = a.distanceToUserMeters ?? double.infinity;
      final bd = b.distanceToUserMeters ?? double.infinity;
      return _sortAsc ? ad.compareTo(bd) : bd.compareTo(ad);
    });
  }

  List<CabinetRecord> get _filteredRecords {
    final query = _searchQuery.trim().toLowerCase();
    if (_statusFilter == null && _radiusFilter == null && query.isEmpty) {
      return _records;
    }

    return _records.where((record) {
      final statusOk =
          _statusFilter == null || record.inspectionStatus == _statusFilter;
      final radiusOk =
          _radiusFilter == null ||
          (record.distanceToUserMeters != null &&
              record.distanceToUserMeters! <= _radiusFilter!);
      final searchOk = query.isEmpty || _matchesSearch(record, query);
      return statusOk && radiusOk && searchOk;
    }).toList();
  }

  bool _matchesSearch(CabinetRecord record, String query) {
    bool contains(String value) => value.toLowerCase().contains(query);

    if (contains(record.id) ||
        contains(record.name) ||
        contains(record.route) ||
        contains(record.latitudeRef.toString()) ||
        contains(record.longitudeRef.toString()) ||
        contains(record.latitudeActual?.toString() ?? '') ||
        contains(record.longitudeActual?.toString() ?? '') ||
        contains(_formatMeters(record.distanceToUserMeters)) ||
        contains(_formatMeters(record.coordinateDeviationMeters)) ||
        contains(record.inspectionStatus.labelVi) ||
        contains(record.severity.name) ||
        contains(record.otherIssueType) ||
        contains(record.inspectorName) ||
        contains(record.notes) ||
        contains('${record.photos.length}')) {
      return true;
    }

    if ((record.isPassed && contains('đạt')) ||
        (!record.isPassed && contains('không đạt')) ||
        contains(record.wrongPosition.toString()) ||
        contains(record.hangingCable.toString()) ||
        contains(record.unfixedCable.toString()) ||
        contains(record.otherIssue.toString())) {
      return true;
    }

    return false;
  }

  String _detectInspectorName(List<CabinetRecord> records) {
    for (final record in records) {
      final name = record.inspectorName.trim();
      if (name.isNotEmpty) return name;
    }
    return _defaultInspectorName;
  }

  Future<void> _applyUpdatedRecord(CabinetRecord updated) async {
    final index = _records.indexWhere((item) => item.id == updated.id);
    if (index < 0) return;

    setState(() {
      _records[index] = updated;
      final name = updated.inspectorName.trim();
      if (name.isNotEmpty) {
        _defaultInspectorName = name;
      }
      _calculateDistanceAndSort();
    });

    try {
      await _persistWorkspace();
      _showStatusMessage('Đã lưu cập nhật cho tủ ${updated.name}.');
    } catch (e) {
      _showStatusMessage('Đã cập nhật trên màn hình nhưng lưu cục bộ lỗi: $e');
    }
  }

  List<CabinetRecord> _buildMapRecords() {
    var records = List<CabinetRecord>.from(_filteredRecords);

    final idTokens = _mapCabinetIdsController.text
        .split(RegExp(r'[,;\s]+'))
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (idTokens.isNotEmpty) {
      records = records
          .where(
            (record) => idTokens.any(
              (token) => record.id.trim().toUpperCase().startsWith(token),
            ),
          )
          .toList();
    }

    final customRadius = double.tryParse(_mapRadiusController.text.trim());
    if (customRadius != null && customRadius > 0 && _currentPosition != null) {
      records = records.where((record) {
        final distance = _locationService.distanceBetween(
          startLat: _currentPosition!.latitude,
          startLng: _currentPosition!.longitude,
          endLat: record.latitudeRef,
          endLng: record.longitudeRef,
        );
        return distance <= customRadius;
      }).toList();
    }

    return records;
  }

  Future<void> _openRecordDetail(CabinetRecord record) async {
    final updated = await Navigator.of(context).push<CabinetRecord>(
      MaterialPageRoute(
        builder: (_) => CabinetDetailPage(
          record: record.copyWith(),
          defaultInspectorName: _defaultInspectorName,
        ),
      ),
    );
    if (updated == null) return;

    await _applyUpdatedRecord(updated);
  }

  Future<void> _openMapView() async {
    final customRadius = double.tryParse(_mapRadiusController.text.trim());
    if (customRadius != null && customRadius > 0 && _currentPosition == null) {
      try {
        _currentPosition = await _locationService.getCurrentPosition();
        _calculateDistanceAndSort();
      } catch (_) {
        _showStatusMessage(
          'Chưa lấy được vị trí hiện tại nên không lọc theo bán kính map.',
        );
      }
    }

    final mapRecords = _buildMapRecords();
    if (mapRecords.isEmpty) {
      _showStatusMessage('Không có tủ phù hợp với bộ lọc map hiện tại.');
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MapPage(
          records: mapRecords,
          userPos: _currentPosition,
          defaultInspectorName: _defaultInspectorName,
          markerIconType: _locationIconType,
          onRecordUpdated: _applyUpdatedRecord,
        ),
      ),
    );
  }

  String _formatDateOnly(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(2)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  int _estimateExportTotalBytes(
    List<CabinetRecord> records,
    ExportImageMode imageMode,
  ) {
    final photoCount = records.fold<int>(
      0,
      (sum, record) => sum + record.photos.length,
    );
    final baseBytes = 600 * 1024;
    final perRecordBytes = records.length * 12 * 1024;
    final perPhotoBytes = switch (imageMode) {
      ExportImageMode.original => photoCount * 420 * 1024,
      ExportImageMode.balanced => photoCount * 240 * 1024,
      ExportImageMode.compact => photoCount * 130 * 1024,
    };
    return baseBytes + perRecordBytes + perPhotoBytes;
  }

  Future<int> _estimateGoogleSyncBytes(List<CabinetRecord> records) async {
    var total = 350 * 1024;
    for (final record in records) {
      total += 12 * 1024;
      for (final photo in record.photos) {
        final file = File(photo.path);
        if (!file.existsSync()) continue;
        final length = await file.length();
        total += (length * 1.4).round();
      }
    }
    return total;
  }

  String _buildExportProgressLabel(String step, int processed, int total) {
    final safeTotal = total <= 0 ? 1 : total;
    final safeProcessed = processed.clamp(0, safeTotal);
    final percent = (safeProcessed / safeTotal) * 100;
    return '$step\n'
        '${_formatBytes(safeProcessed)}/${_formatBytes(safeTotal)} '
        '(${percent.toStringAsFixed(0)}%)';
  }

  Future<ExportOptions?> _showExportOptionsDialog() async {
    ExportDestination destination = ExportDestination.files;
    ExportRecordStatusFilter statusFilter = ExportRecordStatusFilter.all;
    ExportImageMode imageMode = ExportImageMode.balanced;
    DateTime? fromDate;
    DateTime? toDate;
    String appsScriptUrlValue = _googleAppsScriptUrl ?? '';

    final result = await showDialog<ExportOptions>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickFromDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: fromDate ?? now,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked == null) return;
              setDialogState(() {
                fromDate = picked;
                if (toDate != null && toDate!.isBefore(fromDate!)) {
                  toDate = fromDate;
                }
              });
            }

            Future<void> pickToDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: toDate ?? fromDate ?? now,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked == null) return;
              setDialogState(() {
                toDate = picked;
                if (fromDate != null && toDate!.isBefore(fromDate!)) {
                  fromDate = toDate;
                }
              });
            }

            return AlertDialog(
              title: const Text('Tùy chọn xuất báo cáo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<ExportDestination>(
                      value: destination,
                      decoration: const InputDecoration(
                        labelText: 'Nơi xuất dữ liệu',
                      ),
                      items: ExportDestination.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.labelVi),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => destination = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ExportRecordStatusFilter>(
                      value: statusFilter,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái xuất',
                      ),
                      items: ExportRecordStatusFilter.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.labelVi),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => statusFilter = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (destination == ExportDestination.files) ...[
                      DropdownButtonFormField<ExportImageMode>(
                        value: imageMode,
                        decoration: const InputDecoration(
                          labelText: 'Chế độ ảnh trong XLSX',
                        ),
                        items: ExportImageMode.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.labelVi),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => imageMode = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      TextFormField(
                        initialValue: appsScriptUrlValue,
                        decoration: const InputDecoration(
                          labelText: 'URL Google Apps Script (/exec)',
                          hintText:
                              'https://script.google.com/macros/s/.../exec',
                        ),
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        onChanged: (value) => appsScriptUrlValue = value,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ảnh gốc sẽ gửi lên Apps Script để lưu Drive, không bị giảm chất lượng như XLSX.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Từ ngày'),
                      subtitle: Text(
                        fromDate == null
                            ? 'Không giới hạn'
                            : _formatDateOnly(fromDate!),
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Xóa',
                            onPressed: () =>
                                setDialogState(() => fromDate = null),
                            icon: const Icon(Icons.clear),
                          ),
                          IconButton(
                            tooltip: 'Chọn ngày',
                            onPressed: pickFromDate,
                            icon: const Icon(Icons.calendar_month),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Đến ngày'),
                      subtitle: Text(
                        toDate == null
                            ? 'Không giới hạn'
                            : _formatDateOnly(toDate!),
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Xóa',
                            onPressed: () =>
                                setDialogState(() => toDate = null),
                            icon: const Icon(Icons.clear),
                          ),
                          IconButton(
                            tooltip: 'Chọn ngày',
                            onPressed: pickToDate,
                            icon: const Icon(Icons.calendar_month),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    final scriptUrl = appsScriptUrlValue.trim();
                    if (destination == ExportDestination.googleSheets &&
                        scriptUrl.isEmpty) {
                      _showStatusMessage(
                        'Vui lòng nhập URL Google Apps Script.',
                      );
                      return;
                    }

                    Navigator.of(context).pop(
                      ExportOptions(
                        destination: destination,
                        statusFilter: statusFilter,
                        imageMode: imageMode,
                        appsScriptUrl: scriptUrl.isEmpty ? null : scriptUrl,
                        fromDate: fromDate,
                        toDate: toDate,
                      ),
                    );
                  },
                  child: const Text('Xuất'),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  List<CabinetRecord> _buildExportRecords(ExportOptions options) {
    DateTime? fromBoundary;
    DateTime? toBoundary;
    if (options.fromDate != null) {
      fromBoundary = DateTime(
        options.fromDate!.year,
        options.fromDate!.month,
        options.fromDate!.day,
      );
    }
    if (options.toDate != null) {
      toBoundary = DateTime(
        options.toDate!.year,
        options.toDate!.month,
        options.toDate!.day,
        23,
        59,
        59,
        999,
      );
    }

    return _records.where((record) {
      final statusMatch = switch (options.statusFilter) {
        ExportRecordStatusFilter.all => true,
        ExportRecordStatusFilter.checked =>
          record.inspectionStatus == InspectionStatus.checked,
        ExportRecordStatusFilter.notChecked =>
          record.inspectionStatus == InspectionStatus.notChecked,
        ExportRecordStatusFilter.recheckNeeded =>
          record.inspectionStatus == InspectionStatus.recheckNeeded,
      };

      if (!statusMatch) return false;

      if (fromBoundary == null && toBoundary == null) {
        return true;
      }

      final checkedAt = record.lastCheckedAt;
      if (checkedAt == null) return false;

      if (fromBoundary != null && checkedAt.isBefore(fromBoundary)) {
        return false;
      }
      if (toBoundary != null && checkedAt.isAfter(toBoundary)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _exportReports() async {
    final options = await _showExportOptionsDialog();
    if (options == null) return;

    final exportRecords = _buildExportRecords(options);
    if (exportRecords.isEmpty) {
      _showStatusMessage('Không có dữ liệu phù hợp với điều kiện xuất.');
      return;
    }

    setState(() {
      _isBusy = true;
    });

    final estimatedTotalBytes = options.destination == ExportDestination.files
        ? _estimateExportTotalBytes(exportRecords, options.imageMode)
        : await _estimateGoogleSyncBytes(exportRecords);

    final progress = ValueNotifier<double>(0.0);
    final displayedBytes = ValueNotifier<int>(
      (estimatedTotalBytes * 0.05).round(),
    );
    final progressLabel = ValueNotifier<String>(
      _buildExportProgressLabel(
        'Khởi tạo xuất dữ liệu...',
        displayedBytes.value,
        estimatedTotalBytes,
      ),
    );

    bool progressDialogShown = false;

    if (mounted) {
      progressDialogShown = true;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: const Text('Đang xuất báo cáo'),
              content: ValueListenableBuilder<String>(
                valueListenable: progressLabel,
                builder: (context, label, __) {
                  return ValueListenableBuilder<double>(
                    valueListenable: progress,
                    builder: (context, value, ___) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(value: value),
                          const SizedBox(height: 12),
                          Text(label),
                          const SizedBox(height: 6),
                          const Text(
                            'Bạn có thể đưa app xuống nền, tác vụ vẫn tiếp tục xử lý.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    try {
      progress.value = 0.05;
      progressLabel.value = _buildExportProgressLabel(
        options.destination == ExportDestination.files
            ? 'Đang chuẩn bị ${exportRecords.length} bản ghi...'
            : 'Đang chuẩn bị đồng bộ ${exportRecords.length} bản ghi...',
        displayedBytes.value,
        estimatedTotalBytes,
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      if (options.destination == ExportDestination.files) {
        final (csvPath, xlsxPath) = await _exportService.exportRecords(
          exportRecords,
          _exportLocationType,
          customPath: _customExportPath,
          imageMode: options.imageMode,
          onProgress: (event) {
            final value = event.value.clamp(0.0, 0.96);
            progress.value = value;
            displayedBytes.value = (estimatedTotalBytes * value).round();
            progressLabel.value = _buildExportProgressLabel(
              event.message,
              displayedBytes.value,
              estimatedTotalBytes,
            );
          },
        );

        final csvSize = await File(csvPath).length();
        final xlsxSize = await File(xlsxPath).length();
        final totalActualBytes = csvSize + xlsxSize;
        final totalDisplayBytes = totalActualBytes > estimatedTotalBytes
            ? totalActualBytes
            : estimatedTotalBytes;

        displayedBytes.value = totalActualBytes;
        progress.value = (displayedBytes.value / totalDisplayBytes).clamp(
          0.0,
          0.98,
        );
        progressLabel.value = _buildExportProgressLabel(
          'Đang tính kích thước file...',
          displayedBytes.value,
          totalDisplayBytes,
        );

        await Future<void>.delayed(const Duration(milliseconds: 180));
        displayedBytes.value = totalDisplayBytes;
        progress.value = 1.0;
        progressLabel.value = _buildExportProgressLabel(
          'Đang hoàn tất xuất báo cáo...',
          totalDisplayBytes,
          totalDisplayBytes,
        );

        progressLabel.value = _buildExportProgressLabel(
          'Hoàn tất xuất báo cáo.',
          totalDisplayBytes,
          totalDisplayBytes,
        );

        if (progressDialogShown && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        final fileLog =
            '[EXPORT_SUCCESS][FILES] records=${exportRecords.length}, '
            'csv=$csvPath (${_formatBytes(csvSize)}), '
            'xlsx=$xlsxPath (${_formatBytes(xlsxSize)})';
        debugPrint(fileLog);
        print(fileLog);

        _showStatusMessage(
          'Đã xuất thành công ${exportRecords.length} bản ghi (CSV + XLSX).',
        );
      } else {
        final appsScriptUrl = options.appsScriptUrl?.trim() ?? '';
        if (appsScriptUrl.isEmpty) {
          throw StateError('Thiếu URL Google Apps Script để đồng bộ.');
        }

        final uploadedCount = await _googleSheetsSyncService.syncRecords(
          appsScriptUrl: appsScriptUrl,
          records: exportRecords,
          onProgress: (event) {
            final value = event.value.clamp(0.0, 0.98);
            progress.value = value;
            displayedBytes.value = (estimatedTotalBytes * value).round();
            progressLabel.value = _buildExportProgressLabel(
              event.message,
              displayedBytes.value,
              estimatedTotalBytes,
            );
          },
        );

        _googleAppsScriptUrl = appsScriptUrl;
        await _persistWorkspace();

        displayedBytes.value = estimatedTotalBytes;
        progress.value = 1.0;
        progressLabel.value = _buildExportProgressLabel(
          'Hoàn tất đồng bộ Google Sheets.',
          estimatedTotalBytes,
          estimatedTotalBytes,
        );

        if (progressDialogShown && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        final sheetsLog =
            '[EXPORT_SUCCESS][GOOGLE_SHEETS] '
            'records=$uploadedCount/${exportRecords.length}, '
            'appsScriptUrl=$appsScriptUrl';
        debugPrint(sheetsLog);
        print(sheetsLog);

        _showStatusMessage(
          'Đã đồng bộ Google Sheets thành công: $uploadedCount/${exportRecords.length} bản ghi.',
        );
      }
    } catch (e, st) {
      final errorLog =
          '[EXPORT_ERROR][${options.destination.name}] error=$e\nstack=$st';
      debugPrint(errorLog);
      print(errorLog);
      if (progressDialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showStatusMessage(
        options.destination == ExportDestination.files
            ? 'Xuất file thất bại: $e\nHãy chọn lại nơi lưu ở nút thư mục xuất.'
            : 'Đồng bộ Google Sheets thất bại: $e\nHãy kiểm tra lại URL Apps Script và quyền truy cập.',
      );
    } finally {
      progress.dispose();
      displayedBytes.dispose();
      progressLabel.dispose();
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _persistWorkspace() async {
    _updateSelectedDatasetRecords();
    await _storageService.saveWorkspace(
      CabinetWorkspaceState(
        datasets: _datasets,
        selectedDatasetId: _selectedDatasetId,
        exportLocation: _exportLocationType == ExportLocationType.documents
            ? 'documents'
            : _exportLocationType == ExportLocationType.custom
            ? 'custom'
            : 'downloads',
        customExportPath: _customExportPath,
        googleAppsScriptUrl: _googleAppsScriptUrl,
      ),
    );
  }

  Future<void> _chooseExportLocation() async {
    final selected = await showModalBottomSheet<String>(
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Lưu vào Download/cabinet_checker/exports'),
                trailing: _exportLocationType == ExportLocationType.downloads
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => Navigator.of(context).pop('downloads'),
              ),
              ListTile(
                title: const Text('Lưu vào Documents/cabinet_checker/exports'),
                trailing: _exportLocationType == ExportLocationType.documents
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => Navigator.of(context).pop('documents'),
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: Text(
                  _customExportPath == null
                      ? 'Chọn folder tùy ý'
                      : 'Đã chọn: $_customExportPath',
                ),
                trailing: _exportLocationType == ExportLocationType.custom
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickExportFolder();
                },
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;

    if (selected == 'downloads') {
      setState(() {
        _exportLocationType = ExportLocationType.downloads;
        _customExportPath = null;
      });
      _showStatusMessage('Đã chuyển nơi lưu export sang Download.');
    } else if (selected == 'documents') {
      setState(() {
        _exportLocationType = ExportLocationType.documents;
        _customExportPath = null;
      });
      _showStatusMessage('Đã chuyển nơi lưu export sang Documents.');
    }

    await _persistWorkspace();
  }

  Future<void> _pickExportFolder() async {
    final folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null) return;

    setState(() {
      _exportLocationType = ExportLocationType.custom;
      _customExportPath = folderPath;
    });
    _showStatusMessage('Đã chọn folder: $folderPath');
    await _persistWorkspace();
  }

  void _updateSelectedDatasetRecords() {
    if (_selectedDatasetId == null) return;
    final idx = _datasets.indexWhere(
      (dataset) => dataset.id == _selectedDatasetId,
    );
    if (idx < 0) return;
    final current = _datasets[idx];
    _datasets[idx] = CabinetDataset(
      id: current.id,
      fileName: current.fileName,
      importedAt: current.importedAt,
      records: List<CabinetRecord>.from(_records),
    );
  }

  void _selectDataset(String datasetId) {
    final dataset = _datasets.firstWhere((item) => item.id == datasetId);
    setState(() {
      _selectedDatasetId = datasetId;
      _records = List<CabinetRecord>.from(dataset.records);
      _defaultInspectorName = _detectInspectorName(_records);
      if (_currentPosition != null) {
        _calculateDistanceAndSort();
      }
    });
    _showStatusMessage('Đang dùng file: ${dataset.fileName}');
    _persistWorkspace();
  }

  Future<void> _deleteDataset(String datasetId) async {
    final deleting = _datasets.firstWhere((item) => item.id == datasetId);
    _datasets.removeWhere((item) => item.id == datasetId);
    if (_selectedDatasetId == datasetId) {
      _selectedDatasetId = _datasets.isNotEmpty ? _datasets.first.id : null;
      _records = _datasets.isNotEmpty
          ? List<CabinetRecord>.from(_datasets.first.records)
          : <CabinetRecord>[];
      _defaultInspectorName = _detectInspectorName(_records);
    }
    await _persistWorkspace();
    setState(() {});
    _showStatusMessage('Đã xóa file ${deleting.fileName}');
  }

  void _showDatasetManager() {
    showModalBottomSheet<void>(
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Quản lý tệp dữ liệu')),
              if (_datasets.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Chưa có file nào được import.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    shrinkWrap: true,
                    itemCount: _datasets.length,
                    itemBuilder: (context, index) {
                      final dataset = _datasets[index];
                      final isSelected = dataset.id == _selectedDatasetId;
                      return ListTile(
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.insert_drive_file,
                        ),
                        title: Text(dataset.fileName),
                        subtitle: Text('${dataset.records.length} tủ'),
                        onTap: () {
                          Navigator.of(context).pop();
                          _selectDataset(dataset.id);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _deleteDataset(dataset.id);
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatMeters(double? value) {
    if (value == null) return '-';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)} km';
    return '${value.toStringAsFixed(0)} m';
  }

  double _getTableWidth(BuildContext context) {
    final widths = _getResponsiveColumnWidths(context);
    return widths.reduce((a, b) => a + b);
  }

  Widget _buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      height: 44,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _buildDataCell(String text, double width) {
    return Container(
      width: width,
      height: 42,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildLocationStatusCell(CabinetRecord item, double width) {
    final style = getLocationMarkerStyle(item);

    return Container(
      width: width,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Tooltip(
        message: style.statusLabel,
        child: Icon(_locationIconType.iconData, size: 18, color: style.color),
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final widths = _getResponsiveColumnWidths(context);
    return Row(
      children: [
        _buildHeaderCell('', widths[0]),
        _buildHeaderCell('STT', widths[1]),
        _buildHeaderCell('Mã tủ', widths[2]),
        _buildHeaderCell('Tên tủ', widths[3]),
        _buildHeaderCell('Lat chuẩn', widths[4]),
        _buildHeaderCell('Lng chuẩn', widths[5]),
        _buildHeaderCell('Khoảng cách', widths[6]),
        _buildHeaderCell('Sai số', widths[7]),
        _buildHeaderCell('Trạng thái', widths[8]),
        _buildHeaderCell('Mức độ', widths[9]),
        _buildHeaderCell('Ảnh', widths[10]),
      ],
    );
  }

  Widget _buildTableRow(BuildContext context, int index, CabinetRecord item) {
    final widths = _getResponsiveColumnWidths(context);
    return RepaintBoundary(
      child: InkWell(
        key: ValueKey(item.id),
        onTap: () => _openRecordDetail(item),
        child: Row(
          children: [
            _buildLocationStatusCell(item, widths[0]),
            _buildDataCell('${index + 1}', widths[1]),
            _buildDataCell(item.id, widths[2]),
            _buildDataCell(item.name, widths[3]),
            _buildDataCell(item.latitudeRef.toStringAsFixed(6), widths[4]),
            _buildDataCell(item.longitudeRef.toStringAsFixed(6), widths[5]),
            _buildDataCell(_formatMeters(item.distanceToUserMeters), widths[6]),
            _buildDataCell(
              _formatMeters(item.coordinateDeviationMeters),
              widths[7],
            ),
            _buildDataCell(item.inspectionStatus.labelVi, widths[8]),
            _buildDataCell(item.severity.name, widths[9]),
            _buildDataCell('${item.photos.length}', widths[10]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRecords;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Cabinet Checker'),
        actions: [
          IconButton(
            tooltip: 'Quản lý file',
            onPressed: _showDatasetManager,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            tooltip: 'Map',
            onPressed: rows.isEmpty ? null : _openMapView,
            icon: const Icon(Icons.map),
          ),
          IconButton(
            tooltip: 'Vị trí hiện tại',
            onPressed: _isBusy ? null : _refreshCurrentLocation,
            icon: const Icon(Icons.my_location),
          ),
          IconButton(
            tooltip: 'Nơi lưu export',
            onPressed: _chooseExportLocation,
            icon: const Icon(Icons.folder_zip),
          ),
          IconButton(
            tooltip: 'Xuất báo cáo',
            onPressed: _isBusy || _records.isEmpty ? null : _exportReports,
            icon: const Icon(Icons.file_download),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_showScrollToTop)
            FloatingActionButton.small(
              heroTag: 'scrollToTop',
              onPressed: () {
                if (_tableScrollController.hasClients) {
                  _tableScrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                  );
                }
              },
              child: const Icon(Icons.keyboard_double_arrow_up),
            ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'importFile',
            onPressed: _isBusy ? null : _importKmz,
            child: const Icon(Icons.upload_file),
          ),
        ],
      ),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            if (_isBusy) const LinearProgressIndicator(),
            Padding(
              padding: EdgeInsets.all(_isMobileLayout(context) ? 6 : 8),
              child: Column(
                children: [
                  Wrap(
                    spacing: _isMobileLayout(context) ? 4 : 8,
                    runSpacing: _isMobileLayout(context) ? 6 : 8,
                    alignment: WrapAlignment.start,
                    children: [
                      DropdownButton<InspectionStatus?>(
                        value: _statusFilter,
                        hint: Text(
                          _isMobileLayout(context) ? 'Tất cả' : 'Tất cả',
                          style: TextStyle(
                            fontSize: _isMobileLayout(context) ? 12 : 14,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tất cả')),
                          DropdownMenuItem(
                            value: InspectionStatus.notChecked,
                            child: Text('Chưa kiểm'),
                          ),
                          DropdownMenuItem(
                            value: InspectionStatus.checked,
                            child: Text('Đã kiểm'),
                          ),
                          DropdownMenuItem(
                            value: InspectionStatus.recheckNeeded,
                            child: Text('Cần kiểm lại'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _statusFilter = value),
                      ),
                      DropdownButton<double?>(
                        value: _radiusFilter,
                        hint: Text(
                          'Mọi khoảng cách',
                          style: TextStyle(
                            fontSize: _isMobileLayout(context) ? 12 : 14,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('Mọi khoảng cách'),
                          ),
                          DropdownMenuItem(value: 300, child: Text('<= 300 m')),
                          DropdownMenuItem(value: 500, child: Text('<= 500 m')),
                          DropdownMenuItem(value: 1000, child: Text('<= 1 km')),
                        ],
                        onChanged: (value) =>
                            setState(() => _radiusFilter = value),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _sortAsc = !_sortAsc;
                            _calculateDistanceAndSort();
                          });
                        },
                        icon: Icon(
                          _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                          size: _isMobileLayout(context) ? 16 : 18,
                        ),
                        label: Text(
                          _isMobileLayout(context)
                              ? 'Sort'
                              : 'Sort khoảng cách',
                          style: TextStyle(
                            fontSize: _isMobileLayout(context) ? 12 : 14,
                          ),
                        ),
                      ),
                      DropdownButton<LocationMarkerIconType>(
                        value: _locationIconType,
                        items: LocationMarkerIconType.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _locationIconType = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 220),
                          () {
                            if (!mounted) return;
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        );
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Tìm theo mã/tên/tuyến...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchDebounce?.cancel();
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                icon: const Icon(Icons.clear),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _mapRadiusController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Bán kính map (m), ví dụ 200',
                            prefixIcon: const Icon(Icons.radio_button_checked),
                            suffixIcon: _mapRadiusController.text.trim().isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _mapRadiusController.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.clear),
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _mapCabinetIdsController,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Mã tủ map: TNH0062, TNH0039',
                            prefixIcon: const Icon(Icons.tag),
                            suffixIcon:
                                _mapCabinetIdsController.text.trim().isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _mapCabinetIdsController.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.clear),
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có dữ liệu. Bấm nút upload để import KMZ/KML.',
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        width: _getTableWidth(context),
                        child: Column(
                          children: [
                            _buildTableHeader(context),
                            Expanded(
                              child: ListView.builder(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                addAutomaticKeepAlives: false,
                                addRepaintBoundaries: true,
                                cacheExtent: 600,
                                controller: _tableScrollController,
                                itemExtent: 42,
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  final item = rows[index];
                                  return _buildTableRow(context, index, item);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
