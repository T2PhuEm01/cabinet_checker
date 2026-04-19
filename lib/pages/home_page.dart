import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:cabinet_checker/controllers/home_controller.dart';
import 'package:cabinet_checker/models/cabinet_dataset.dart';
import 'package:cabinet_checker/models/cabinet_record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cabinet_checker/services/location_service.dart';
import 'package:cabinet_checker/utils/button_util.dart';
import 'package:cabinet_checker/utils/colors.dart';
import 'package:cabinet_checker/utils/common_utils.dart';
import 'package:cabinet_checker/utils/dimens.dart';
import 'package:cabinet_checker/utils/location_marker_style.dart';
import 'package:cabinet_checker/utils/spacers.dart';
import 'package:cabinet_checker/utils/text_field_util.dart';
import 'package:cabinet_checker/utils/text_util.dart';
import 'package:cabinet_checker/widgets/cabinet_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../services/export_cancel_token.dart';
import '../services/download_path_service.dart';
import '../services/google_sheets_sync_service.dart';
import '../services/storage_service.dart';
import 'cabinet_detail_page.dart';
import 'export/export_options_dialog.dart';
import 'home_dataset_manager.dart';
import 'home_location_manager.dart';
import 'home_table_sort_manager.dart';
import 'map_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final HomeController _controller = Get.put(HomeController());
  final GoogleSheetsSyncService _googleSheetsSyncService =
      GoogleSheetsSyncService();
  final DownloadPathService _downloadPathService = DownloadPathService();
  final StorageService _storageService = StorageService();

  static const List<String> _statusFilterLabels = <String>[
    'Tất cả',
    'Chưa kiểm',
    'Đã kiểm',
    'Cần kiểm lại',
  ];

  static const List<InspectionStatus?> _statusFilterValues =
      <InspectionStatus?>[
        null,
        InspectionStatus.notChecked,
        InspectionStatus.checked,
        InspectionStatus.recheckNeeded,
      ];

  static const List<double> _columnWidths = <double>[
    48,
    56,
    230,
    130,
    130,
    120,
    100,
    120,
    100,
    70,
  ];

  final ScrollController _tableScrollController = ScrollController();
  final List<CabinetRecord> _records = <CabinetRecord>[];
  final List<CabinetDataset> _datasets = <CabinetDataset>[];
  Position? _currentPosition;
  HomeTableSortState _tableSortState = const HomeTableSortState.none();

  InspectionStatus? _statusFilter;
  String? _selectedDatasetId;
  bool _isBusy = false;
  bool _isExportingInProgress = false;
  ExportCancelToken? _activeExportCancelToken;
  String? _googleAppsScriptUrl;
  final LocationMarkerIconType _locationIconType = LocationMarkerIconType.pin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureLocationPermissionOnEntry());
    });
    _loadSavedData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.searchController.removeListener(_onSearchChanged);
    _tableScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_ensureLocationPermissionOnEntry());
    }
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _showStatusMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _ensureLocationPermissionOnEntry() async {
    final permissionState = await _controller.ensureLocationPermission();
    if (!mounted) return;

    switch (permissionState) {
      case LocationPermissionState.granted:
        return;
      case LocationPermissionState.serviceDisabled:
        _showStatusMessage('Vui lòng bật dịch vụ vị trí để dùng bản đồ.');
        return;
      case LocationPermissionState.denied:
        _showStatusMessage(
          'Bạn cần cấp quyền vị trí để dùng đầy đủ chức năng.',
        );
        return;
      case LocationPermissionState.deniedForever:
        await _showLocationPermissionDialog();
        return;
    }
  }

  Future<void> _showLocationPermissionDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cần quyền vị trí'),
          content: const Text(
            'Ứng dụng cần quyền vị trí để đo khoảng cách và hiển thị bản đồ. '
            'Hãy mở cài đặt và bật quyền vị trí cho ứng dụng.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () async {
                await Geolocator.openAppSettings();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Mở cài đặt'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSavedData() async {
    final workspace = await _storageService.loadWorkspace();
    final selectedDataset = workspace.datasets.isEmpty
        ? null
        : workspace.datasets.firstWhere(
            (dataset) => dataset.id == workspace.selectedDatasetId,
            orElse: () => workspace.datasets.first,
          );

    if (!mounted) return;

    setState(() {
      _datasets
        ..clear()
        ..addAll(workspace.datasets);
      _selectedDatasetId = selectedDataset?.id;
      _records
        ..clear()
        ..addAll(selectedDataset?.records ?? <CabinetRecord>[]);
      _googleAppsScriptUrl = workspace.googleAppsScriptUrl;
    });
  }

  Future<void> _persistWorkspace() async {
    final workspace = _buildWorkspaceState();
    await _storageService.saveWorkspace(workspace);
    await _writeAutoBackupFile(workspace);
  }

  CabinetWorkspaceState _buildWorkspaceState() {
    return CabinetWorkspaceState(
      datasets: _datasets,
      selectedDatasetId: _selectedDatasetId,
      googleAppsScriptUrl: _googleAppsScriptUrl,
    );
  }

  Future<File> _writeAutoBackupFile(CabinetWorkspaceState workspace) async {
    final backupDir = await _downloadPathService.getCabinetSubDirectory(
      'backups',
    );
    final fileName = 'cabinet_workspace_autosave.json';
    final backupFile = File('${backupDir.path}/$fileName');
    await backupFile.writeAsString(jsonEncode(workspace.toMap()), flush: true);
    return backupFile;
  }

  Future<File> _writeManualBackupFile(CabinetWorkspaceState workspace) async {
    final backupDir = await _downloadPathService.getCabinetSubDirectory(
      'backups',
    );
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final fileName = 'cabinet_workspace_backup_$stamp.json';
    final backupFile = File('${backupDir.path}/$fileName');
    await backupFile.writeAsString(jsonEncode(workspace.toMap()), flush: true);
    return backupFile;
  }

  Future<void> _restoreWorkspaceFromBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
      withData: true,
    );

    final file = result?.files.single;
    if (file == null) {
      _showStatusMessage('Đã hủy khôi phục dữ liệu.');
      return;
    }

    final raw = file.bytes != null
        ? utf8.decode(file.bytes!)
        : file.path != null
        ? await File(file.path!).readAsString()
        : null;
    if (raw == null || raw.trim().isEmpty) {
      _showStatusMessage('Không đọc được file backup đã chọn.');
      return;
    }

    CabinetWorkspaceState? workspace;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        workspace = CabinetWorkspaceState.fromMap(decoded);
      } else if (decoded is Map) {
        workspace = CabinetWorkspaceState.fromMap(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      workspace = null;
    }

    if (workspace == null) {
      _showStatusMessage('File backup không hợp lệ.');
      return;
    }

    final selectedDataset = workspace.datasets.isEmpty
        ? null
        : workspace.datasets.firstWhere(
            (dataset) => dataset.id == workspace?.selectedDatasetId,
            orElse: () => workspace!.datasets.first,
          );

    if (!mounted) return;

    setState(() {
      _datasets
        ..clear()
        ..addAll(workspace!.datasets);
      _selectedDatasetId = selectedDataset?.id;
      _records
        ..clear()
        ..addAll(selectedDataset?.records ?? <CabinetRecord>[]);
      _googleAppsScriptUrl = workspace?.googleAppsScriptUrl;
    });

    await _persistWorkspace();
    _showStatusMessage('Đã khôi phục ${_datasets.length} file từ backup.');
  }

  Future<void> _importKmz() async {
    setState(() {
      _isBusy = true;
    });

    final result = await _controller.importKmz();

    if (result.status == ImportKmzStatus.canceled) {
      setState(() => _isBusy = false);
      _showStatusMessage('Đã hủy import.');
      return;
    }

    if (result.status == ImportKmzStatus.empty) {
      setState(() => _isBusy = false);
      _showStatusMessage('Không có dữ liệu hợp lệ từ file import.');
      return;
    }

    if (result.status == ImportKmzStatus.error || result.dataset == null) {
      setState(() => _isBusy = false);
      _showStatusMessage('Import lỗi: ${result.error ?? 'Unknown error'}');
      return;
    }

    setState(() {
      _datasets.add(result.dataset!);
      _selectedDatasetId = result.dataset!.id;
      _records
        ..clear()
        ..addAll(result.dataset!.records);
      _isBusy = false;
    });

    await _persistWorkspace();

    _showStatusMessage(
      'Import ${result.dataset!.fileName} thành công ${_records.length} tủ.',
    );
  }

  List<CabinetRecord> get _filteredRecords {
    final query = _controller.searchController.text.trim().toLowerCase();

    final filtered = _records.where((record) {
      final statusOk =
          _statusFilter == null || record.inspectionStatus == _statusFilter;
      if (!statusOk) return false;

      if (query.isEmpty) return true;
      final searchText = '${record.id} ${record.name} ${record.route}'
          .toLowerCase();
      return searchText.contains(query);
    }).toList();

    return HomeTableSortManager.applySort(
      records: filtered,
      state: _tableSortState,
    );
  }

  void _onTapSttHeader() {
    setState(() {
      _tableSortState = HomeTableSortManager.toggleStt(_tableSortState);
    });
  }

  void _onTapDistanceHeader() {
    setState(() {
      _tableSortState = HomeTableSortManager.toggleDistance(_tableSortState);
    });
  }

  String _formatMeters(double? value) {
    if (value == null) return '-';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)} km';
    return '${value.toStringAsFixed(0)} m';
  }

  Future<void> _refreshCurrentLocation() async {
    setState(() {
      _isBusy = true;
    });

    final result = await _controller.refreshCurrentLocation();
    if (result.status == CurrentLocationStatus.success &&
        result.position != null) {
      setState(() {
        _currentPosition = result.position;
        HomeLocationManager.applyDistanceFromCurrentPosition(
          currentPosition: result.position!,
          records: _records,
        );
        _isBusy = false;
      });
      _showStatusMessage('Đã cập nhật khoảng cách theo vị trí hiện tại.');
      return;
    }

    setState(() {
      _isBusy = false;
    });
    _showStatusMessage('Không lấy được vị trí hiện tại.');
  }

  String _getDefaultInspectorName() {
    for (final record in _records) {
      final name = record.inspectorName.trim();
      if (name.isNotEmpty) return name;
    }
    return '';
  }

  Future<void> _openRecordDetail(CabinetRecord record) async {
    final updated = await Get.to(
      () => CabinetDetailPage(
        record: record,
        defaultInspectorName: _getDefaultInspectorName(),
      ),
    );

    if (updated == null) return;

    setState(() {
      final recordIndex = _records.indexWhere((item) => item.id == updated.id);
      if (recordIndex >= 0) {
        _records[recordIndex] = updated;
      }

      final datasetIndex = _datasets.indexWhere(
        (dataset) => dataset.id == _selectedDatasetId,
      );
      if (datasetIndex >= 0) {
        final datasetRecords = _datasets[datasetIndex].records;
        final datasetRecordIndex = datasetRecords.indexWhere(
          (item) => item.id == updated.id,
        );
        if (datasetRecordIndex >= 0) {
          datasetRecords[datasetRecordIndex] = updated;
        }
      }
    });

    await _persistWorkspace();

    _showStatusMessage('Đã cập nhật tủ: ${updated.id}');
  }

  Future<void> _applyUpdatedRecord(CabinetRecord updated) async {
    setState(() {
      final recordIndex = _records.indexWhere((item) => item.id == updated.id);
      if (recordIndex >= 0) {
        _records[recordIndex] = updated;
      }

      final datasetIndex = _datasets.indexWhere(
        (dataset) => dataset.id == _selectedDatasetId,
      );
      if (datasetIndex >= 0) {
        final datasetRecords = _datasets[datasetIndex].records;
        final datasetRecordIndex = datasetRecords.indexWhere(
          (item) => item.id == updated.id,
        );
        if (datasetRecordIndex >= 0) {
          datasetRecords[datasetRecordIndex] = updated;
        }
      }
    });

    await _persistWorkspace();
  }

  Future<void> _openMapPage() async {
    await Get.to(
      () => MapPage(
        records: _records,
        userPos: _currentPosition,
        defaultInspectorName: _getDefaultInspectorName(),
        markerIconType: _locationIconType,
        onRecordUpdated: _applyUpdatedRecord,
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_isExportingInProgress) return true;

    final shouldCancelAndExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đang xuất dữ liệu'),
        content: const Text(
          'Ứng dụng đang đồng bộ báo cáo nên chưa thể thoát ngay. '
          'Bạn có muốn dừng xuất rồi thoát không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tiếp tục xuất'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Dừng xuất'),
          ),
        ],
      ),
    );

    if (shouldCancelAndExit == true) {
      _activeExportCancelToken?.cancel();
      _showStatusMessage('Đang dừng xuất dữ liệu...');
    } else {
      _showStatusMessage(
        'Đang xuất dữ liệu. Hãy dừng xuất trước khi thoát app.',
      );
    }

    return false;
  }

  String _defaultGoogleSheetTabName() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return 'BaoCao_${now.year}$mm$dd-$hh$min';
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(2)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  String _buildExportProgressLabel(String step, int processed, int total) {
    final safeTotal = total <= 0 ? 1 : total;
    final safeProcessed = processed.clamp(0, safeTotal);
    final percent = (safeProcessed / safeTotal) * 100;
    return '$step\n'
        '${_formatBytes(safeProcessed)}/${_formatBytes(safeTotal)} '
        '(${percent.toStringAsFixed(0)}%)';
  }

  Future<void> _exportReports() async {
    final options = await showExportOptionsDialog(
      context: context,
      initialAppsScriptUrl: _googleAppsScriptUrl,
      defaultSheetName: _defaultGoogleSheetTabName(),
      showStatusMessage: _showStatusMessage,
    );
    if (options == null) return;

    final exportRecords = _buildExportRecords(options);
    if (exportRecords.isEmpty) {
      _showStatusMessage('Không có dữ liệu phù hợp với điều kiện xuất.');
      return;
    }

    setState(() {
      _isBusy = true;
      _isExportingInProgress = true;
    });

    final estimatedTotalBytes = await _estimateGoogleSyncBytes(exportRecords);
    final progress = ValueNotifier<double>(0.0);
    final displayedBytes = ValueNotifier<int>(
      (estimatedTotalBytes * 0.05).round(),
    );
    final progressLabel = ValueNotifier<String>(
      _buildExportProgressLabel(
        'Khởi tạo đồng bộ dữ liệu...',
        displayedBytes.value,
        estimatedTotalBytes,
      ),
    );
    final isCancelRequested = ValueNotifier<bool>(false);
    final cancelToken = ExportCancelToken();

    _activeExportCancelToken = cancelToken;
    var progressDialogShown = false;

    if (mounted) {
      progressDialogShown = true;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: const Text('Đang đồng bộ Google Sheets'),
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
                        ],
                      );
                    },
                  );
                },
              ),
              actions: [
                ValueListenableBuilder<bool>(
                  valueListenable: isCancelRequested,
                  builder: (context, requested, _) {
                    return TextButton(
                      onPressed: requested
                          ? null
                          : () {
                              isCancelRequested.value = true;
                              progressLabel.value = _buildExportProgressLabel(
                                'Đang gửi yêu cầu hủy, vui lòng chờ...',
                                displayedBytes.value,
                                estimatedTotalBytes,
                              );
                              cancelToken.cancel();
                            },
                      child: Text(requested ? 'Đang hủy...' : 'Hủy đồng bộ'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      progress.value = 0.05;
      progressLabel.value = _buildExportProgressLabel(
        'Đang chuẩn bị đồng bộ ${exportRecords.length} bản ghi...',
        displayedBytes.value,
        estimatedTotalBytes,
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final appsScriptUrl = options.appsScriptUrl?.trim() ?? '';
      final sheetName = options.sheetName?.trim() ?? '';
      if (appsScriptUrl.isEmpty) {
        throw StateError('Thiếu URL Google Apps Script để đồng bộ.');
      }
      if (sheetName.isEmpty) {
        throw StateError('Thiếu tên trang tính để đồng bộ Google Sheets.');
      }

      final uploadedCount = await _googleSheetsSyncService.syncRecords(
        appsScriptUrl: appsScriptUrl,
        sheetName: sheetName,
        records: exportRecords,
        cancelToken: cancelToken,
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

      displayedBytes.value = estimatedTotalBytes;
      progress.value = 1.0;

      if (progressDialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      _showStatusMessage(
        'Đã đồng bộ Google Sheets thành công vào tab "$sheetName": '
        '$uploadedCount/${exportRecords.length} bản ghi.',
      );

      await _persistWorkspace();
    } catch (e) {
      if (e is ExportCanceledException) {
        if (progressDialogShown && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _showStatusMessage('Đã hủy đồng bộ dữ liệu.');
        return;
      }
      if (progressDialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showStatusMessage(
        'Đồng bộ Google Sheets thất bại. Vui lòng không thoát app khi đang export',
      );
    } finally {
      progress.dispose();
      displayedBytes.dispose();
      progressLabel.dispose();
      isCancelRequested.dispose();
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isExportingInProgress = false;
          _activeExportCancelToken = null;
        });
      } else {
        _isExportingInProgress = false;
        _activeExportCancelToken = null;
      }
    }
  }

  Future<void> _selectDataset(String datasetId) async {
    final result = HomeDatasetManager.selectDataset(
      datasets: _datasets,
      datasetId: datasetId,
    );

    setState(() {
      _selectedDatasetId = result.selectedDatasetId;
      _records
        ..clear()
        ..addAll(result.records);
    });
    _showStatusMessage(result.message);

    await _persistWorkspace();
  }

  Future<void> _deleteDataset(String datasetId) async {
    final result = HomeDatasetManager.deleteDataset(
      datasets: _datasets,
      datasetId: datasetId,
      selectedDatasetId: _selectedDatasetId,
      currentRecords: _records,
    );

    setState(() {
      _datasets
        ..clear()
        ..addAll(result.datasets);
      _selectedDatasetId = result.selectedDatasetId;
      _records
        ..clear()
        ..addAll(result.records);
    });

    _showStatusMessage(result.message);

    await _persistWorkspace();
  }

  void _showDatasetManager() {
    HomeDatasetManager.showDatasetManagerSheet(
      context: context,
      datasets: _datasets,
      selectedDatasetId: _selectedDatasetId,
      onSelect: _selectDataset,
      onDelete: _deleteDataset,
      onBackup: () async {
        final workspace = _buildWorkspaceState();
        await _storageService.saveWorkspace(workspace);
        await _writeAutoBackupFile(workspace);
        final backupFile = await _writeManualBackupFile(workspace);
        final backupName = backupFile.path.split(Platform.pathSeparator).last;
        _showStatusMessage('Đã sao lưu: $backupName');
      },
      onRestore: _restoreWorkspaceFromBackup,
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardDismissOnTap(
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          floatingActionButton: FloatingActionButton(
            backgroundColor: colorViettel,
            heroTag: 'importFile',
            onPressed: _isBusy ? null : _importKmz,
            child: const Icon(Icons.upload_file, color: Colors.white),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dns,
                        color: colorViettel,
                        size: Dimens.iconSizeMid + 4,
                      ),
                      const Spacer(),
                      buttonOnlyIcon(
                        onPress: _showDatasetManager,
                        iconData: Icons.folder_open,
                        iconColor: colorViettel,
                        size: Dimens.iconSizeMid,
                        visualDensity: minimumVisualDensity,
                      ),
                      hSpacer10(),
                      buttonOnlyIcon(
                        onPress: _openMapPage,
                        iconData: Icons.map,
                        iconColor: colorViettel,
                        size: Dimens.iconSizeMid,
                        visualDensity: minimumVisualDensity,
                      ),
                      hSpacer10(),
                      buttonOnlyIcon(
                        onPress: _isBusy ? null : _refreshCurrentLocation,
                        iconData: Icons.my_location,
                        iconColor: colorViettel,
                        size: Dimens.iconSizeMid,
                        visualDensity: minimumVisualDensity,
                      ),
                      hSpacer10(),
                      buttonOnlyIcon(
                        onPress: _isBusy ? null : _exportReports,
                        iconData: Icons.file_download,
                        iconColor: colorViettel,
                        size: Dimens.iconSizeMid,
                        visualDensity: minimumVisualDensity,
                      ),
                    ],
                  ),
                  if (_isBusy) const LinearProgressIndicator(),
                  vSpacer10(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 220,
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: lightDivider),
                          borderRadius: BorderRadius.circular(
                            Dimens.radiusCornerSmall,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<InspectionStatus?>(
                            isDense: true,
                            value: _statusFilter,
                            hint: TextRobotoAutoNormal(
                              'Tất cả',
                              fontSize: Dimens.regularFontSizeExtraMid,
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            borderRadius: BorderRadius.circular(12),
                            items:
                                List<
                                  DropdownMenuItem<InspectionStatus?>
                                >.generate(
                                  _statusFilterValues.length,
                                  (index) =>
                                      DropdownMenuItem<InspectionStatus?>(
                                        value: _statusFilterValues[index],
                                        child: TextRobotoAutoNormal(
                                          _statusFilterLabels[index],
                                          fontSize:
                                              Dimens.regularFontSizeExtraMid,
                                        ),
                                      ),
                                ),
                            onChanged: (value) => setState(() {
                              _statusFilter = value;
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                  vSpacer10(),
                  textFieldWithWidget(
                    controller: _controller.searchController,
                    hint: 'Tìm theo mã/tên/tuyến...',
                    prefixWidget: const Icon(
                      Icons.search_rounded,
                      color: Colors.grey,
                    ),
                    suffixWidget: _controller.searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Colors.grey,
                            ),
                            onPressed: _controller.clearInputData,
                          )
                        : null,
                    borderRadius: Dimens.radiusCornerSmall,
                  ),
                  vSpacer10(),
                  Expanded(
                    child: CabinetTable(
                      rows: _filteredRecords,
                      columnWidths: _columnWidths,
                      markerIconType: _locationIconType,
                      tableScrollController: _tableScrollController,
                      formatMeters: _formatMeters,
                      onRecordTap: _openRecordDetail,
                      onSttHeaderTap: _onTapSttHeader,
                      onDistanceHeaderTap: _onTapDistanceHeader,
                      isSortByStt: _tableSortState.isStt,
                      isSortByDistance: _tableSortState.isDistance,
                      sortAscending: _tableSortState.ascending,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
