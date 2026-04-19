// import 'dart:async';
// import 'dart:io';
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import '../models/cabinet_dataset.dart';
// import '../models/cabinet_record.dart';
// import '../services/download_path_service.dart';
// import '../services/export_cancel_token.dart';
// import '../services/export_service.dart';
// import '../services/google_sheets_sync_service.dart';
// import '../services/kmz_service.dart';
// import '../services/location_service.dart';
// import '../services/storage_service.dart';
// import '../utils/location_marker_style.dart';
// import '../widgets/cabinet_table.dart';
// import 'cabinet_detail_page.dart';
// import 'export/export_options_dialog.dart';
// import 'map_page.dart';

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   final KmzService _kmzService = KmzService();
//   final StorageService _storageService = StorageService();
//   final LocationService _locationService = LocationService();
//   final ExportService _exportService = ExportService();
//   final GoogleSheetsSyncService _googleSheetsSyncService =
//       GoogleSheetsSyncService();

//   List<CabinetDataset> _datasets = <CabinetDataset>[];
//   String? _selectedDatasetId;
//   List<CabinetRecord> _records = <CabinetRecord>[];
//   Position? _currentPosition;
//   bool _isBusy = false;
//   bool _isExportingInProgress = false;
//   ExportCancelToken? _activeExportCancelToken;
//   InspectionStatus? _statusFilter;
//   double? _radiusFilter;
//   bool _sortAsc = true;
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _mapRadiusController = TextEditingController();
//   final TextEditingController _mapCabinetIdsController =
//       TextEditingController();
//   String _searchQuery = '';
//   Timer? _searchDebounce;
//   Map<int, String> _searchTextCache = <int, String>{};
//   int _recordsRevision = 0;
//   List<CabinetRecord>? _filteredCache;
//   int _filteredCacheRevision = -1;
//   InspectionStatus? _filteredCacheStatus;
//   double? _filteredCacheRadius;
//   String _filteredCacheQuery = '';
//   final ScrollController _tableScrollController = ScrollController();
//   bool _showScrollToTop = false;
//   String _defaultInspectorName = '';
//   LocationMarkerIconType _locationIconType = LocationMarkerIconType.pin;
//   ExportLocationType _exportLocationType = ExportLocationType.downloads;
//   String? _customExportPath;
//   String? _googleAppsScriptUrl;
//   static const List<double> _columnWidthsDesktop = <double>[
//     48, // Icon vi tri
//     56, // STT
//     140, // Ma tu
//     200, // Ten tu
//     130, // Lat
//     130, // Lng
//     120, // Khoang cach
//     100, // Sai so
//     120, // Trang thai
//     100, // Muc do
//     70, // Anh
//   ];

//   static const List<double> _columnWidthsTablet = <double>[
//     44, // Icon vi tri
//     50, // STT
//     110, // Ma tu
//     150, // Ten tu
//     100, // Lat
//     100, // Lng
//     100, // Khoang cach
//     80, // Sai so
//     100, // Trang thai
//     80, // Muc do
//     60, // Anh
//   ];

//   static const List<double> _columnWidthsMobile = <double>[
//     40, // Icon vi tri
//     40, // STT
//     80, // Ma tu
//     100, // Ten tu
//     80, // Lat
//     80, // Lng
//     80, // Khoang cach
//     70, // Sai so
//     80, // Trang thai
//     70, // Muc do
//     50, // Anh
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _tableScrollController.addListener(_onTableScroll);
//     _initApp();
//   }

//   Future<void> _initApp() async {
//     await _loadSavedData();
//   }

//   @override
//   void dispose() {
//     _searchDebounce?.cancel();
//     _tableScrollController
//       ..removeListener(_onTableScroll)
//       ..dispose();
//     _searchController.dispose();
//     _mapRadiusController.dispose();
//     _mapCabinetIdsController.dispose();
//     super.dispose();
//   }

//   void _showStatusMessage(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).clearSnackBars();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         duration: const Duration(seconds: 3),
//         behavior: SnackBarBehavior.fixed,
//       ),
//     );
//   }

//   Future<bool> _onWillPop() async {
//     if (!_isExportingInProgress) {
//       return true;
//     }

//     final shouldCancelAndExit = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Đang xuất dữ liệu'),
//         content: const Text(
//           'Ứng dụng đang xuất báo cáo nên chưa thể thoát ngay. '
//           'Bạn có muốn dừng xuất rồi thoát không?',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: const Text('Tiếp tục xuất'),
//           ),
//           FilledButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             child: const Text('Dừng xuất'),
//           ),
//         ],
//       ),
//     );

//     if (shouldCancelAndExit == true) {
//       _activeExportCancelToken?.cancel();
//       _showStatusMessage('Đang dừng xuất dữ liệu...');
//     } else {
//       _showStatusMessage(
//         'Đang xuất dữ liệu. Hãy dừng xuất trước khi thoát app.',
//       );
//     }

//     return false;
//   }

//   List<double> _getResponsiveColumnWidths(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     if (screenWidth >= 1024) {
//       return _columnWidthsDesktop;
//     } else if (screenWidth >= 600) {
//       return _columnWidthsTablet;
//     } else {
//       return _columnWidthsMobile;
//     }
//   }

//   bool _isMobileLayout(BuildContext context) {
//     return MediaQuery.of(context).size.width < 600;
//   }

//   void _onTableScroll() {
//     final shouldShow =
//         _tableScrollController.hasClients &&
//         _tableScrollController.offset > 600;
//     if (shouldShow != _showScrollToTop && mounted) {
//       setState(() {
//         _showScrollToTop = shouldShow;
//       });
//     }
//   }

//   Future<void> _loadSavedData() async {
//     setState(() {
//       _isBusy = true;
//     });
//     final workspace = await _storageService.loadWorkspace();
//     final selectedId = workspace.selectedDatasetId;
//     final selectedDataset = workspace.datasets
//         .cast<CabinetDataset?>()
//         .firstWhere(
//           (dataset) => dataset?.id == selectedId,
//           orElse: () =>
//               workspace.datasets.isNotEmpty ? workspace.datasets.first : null,
//         );
//     setState(() {
//       _datasets = workspace.datasets;
//       _selectedDatasetId = selectedDataset?.id;
//       _records = selectedDataset?.records ?? <CabinetRecord>[];
//       _invalidateFilteredCache();
//       _defaultInspectorName = _detectInspectorName(_records);
//       _exportLocationType = workspace.exportLocation == 'documents'
//           ? ExportLocationType.documents
//           : workspace.exportLocation == 'custom'
//           ? ExportLocationType.custom
//           : ExportLocationType.downloads;
//       _customExportPath = workspace.customExportPath;
//       _googleAppsScriptUrl = workspace.googleAppsScriptUrl;
//       _isBusy = false;
//     });
//   }

//   Future<bool> _ensureCurrentPosition({
//     bool showLoadingMessage = false,
//     bool showErrorMessage = true,
//   }) async {
//     if (_currentPosition != null) return true;

//     if (showLoadingMessage) {
//       _showStatusMessage('Đang lấy vị trí hiện tại...');
//     }

//     try {
//       _currentPosition = await _locationService.getCurrentPosition();
//       return true;
//     } catch (_) {
//       if (showErrorMessage) {
//         _showStatusMessage('Hãy cấp quyền vị trí để sắp xếp tủ gần nhất.');
//       }
//       return false;
//     }
//   }

//   Future<void> _importKmz() async {
//     setState(() {
//       _isBusy = true;
//     });
//     _showStatusMessage('Đang import KMZ/KML...');
//     try {
//       final imported = await _kmzService.importKmz();
//       if (imported == null) {
//         setState(() {
//           _isBusy = false;
//         });
//         _showStatusMessage('Đã huỷ import.');
//         return;
//       }
//       if (imported.records.isEmpty) {
//         setState(() {
//           _isBusy = false;
//         });
//         _showStatusMessage('Không có dữ liệu hợp lệ từ file import.');
//         return;
//       }
//       final dataset = CabinetDataset(
//         id: DateTime.now().millisecondsSinceEpoch.toString(),
//         fileName: imported.fileName,
//         importedAt: DateTime.now(),
//         records: imported.records,
//       );
//       _datasets = <CabinetDataset>[..._datasets, dataset];
//       _selectedDatasetId = dataset.id;
//       _records = dataset.records;
//       _invalidateFilteredCache();
//       if (_currentPosition != null) {
//         await _calculateDistanceAndSortAsync();
//       }
//       await _persistWorkspace();
//       setState(() {
//         _isBusy = false;
//       });
//       _showStatusMessage(
//         'Import file ${dataset.fileName} thành công ${_records.length} tủ.',
//       );
//     } catch (error) {
//       setState(() {
//         _isBusy = false;
//       });
//       _showStatusMessage('Import lỗi: $error');
//     }
//   }

//   Future<void> _refreshCurrentLocation() async {
//     setState(() {
//       _isBusy = true;
//     });
//     _showStatusMessage('Đang lấy vị trí hiện tại...');
//     try {
//       _currentPosition = await _locationService.getCurrentPosition();
//       await _calculateDistanceAndSortAsync();
//       setState(() {
//         _isBusy = false;
//       });
//       _showStatusMessage('Đã cập nhật khoảng cách theo vị trí hiện tại.');
//     } catch (error) {
//       setState(() {
//         _isBusy = false;
//       });
//       _showStatusMessage('Lỗi vị trí: $error');
//     }
//   }

//   void _invalidateFilteredCache() {
//     _recordsRevision++;
//     _filteredCache = null;
//     _searchTextCache = <int, String>{};
//   }

//   List<CabinetRecord> get _filteredRecords {
//     final query = _searchQuery.trim().toLowerCase();
//     if (_filteredCache != null &&
//         _filteredCacheRevision == _recordsRevision &&
//         _filteredCacheStatus == _statusFilter &&
//         _filteredCacheRadius == _radiusFilter &&
//         _filteredCacheQuery == query) {
//       return _filteredCache!;
//     }

//     final List<CabinetRecord> computed;
//     if (_statusFilter == null && _radiusFilter == null && query.isEmpty) {
//       computed = _records;
//     } else {
//       computed = _records.where((record) {
//         final statusOk =
//             _statusFilter == null || record.inspectionStatus == _statusFilter;
//         final radiusOk =
//             _radiusFilter == null ||
//             (record.distanceToUserMeters != null &&
//                 record.distanceToUserMeters! <= _radiusFilter!);
//         final searchOk = query.isEmpty || _matchesSearch(record, query);
//         return statusOk && radiusOk && searchOk;
//       }).toList();
//     }

//     _filteredCache = computed;
//     _filteredCacheRevision = _recordsRevision;
//     _filteredCacheStatus = _statusFilter;
//     _filteredCacheRadius = _radiusFilter;
//     _filteredCacheQuery = query;
//     return computed;
//   }

//   bool _matchesSearch(CabinetRecord record, String query) {
//     final key = identityHashCode(record);
//     final searchText = _searchTextCache.putIfAbsent(
//       key,
//       () => _buildSearchText(record),
//     );
//     return searchText.contains(query);
//   }

//   String _buildSearchText(CabinetRecord record) {
//     final buffer = StringBuffer()
//       ..write(record.id)
//       ..write(' ')
//       ..write(record.name)
//       ..write(' ')
//       ..write(record.route)
//       ..write(' ')
//       ..write(record.latitudeRef)
//       ..write(' ')
//       ..write(record.longitudeRef)
//       ..write(' ')
//       ..write(record.latitudeActual ?? '')
//       ..write(' ')
//       ..write(record.longitudeActual ?? '')
//       ..write(' ')
//       ..write(_formatMeters(record.distanceToUserMeters))
//       ..write(' ')
//       ..write(_formatMeters(record.coordinateDeviationMeters))
//       ..write(' ')
//       ..write(record.inspectionStatus.labelVi)
//       ..write(' ')
//       ..write(record.severity.labelVi)
//       ..write(' ')
//       ..write(record.otherIssueType)
//       ..write(' ')
//       ..write(record.inspectorName)
//       ..write(' ')
//       ..write(record.notes)
//       ..write(' ')
//       ..write(record.photos.length)
//       ..write(' ')
//       ..write(record.isPassed ? 'đạt' : 'không đạt')
//       ..write(' ')
//       ..write(record.wrongPosition)
//       ..write(' ')
//       ..write(record.hangingCable)
//       ..write(' ')
//       ..write(record.unfixedCable)
//       ..write(' ')
//       ..write(record.otherIssue);

//     return buffer.toString().toLowerCase();
//   }

//   Future<void> _calculateDistanceAndSortAsync() async {
//     if (_currentPosition == null) return;

//     final currentPosition = _currentPosition!;
//     const chunkSize = 200;

//     for (var i = 0; i < _records.length; i++) {
//       final record = _records[i];
//       final distance = _locationService.distanceBetween(
//         startLat: currentPosition.latitude,
//         startLng: currentPosition.longitude,
//         endLat: record.latitudeRef,
//         endLng: record.longitudeRef,
//       );
//       record.distanceToUserMeters = distance;

//       if (record.latitudeActual != null && record.longitudeActual != null) {
//         record.coordinateDeviationMeters = _locationService.distanceBetween(
//           startLat: record.latitudeRef,
//           startLng: record.longitudeRef,
//           endLat: record.latitudeActual!,
//           endLng: record.longitudeActual!,
//         );
//       }

//       if ((i + 1) % chunkSize == 0) {
//         await Future<void>.delayed(Duration.zero);
//       }
//     }

//     _records.sort((a, b) {
//       final ad = a.distanceToUserMeters ?? double.infinity;
//       final bd = b.distanceToUserMeters ?? double.infinity;
//       return _sortAsc ? ad.compareTo(bd) : bd.compareTo(ad);
//     });
//     _invalidateFilteredCache();
//   }

//   String _detectInspectorName(List<CabinetRecord> records) {
//     for (final record in records) {
//       final name = record.inspectorName.trim();
//       if (name.isNotEmpty) return name;
//     }
//     return _defaultInspectorName;
//   }

//   Future<void> _applyUpdatedRecord(CabinetRecord updated) async {
//     final index = _records.indexWhere((item) => item.id == updated.id);
//     if (index < 0) return;

//     setState(() {
//       _records[index] = updated;
//       _invalidateFilteredCache();
//       final name = updated.inspectorName.trim();
//       if (name.isNotEmpty) {
//         _defaultInspectorName = name;
//       }
//     });

//     if (_currentPosition != null) {
//       await _calculateDistanceAndSortAsync();
//       if (mounted) {
//         setState(() {});
//       }
//     }

//     try {
//       await _persistWorkspace();
//       _showStatusMessage('Đã lưu cập nhật cho tủ ${updated.name}.');
//     } catch (e) {
//       _showStatusMessage('Đã cập nhật trên màn hình nhưng lưu cục bộ lỗi: $e');
//     }
//   }

//   List<CabinetRecord> _buildMapRecords() {
//     var records = List<CabinetRecord>.from(_filteredRecords);

//     final idTokens = _mapCabinetIdsController.text
//         .split(RegExp(r'[,;\s]+'))
//         .map((value) => value.trim().toUpperCase())
//         .where((value) => value.isNotEmpty)
//         .toSet();
//     if (idTokens.isNotEmpty) {
//       records = records
//           .where(
//             (record) => idTokens.any(
//               (token) => record.id.trim().toUpperCase().startsWith(token),
//             ),
//           )
//           .toList();
//     }

//     final customRadius = double.tryParse(_mapRadiusController.text.trim());
//     if (customRadius != null && customRadius > 0 && _currentPosition != null) {
//       records = records.where((record) {
//         final distance = _locationService.distanceBetween(
//           startLat: _currentPosition!.latitude,
//           startLng: _currentPosition!.longitude,
//           endLat: record.latitudeRef,
//           endLng: record.longitudeRef,
//         );
//         return distance <= customRadius;
//       }).toList();
//     }

//     return records;
//   }

//   Future<void> _openRecordDetail(CabinetRecord record) async {
//     final updated = await Navigator.of(context).push<CabinetRecord>(
//       MaterialPageRoute(
//         builder: (_) => CabinetDetailPage(
//           record: record.copyWith(),
//           defaultInspectorName: _defaultInspectorName,
//         ),
//       ),
//     );
//     if (updated == null) return;

//     await _applyUpdatedRecord(updated);
//   }

//   Future<void> _openMapView() async {
//     final customRadius = double.tryParse(_mapRadiusController.text.trim());
//     if (customRadius != null && customRadius > 0 && _currentPosition == null) {
//       final hasPosition = await _ensureCurrentPosition(
//         showLoadingMessage: true,
//       );
//       if (hasPosition) {
//         await _calculateDistanceAndSortAsync();
//       } else {
//         _showStatusMessage(
//           'Chưa lấy được vị trí hiện tại nên không lọc theo bán kính map.',
//         );
//       }
//     }

//     final mapRecords = _buildMapRecords();
//     if (mapRecords.isEmpty) {
//       _showStatusMessage('Không có tủ phù hợp với bộ lọc map hiện tại.');
//       return;
//     }

//     await Navigator.of(context).push<void>(
//       MaterialPageRoute(
//         builder: (_) => MapPage(
//           records: mapRecords,
//           userPos: _currentPosition,
//           defaultInspectorName: _defaultInspectorName,
//           markerIconType: _locationIconType,
//           onRecordUpdated: _applyUpdatedRecord,
//         ),
//       ),
//     );
//   }

//   Future<void> _toggleSortByDistance() async {
//     if (_currentPosition == null) {
//       final hasPosition = await _ensureCurrentPosition(
//         showLoadingMessage: true,
//       );
//       if (!hasPosition || !mounted) return;
//     }

//     setState(() {
//       _sortAsc = !_sortAsc;
//     });
//     await _calculateDistanceAndSortAsync();
//     if (mounted) {
//       setState(() {});
//     }
//   }

//   String _formatBytes(int bytes) {
//     if (bytes < 1024) return '$bytes B';
//     final kb = bytes / 1024;
//     if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
//     final mb = kb / 1024;
//     if (mb < 1024) return '${mb.toStringAsFixed(2)} MB';
//     final gb = mb / 1024;
//     return '${gb.toStringAsFixed(2)} GB';
//   }

//   int _estimateExportTotalBytes(
//     List<CabinetRecord> records,
//     ExportImageMode imageMode,
//   ) {
//     final photoCount = records.fold<int>(
//       0,
//       (sum, record) => sum + record.photos.length,
//     );
//     final baseBytes = 600 * 1024;
//     final perRecordBytes = records.length * 12 * 1024;
//     final perPhotoBytes = switch (imageMode) {
//       ExportImageMode.original => photoCount * 420 * 1024,
//       ExportImageMode.balanced => photoCount * 240 * 1024,
//       ExportImageMode.compact => photoCount * 130 * 1024,
//     };
//     return baseBytes + perRecordBytes + perPhotoBytes;
//   }

//   Future<int> _estimateGoogleSyncBytes(List<CabinetRecord> records) async {
//     var total = 350 * 1024;
//     for (final record in records) {
//       total += 12 * 1024;
//       for (final photo in record.photos) {
//         final file = File(photo.path);
//         if (!file.existsSync()) continue;
//         final length = await file.length();
//         total += (length * 1.4).round();
//       }
//     }
//     return total;
//   }

//   String _buildExportProgressLabel(String step, int processed, int total) {
//     final safeTotal = total <= 0 ? 1 : total;
//     final safeProcessed = processed.clamp(0, safeTotal);
//     final percent = (safeProcessed / safeTotal) * 100;
//     return '$step\n'
//         '${_formatBytes(safeProcessed)}/${_formatBytes(safeTotal)} '
//         '(${percent.toStringAsFixed(0)}%)';
//   }

//   String _defaultGoogleSheetTabName() {
//     final now = DateTime.now();
//     final mm = now.month.toString().padLeft(2, '0');
//     final dd = now.day.toString().padLeft(2, '0');
//     final hh = now.hour.toString().padLeft(2, '0');
//     final min = now.minute.toString().padLeft(2, '0');
//     return 'BaoCao_${now.year}$mm$dd-$hh$min';
//   }

//   List<CabinetRecord> _buildExportRecords(ExportOptions options) {
//     DateTime? fromBoundary;
//     DateTime? toBoundary;
//     if (options.fromDate != null) {
//       fromBoundary = DateTime(
//         options.fromDate!.year,
//         options.fromDate!.month,
//         options.fromDate!.day,
//       );
//     }
//     if (options.toDate != null) {
//       toBoundary = DateTime(
//         options.toDate!.year,
//         options.toDate!.month,
//         options.toDate!.day,
//         23,
//         59,
//         59,
//         999,
//       );
//     }

//     return _records.where((record) {
//       final statusMatch = switch (options.statusFilter) {
//         ExportRecordStatusFilter.all => true,
//         ExportRecordStatusFilter.checked =>
//           record.inspectionStatus == InspectionStatus.checked,
//         ExportRecordStatusFilter.notChecked =>
//           record.inspectionStatus == InspectionStatus.notChecked,
//         ExportRecordStatusFilter.recheckNeeded =>
//           record.inspectionStatus == InspectionStatus.recheckNeeded,
//       };

//       if (!statusMatch) return false;

//       if (fromBoundary == null && toBoundary == null) {
//         return true;
//       }

//       final checkedAt = record.lastCheckedAt;
//       if (checkedAt == null) return false;

//       if (fromBoundary != null && checkedAt.isBefore(fromBoundary)) {
//         return false;
//       }
//       if (toBoundary != null && checkedAt.isAfter(toBoundary)) {
//         return false;
//       }
//       return true;
//     }).toList();
//   }

//   Future<void> _exportReports() async {
//     final options = await showExportOptionsDialog(
//       context: context,
//       initialAppsScriptUrl: _googleAppsScriptUrl,
//       defaultSheetName: _defaultGoogleSheetTabName(),
//       showStatusMessage: _showStatusMessage,
//     );
//     if (options == null) return;

//     final exportRecords = _buildExportRecords(options);
//     if (exportRecords.isEmpty) {
//       _showStatusMessage('Không có dữ liệu phù hợp với điều kiện xuất.');
//       return;
//     }

//     setState(() {
//       _isBusy = true;
//     });

//     final estimatedTotalBytes = options.destination == ExportDestination.files
//         ? _estimateExportTotalBytes(exportRecords, options.imageMode)
//         : await _estimateGoogleSyncBytes(exportRecords);

//     final progress = ValueNotifier<double>(0.0);
//     final displayedBytes = ValueNotifier<int>(
//       (estimatedTotalBytes * 0.05).round(),
//     );
//     final progressLabel = ValueNotifier<String>(
//       _buildExportProgressLabel(
//         'Khởi tạo xuất dữ liệu...',
//         displayedBytes.value,
//         estimatedTotalBytes,
//       ),
//     );
//     final isCancelRequested = ValueNotifier<bool>(false);
//     final cancelToken = ExportCancelToken();
//     _isExportingInProgress = true;
//     _activeExportCancelToken = cancelToken;

//     bool progressDialogShown = false;

//     if (mounted) {
//       progressDialogShown = true;
//       unawaited(
//         showDialog<void>(
//           context: context,
//           barrierDismissible: false,
//           builder: (_) => WillPopScope(
//             onWillPop: () async => false,
//             child: AlertDialog(
//               title: const Text('Đang xuất báo cáo'),
//               content: ValueListenableBuilder<String>(
//                 valueListenable: progressLabel,
//                 builder: (context, label, __) {
//                   return ValueListenableBuilder<double>(
//                     valueListenable: progress,
//                     builder: (context, value, ___) {
//                       return Column(
//                         mainAxisSize: MainAxisSize.min,
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           LinearProgressIndicator(value: value),
//                           const SizedBox(height: 12),
//                           Text(label),
//                           const SizedBox(height: 6),
//                           const Text(
//                             'Bạn có thể đưa app xuống nền, tác vụ vẫn tiếp tục xử lý.',
//                             style: TextStyle(fontSize: 12),
//                           ),
//                         ],
//                       );
//                     },
//                   );
//                 },
//               ),
//               actions: [
//                 ValueListenableBuilder<bool>(
//                   valueListenable: isCancelRequested,
//                   builder: (context, requested, _) {
//                     return TextButton(
//                       onPressed: requested
//                           ? null
//                           : () {
//                               isCancelRequested.value = true;
//                               progressLabel.value = _buildExportProgressLabel(
//                                 'Đang gửi yêu cầu hủy, vui lòng chờ... ',
//                                 displayedBytes.value,
//                                 estimatedTotalBytes,
//                               );
//                               cancelToken.cancel();
//                             },
//                       child: Text(requested ? 'Đang hủy...' : 'Hủy xuất'),
//                     );
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     try {
//       progress.value = 0.05;
//       progressLabel.value = _buildExportProgressLabel(
//         options.destination == ExportDestination.files
//             ? 'Đang chuẩn bị ${exportRecords.length} bản ghi...'
//             : 'Đang chuẩn bị đồng bộ ${exportRecords.length} bản ghi...',
//         displayedBytes.value,
//         estimatedTotalBytes,
//       );
//       await Future<void>.delayed(const Duration(milliseconds: 120));

//       if (options.destination == ExportDestination.files) {
//         final (csvPath, xlsxPath) = await _exportService.exportRecords(
//           exportRecords,
//           _exportLocationType,
//           customPath: _customExportPath,
//           imageMode: options.imageMode,
//           cancelToken: cancelToken,
//           onProgress: (event) {
//             final value = event.value.clamp(0.0, 0.96);
//             progress.value = value;
//             displayedBytes.value = (estimatedTotalBytes * value).round();
//             progressLabel.value = _buildExportProgressLabel(
//               event.message,
//               displayedBytes.value,
//               estimatedTotalBytes,
//             );
//           },
//         );

//         final csvSize = await File(csvPath).length();
//         final xlsxSize = await File(xlsxPath).length();
//         final totalActualBytes = csvSize + xlsxSize;
//         final totalDisplayBytes = totalActualBytes > estimatedTotalBytes
//             ? totalActualBytes
//             : estimatedTotalBytes;

//         displayedBytes.value = totalActualBytes;
//         progress.value = (displayedBytes.value / totalDisplayBytes).clamp(
//           0.0,
//           0.98,
//         );
//         progressLabel.value = _buildExportProgressLabel(
//           'Đang tính kích thước file...',
//           displayedBytes.value,
//           totalDisplayBytes,
//         );

//         await Future<void>.delayed(const Duration(milliseconds: 180));
//         displayedBytes.value = totalDisplayBytes;
//         progress.value = 1.0;
//         progressLabel.value = _buildExportProgressLabel(
//           'Đang hoàn tất xuất báo cáo...',
//           totalDisplayBytes,
//           totalDisplayBytes,
//         );

//         progressLabel.value = _buildExportProgressLabel(
//           'Hoàn tất xuất báo cáo.',
//           totalDisplayBytes,
//           totalDisplayBytes,
//         );

//         if (progressDialogShown && mounted) {
//           Navigator.of(context, rootNavigator: true).pop();
//         }

//         final fileLog =
//             '[EXPORT_SUCCESS][FILES] records=${exportRecords.length}, '
//             'csv=$csvPath (${_formatBytes(csvSize)}), '
//             'xlsx=$xlsxPath (${_formatBytes(xlsxSize)})';
//         debugPrint(fileLog);
//         print(fileLog);

//         _showStatusMessage(
//           'Đã xuất thành công ${exportRecords.length} bản ghi (CSV + XLSX).',
//         );
//       } else {
//         final appsScriptUrl = options.appsScriptUrl?.trim() ?? '';
//         final sheetName = options.sheetName?.trim() ?? '';
//         if (appsScriptUrl.isEmpty) {
//           throw StateError('Thiếu URL Google Apps Script để đồng bộ.');
//         }
//         if (sheetName.isEmpty) {
//           throw StateError('Thiếu tên trang tính để đồng bộ Google Sheets.');
//         }

//         final uploadedCount = await _googleSheetsSyncService.syncRecords(
//           appsScriptUrl: appsScriptUrl,
//           sheetName: sheetName,
//           records: exportRecords,
//           cancelToken: cancelToken,
//           onProgress: (event) {
//             final value = event.value.clamp(0.0, 0.98);
//             progress.value = value;
//             displayedBytes.value = (estimatedTotalBytes * value).round();
//             progressLabel.value = _buildExportProgressLabel(
//               event.message,
//               displayedBytes.value,
//               estimatedTotalBytes,
//             );
//           },
//         );

//         _googleAppsScriptUrl = appsScriptUrl;
//         await _persistWorkspace();

//         displayedBytes.value = estimatedTotalBytes;
//         progress.value = 1.0;
//         progressLabel.value = _buildExportProgressLabel(
//           'Hoàn tất đồng bộ Google Sheets.',
//           estimatedTotalBytes,
//           estimatedTotalBytes,
//         );

//         if (progressDialogShown && mounted) {
//           Navigator.of(context, rootNavigator: true).pop();
//         }

//         final sheetsLog =
//             '[EXPORT_SUCCESS][GOOGLE_SHEETS] '
//             'records=$uploadedCount/${exportRecords.length}, '
//             'appsScriptUrl=$appsScriptUrl, '
//             'sheetName=$sheetName';
//         debugPrint(sheetsLog);
//         print(sheetsLog);

//         _showStatusMessage(
//           'Đã đồng bộ Google Sheets thành công vào tab "$sheetName": '
//           '$uploadedCount/${exportRecords.length} bản ghi.',
//         );
//       }
//     } catch (e, st) {
//       if (e is ExportCanceledException) {
//         debugPrint('[EXPORT_CANCELED][${options.destination.name}]');
//         print('[EXPORT_CANCELED][${options.destination.name}]');
//         if (progressDialogShown && mounted) {
//           Navigator.of(context, rootNavigator: true).pop();
//         }
//         _showStatusMessage('Đã hủy xuất dữ liệu.');
//         return;
//       }
//       final errorLog =
//           '[EXPORT_ERROR][${options.destination.name}] error=$e\nstack=$st';
//       debugPrint(errorLog);
//       print(errorLog);
//       if (progressDialogShown && mounted) {
//         Navigator.of(context, rootNavigator: true).pop();
//       }
//       _showStatusMessage(
//         options.destination == ExportDestination.files
//             ? 'Xuất file thất bại' //$e\nHãy chọn lại nơi lưu ở nút thư mục xuất.
//             : 'Đồng bộ Google Sheets thất bại. Vui lòng không thoát hoặc đóng ứng dụng khi đang export', //: $e\nHãy kiểm tra lại URL Apps Script và quyền truy cập.
//       );
//     } finally {
//       progress.dispose();
//       displayedBytes.dispose();
//       progressLabel.dispose();
//       isCancelRequested.dispose();
//       if (mounted) {
//         setState(() {
//           _isBusy = false;
//           _isExportingInProgress = false;
//           _activeExportCancelToken = null;
//         });
//       } else {
//         _isExportingInProgress = false;
//         _activeExportCancelToken = null;
//       }
//     }
//   }

//   Future<void> _persistWorkspace() async {
//     _updateSelectedDatasetRecords();
//     await _storageService.saveWorkspace(
//       CabinetWorkspaceState(
//         datasets: _datasets,
//         selectedDatasetId: _selectedDatasetId,
//         exportLocation: _exportLocationType == ExportLocationType.documents
//             ? 'documents'
//             : _exportLocationType == ExportLocationType.custom
//             ? 'custom'
//             : 'downloads',
//         customExportPath: _customExportPath,
//         googleAppsScriptUrl: _googleAppsScriptUrl,
//       ),
//     );
//   }

//   Future<void> _chooseExportLocation() async {
//     final selected = await showModalBottomSheet<String>(
//       isScrollControlled: true,
//       context: context,
//       builder: (context) {
//         return SafeArea(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ListTile(
//                 title: const Text('Lưu vào Download/cabinet_checker/exports'),
//                 trailing: _exportLocationType == ExportLocationType.downloads
//                     ? const Icon(Icons.check, color: Colors.green)
//                     : null,
//                 onTap: () => Navigator.of(context).pop('downloads'),
//               ),
//               ListTile(
//                 title: const Text('Lưu vào Documents/cabinet_checker/exports'),
//                 trailing: _exportLocationType == ExportLocationType.documents
//                     ? const Icon(Icons.check, color: Colors.green)
//                     : null,
//                 onTap: () => Navigator.of(context).pop('documents'),
//               ),
//               ListTile(
//                 leading: const Icon(Icons.folder),
//                 title: Text(
//                   _customExportPath == null
//                       ? 'Chọn folder tùy ý'
//                       : 'Đã chọn: $_customExportPath',
//                 ),
//                 trailing: _exportLocationType == ExportLocationType.custom
//                     ? const Icon(Icons.check, color: Colors.green)
//                     : null,
//                 onTap: () async {
//                   Navigator.of(context).pop();
//                   await _pickExportFolder();
//                 },
//               ),
//             ],
//           ),
//         );
//       },
//     );

//     if (selected == null) return;

//     if (selected == 'downloads') {
//       setState(() {
//         _exportLocationType = ExportLocationType.downloads;
//         _customExportPath = null;
//       });
//       _showStatusMessage('Đã chuyển nơi lưu export sang Download.');
//     } else if (selected == 'documents') {
//       setState(() {
//         _exportLocationType = ExportLocationType.documents;
//         _customExportPath = null;
//       });
//       _showStatusMessage('Đã chuyển nơi lưu export sang Documents.');
//     }

//     await _persistWorkspace();
//   }

//   Future<void> _pickExportFolder() async {
//     final folderPath = await FilePicker.platform.getDirectoryPath();
//     if (folderPath == null) return;

//     setState(() {
//       _exportLocationType = ExportLocationType.custom;
//       _customExportPath = folderPath;
//     });
//     _showStatusMessage('Đã chọn folder: $folderPath');
//     await _persistWorkspace();
//   }

//   void _updateSelectedDatasetRecords() {
//     if (_selectedDatasetId == null) return;
//     final idx = _datasets.indexWhere(
//       (dataset) => dataset.id == _selectedDatasetId,
//     );
//     if (idx < 0) return;
//     final current = _datasets[idx];
//     _datasets[idx] = CabinetDataset(
//       id: current.id,
//       fileName: current.fileName,
//       importedAt: current.importedAt,
//       records: List<CabinetRecord>.from(_records),
//     );
//   }

//   void _selectDataset(String datasetId) {
//     final dataset = _datasets.firstWhere((item) => item.id == datasetId);
//     setState(() {
//       _selectedDatasetId = datasetId;
//       _records = List<CabinetRecord>.from(dataset.records);
//       _invalidateFilteredCache();
//       _defaultInspectorName = _detectInspectorName(_records);
//     });

//     if (_currentPosition != null) {
//       unawaited(
//         _calculateDistanceAndSortAsync().then((_) {
//           if (mounted) setState(() {});
//         }),
//       );
//     }

//     _showStatusMessage('Đang dùng file: ${dataset.fileName}');
//     _persistWorkspace();
//   }

//   Future<void> _deleteDataset(String datasetId) async {
//     final deleting = _datasets.firstWhere((item) => item.id == datasetId);
//     _datasets.removeWhere((item) => item.id == datasetId);
//     if (_selectedDatasetId == datasetId) {
//       _selectedDatasetId = _datasets.isNotEmpty ? _datasets.first.id : null;
//       _records = _datasets.isNotEmpty
//           ? List<CabinetRecord>.from(_datasets.first.records)
//           : <CabinetRecord>[];
//       _invalidateFilteredCache();
//       _defaultInspectorName = _detectInspectorName(_records);
//     }
//     await _persistWorkspace();
//     setState(() {});
//     _showStatusMessage('Đã xóa file ${deleting.fileName}');
//   }

//   void _showDatasetManager() {
//     showModalBottomSheet<void>(
//       isScrollControlled: true,
//       context: context,
//       builder: (context) {
//         return SafeArea(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const ListTile(title: Text('Quản lý tệp dữ liệu')),
//               if (_datasets.isEmpty)
//                 const Padding(
//                   padding: EdgeInsets.all(16),
//                   child: Text('Chưa có file nào được import.'),
//                 )
//               else
//                 Flexible(
//                   child: ListView.builder(
//                     keyboardDismissBehavior:
//                         ScrollViewKeyboardDismissBehavior.onDrag,
//                     addAutomaticKeepAlives: false,
//                     addRepaintBoundaries: true,
//                     shrinkWrap: true,
//                     itemCount: _datasets.length,
//                     itemBuilder: (context, index) {
//                       final dataset = _datasets[index];
//                       final isSelected = dataset.id == _selectedDatasetId;
//                       return ListTile(
//                         leading: Icon(
//                           isSelected
//                               ? Icons.radio_button_checked
//                               : Icons.insert_drive_file,
//                         ),
//                         title: Text(dataset.fileName),
//                         subtitle: Text('${dataset.records.length} tủ'),
//                         onTap: () {
//                           Navigator.of(context).pop();
//                           _selectDataset(dataset.id);
//                         },
//                         trailing: IconButton(
//                           icon: const Icon(Icons.delete_outline),
//                           onPressed: () async {
//                             Navigator.of(context).pop();
//                             await _deleteDataset(dataset.id);
//                           },
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   String _formatMeters(double? value) {
//     if (value == null) return '-';
//     if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)} km';
//     return '${value.toStringAsFixed(0)} m';
//   }

//   @override
//   Widget build(BuildContext context) {
//     final rows = _filteredRecords;
//     return WillPopScope(
//       onWillPop: _onWillPop,
//       child: Scaffold(
//         // Avoid relayout of the whole heavy table when keyboard opens.
//         resizeToAvoidBottomInset: false,
//         appBar: AppBar(
//           title: const Text('Cabinet'),
//           actions: [
//             IconButton(
//               tooltip: 'Quản lý file',
//               onPressed: _showDatasetManager,
//               icon: const Icon(Icons.folder_open),
//             ),
//             IconButton(
//               tooltip: 'Map',
//               onPressed: rows.isEmpty ? null : _openMapView,
//               icon: const Icon(Icons.map),
//             ),
//             IconButton(
//               tooltip: 'Vị trí hiện tại',
//               onPressed: _isBusy ? null : _refreshCurrentLocation,
//               icon: const Icon(Icons.my_location),
//             ),
//             IconButton(
//               tooltip: 'Nơi lưu export',
//               onPressed: _chooseExportLocation,
//               icon: const Icon(Icons.folder_zip),
//             ),
//             IconButton(
//               tooltip: 'Xuất báo cáo',
//               onPressed: _isBusy || _records.isEmpty ? null : _exportReports,
//               icon: const Icon(Icons.file_download),
//             ),
//           ],
//         ),
//         floatingActionButton: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             if (_showScrollToTop)
//               FloatingActionButton.small(
//                 heroTag: 'scrollToTop',
//                 onPressed: () {
//                   if (_tableScrollController.hasClients) {
//                     _tableScrollController.animateTo(
//                       0,
//                       duration: const Duration(milliseconds: 280),
//                       curve: Curves.easeOut,
//                     );
//                   }
//                 },
//                 child: const Icon(Icons.keyboard_double_arrow_up),
//               ),
//             const SizedBox(height: 10),
//             FloatingActionButton(
//               heroTag: 'importFile',
//               onPressed: _isBusy ? null : _importKmz,
//               child: const Icon(Icons.upload_file),
//             ),
//           ],
//         ),
//         body: Listener(
//           behavior: HitTestBehavior.translucent,
//           onPointerDown: (_) => FocusScope.of(context).unfocus(),
//           child: Column(
//             children: [
//               if (_isBusy) const LinearProgressIndicator(),
//               Padding(
//                 padding: EdgeInsets.all(_isMobileLayout(context) ? 6 : 8),
//                 child: Column(
//                   children: [
//                     Wrap(
//                       spacing: _isMobileLayout(context) ? 4 : 8,
//                       runSpacing: _isMobileLayout(context) ? 6 : 8,
//                       alignment: WrapAlignment.start,
//                       children: [
//                         DropdownButton<InspectionStatus?>(
//                           value: _statusFilter,
//                           hint: Text(
//                             _isMobileLayout(context) ? 'Tất cả' : 'Tất cả',
//                             style: TextStyle(
//                               fontSize: _isMobileLayout(context) ? 10 : 12,
//                             ),
//                           ),
//                           items: const [
//                             DropdownMenuItem(
//                               value: null,
//                               child: Text('Tất cả'),
//                             ),
//                             DropdownMenuItem(
//                               value: InspectionStatus.notChecked,
//                               child: Text('Chưa kiểm'),
//                             ),
//                             DropdownMenuItem(
//                               value: InspectionStatus.checked,
//                               child: Text('Đã kiểm'),
//                             ),
//                             DropdownMenuItem(
//                               value: InspectionStatus.recheckNeeded,
//                               child: Text('Cần kiểm lại'),
//                             ),
//                           ],
//                           onChanged: (value) => setState(() {
//                             _statusFilter = value;
//                             _invalidateFilteredCache();
//                           }),
//                         ),
//                         DropdownButton<double?>(
//                           value: _radiusFilter,
//                           hint: Text(
//                             'Mọi khoảng cách',
//                             style: TextStyle(
//                               fontSize: _isMobileLayout(context) ? 10 : 12,
//                             ),
//                           ),
//                           items: const [
//                             DropdownMenuItem(
//                               value: null,
//                               child: Text('Mọi khoảng cách'),
//                             ),
//                             DropdownMenuItem(
//                               value: 300,
//                               child: Text('<= 300 m'),
//                             ),
//                             DropdownMenuItem(
//                               value: 500,
//                               child: Text('<= 500 m'),
//                             ),
//                             DropdownMenuItem(
//                               value: 1000,
//                               child: Text('<= 1 km'),
//                             ),
//                           ],
//                           onChanged: (value) => setState(() {
//                             _radiusFilter = value;
//                             _invalidateFilteredCache();
//                           }),
//                         ),
//                         OutlinedButton.icon(
//                           onPressed: _toggleSortByDistance,
//                           icon: Icon(
//                             _sortAsc
//                                 ? Icons.arrow_upward
//                                 : Icons.arrow_downward,
//                             size: _isMobileLayout(context) ? 16 : 18,
//                           ),
//                           label: Text(
//                             _isMobileLayout(context)
//                                 ? 'Sort'
//                                 : 'Sort khoảng cách',
//                             style: TextStyle(
//                               fontSize: _isMobileLayout(context) ? 10 : 12,
//                             ),
//                           ),
//                         ),
//                         // PopupMenuButton<LocationMarkerIconType>(
//                         //   tooltip: 'Kiểu marker',
//                         //   icon: Icon(
//                         //     _locationIconType.iconData,
//                         //     size: _isMobileLayout(context) ? 18 : 20,
//                         //   ),
//                         //   initialValue: _locationIconType,
//                         //   onSelected: (value) {
//                         //     if (value != _locationIconType) {
//                         //       setState(() => _locationIconType = value);
//                         //     }
//                         //   },
//                         //   itemBuilder: (context) => LocationMarkerIconType.values
//                         //       .map(
//                         //         (value) =>
//                         //             CheckedPopupMenuItem<LocationMarkerIconType>(
//                         //               value: value,
//                         //               checked: value == _locationIconType,
//                         //               child: Row(
//                         //                 children: [
//                         //                   Icon(value.iconData, size: 18),
//                         //                   const SizedBox(width: 8),
//                         //                   Text(value.label),
//                         //                 ],
//                         //               ),
//                         //             ),
//                         //       )
//                         //       .toList(),
//                         // ),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     SizedBox(
//                       width: double.infinity,
//                       child: TextField(
//                         controller: _searchController,
//                         onChanged: (value) {
//                           _searchDebounce?.cancel();
//                           _searchDebounce = Timer(
//                             const Duration(milliseconds: 320),
//                             () {
//                               if (!mounted) return;
//                               if (_searchQuery == value) return;
//                               setState(() {
//                                 _searchQuery = value;
//                                 _invalidateFilteredCache();
//                               });
//                             },
//                           );
//                         },
//                         decoration: InputDecoration(
//                           isDense: true,
//                           hintText: 'Tìm theo mã/tên/tuyến...',
//                           prefixIcon: const Icon(Icons.search),
//                           suffixIcon: _searchQuery.isEmpty
//                               ? null
//                               : IconButton(
//                                   onPressed: () {
//                                     _searchDebounce?.cancel();
//                                     _searchController.clear();
//                                     setState(() {
//                                       _searchQuery = '';
//                                       _invalidateFilteredCache();
//                                     });
//                                   },
//                                   icon: const Icon(Icons.clear),
//                                 ),
//                           border: const OutlineInputBorder(),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: TextField(
//                             controller: _mapRadiusController,
//                             keyboardType: const TextInputType.numberWithOptions(
//                               decimal: true,
//                             ),
//                             decoration: InputDecoration(
//                               isDense: true,
//                               hintText: 'Bán kính map (vd: 200 m)',
//                               hintStyle: TextStyle(
//                                 fontSize: _isMobileLayout(context) ? 10 : 12,
//                               ),
//                               // prefixIcon: const Icon(Icons.radio_button_checked),
//                               suffixIcon:
//                                   _mapRadiusController.text.trim().isEmpty
//                                   ? null
//                                   : IconButton(
//                                       onPressed: () {
//                                         _mapRadiusController.clear();
//                                         setState(() {});
//                                       },
//                                       icon: const Icon(Icons.clear),
//                                     ),
//                               border: const OutlineInputBorder(),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 5),
//                         Expanded(
//                           child: TextField(
//                             controller: _mapCabinetIdsController,
//                             decoration: InputDecoration(
//                               isDense: true,
//                               hintText: 'Mã tủ map: TNH0062, TNH0039',
//                               hintStyle: TextStyle(
//                                 fontSize: _isMobileLayout(context) ? 10 : 12,
//                               ),
//                               // prefixIcon: const Icon(Icons.tag),
//                               suffixIcon:
//                                   _mapCabinetIdsController.text.trim().isEmpty
//                                   ? null
//                                   : IconButton(
//                                       onPressed: () {
//                                         _mapCabinetIdsController.clear();
//                                         setState(() {});
//                                       },
//                                       icon: const Icon(Icons.clear),
//                                     ),
//                               border: const OutlineInputBorder(),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               Expanded(
//                 child: rows.isEmpty
//                     ? const Center(
//                         child: Text(
//                           'Chưa có dữ liệu. Bấm nút upload để import KMZ/KML.',
//                         ),
//                       )
//                     : CabinetTable(
//                         rows: rows,
//                         columnWidths: _getResponsiveColumnWidths(context),
//                         markerIconType: _locationIconType,
//                         tableScrollController: _tableScrollController,
//                         formatMeters: _formatMeters,
//                         onRecordTap: _openRecordDetail,
//                       ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
