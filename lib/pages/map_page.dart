import 'dart:async';
import 'dart:math' as math;
import 'package:cabinet_checker/utils/button_util.dart';
import 'package:cabinet_checker/utils/colors.dart';
import 'package:cabinet_checker/utils/common_utils.dart';
import 'package:cabinet_checker/utils/dimens.dart';
import 'package:cabinet_checker/utils/spacers.dart';
import 'package:cabinet_checker/utils/text_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/cabinet_record.dart';
import '../utils/location_marker_style.dart';
import 'cabinet_detail_page.dart';

enum _MapTileType { standard, satellite, terrain }

extension _MapTileTypeLabel on _MapTileType {
  String get labelVi {
    switch (this) {
      case _MapTileType.standard:
        return 'Mặc định';
      case _MapTileType.satellite:
        return 'Vệ tinh';
      case _MapTileType.terrain:
        return 'Địa hình';
    }
  }

  String get urlTemplate {
    switch (this) {
      case _MapTileType.standard:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case _MapTileType.satellite:
        return 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case _MapTileType.terrain:
        return 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
    }
  }

  int get maxNativeZoom {
    switch (this) {
      case _MapTileType.standard:
        return 19;
      case _MapTileType.satellite:
        return 20;
      case _MapTileType.terrain:
        return 17;
    }
  }
}

class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    required this.records,
    required this.userPos,
    required this.defaultInspectorName,
    required this.markerIconType,
    required this.onRecordUpdated,
  });

  final List<CabinetRecord> records;
  final Position? userPos;
  final String defaultInspectorName;
  final LocationMarkerIconType markerIconType;
  final Future<void> Function(CabinetRecord updated) onRecordUpdated;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  late List<CabinetRecord> _records;
  static const List<double> _radiusOptions = <double>[
    100,
    300,
    500,
    1000,
    2000,
  ];
  Position? _liveUserPos;
  double _headingDeg = 0;
  double _currentZoom = 17;
  _MapTileType _mapTileType = _MapTileType.satellite;
  bool _followUser = true;
  bool _showRecenterButton = false;
  bool _isSearchOpen = false;
  double? _radiusFilterMeters;
  String _codeFilterQuery = '';
  DateTime? _lastLocationUiUpdateAt;
  StreamSubscription<Position>? _positionSub;

  static const double _recenterDistanceThresholdMeters = 250;
  static const double _maxInteractiveZoom = 22;
  static const Duration _minLocationUiUpdateInterval = Duration(
    milliseconds: 100,
  );

  @override
  void initState() {
    super.initState();
    _records = List<CabinetRecord>.from(widget.records);
    _liveUserPos = widget.userPos;
    if (_liveUserPos != null && _liveUserPos!.heading >= 0) {
      _headingDeg = _liveUserPos!.heading;
    }
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  void _startLocationTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
          if (!mounted) return;

          // Update position state directly without full page rebuild
          _liveUserPos = position;
          if (position.heading >= 0) {
            _headingDeg = position.heading;
          }

          // Avoid moving map center while search UI/keyboard is active.
          if (_isSearchOpen) {
            return;
          }

          final now = DateTime.now();
          final canMoveCameraByInterval =
              _lastLocationUiUpdateAt == null ||
              now.difference(_lastLocationUiUpdateAt!) >=
                  _minLocationUiUpdateInterval;

          if (canMoveCameraByInterval) {
            if (_followUser) {
              _mapController.move(
                LatLng(position.latitude, position.longitude),
                _mapController.camera.zoom,
              );
            }
            _lastLocationUiUpdateAt = now;
            _updateRecenterVisibility(_mapController.camera.center);
            // Rebuild UI only on debounced interval for map state updates
            if (mounted) {
              setState(() {});
            }
          }
        });
  }

  void _updateRecenterVisibility(LatLng mapCenter) {
    if (_liveUserPos == null) {
      if (_showRecenterButton) {
        setState(() => _showRecenterButton = false);
      }
      return;
    }

    final meter = _distance(
      LatLng(_liveUserPos!.latitude, _liveUserPos!.longitude),
      mapCenter,
    );
    final shouldShow = meter >= _recenterDistanceThresholdMeters;
    if (shouldShow != _showRecenterButton) {
      setState(() => _showRecenterButton = shouldShow);
    }
  }

  void _focusOnRecord(CabinetRecord record) {
    FocusScope.of(context).unfocus();

    setState(() {
      _followUser = false;
    });

    final target = LatLng(record.latitudeRef, record.longitudeRef);
    final targetZoom = (_currentZoom < 18 ? 18.0 : _currentZoom).clamp(
      3.0,
      _maxInteractiveZoom,
    );
    _mapController.move(target, targetZoom);
    _currentZoom = targetZoom;
    _updateRecenterVisibility(target);
  }

  List<CabinetRecord> get _filteredRecords {
    final query = _codeFilterQuery.trim().toLowerCase();

    return _records.where((record) {
      final codeMatch =
          query.isEmpty || record.id.toLowerCase().contains(query);
      if (!codeMatch) return false;

      if (_radiusFilterMeters == null) return true;
      if (_liveUserPos == null) return true;

      final meter = _distance(
        LatLng(_liveUserPos!.latitude, _liveUserPos!.longitude),
        LatLng(record.latitudeRef, record.longitudeRef),
      );
      return meter <= _radiusFilterMeters!;
    }).toList();
  }

  Future<void> _openFilter() async {
    double? tempRadius = _radiusFilterMeters;
    String tempCode = _codeFilterQuery;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bộ lọc hiển thị tủ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<double?>(
                      value: tempRadius,
                      decoration: const InputDecoration(
                        labelText: 'Bán kính hiển thị quanh vị trí hiện tại',
                      ),
                      items: <DropdownMenuItem<double?>>[
                        const DropdownMenuItem<double?>(
                          value: null,
                          child: Text('Tất cả (không giới hạn)'),
                        ),
                        ..._radiusOptions.map(
                          (value) => DropdownMenuItem<double?>(
                            value: value,
                            child: Text('${value.toStringAsFixed(0)} m'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          tempRadius = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: TextEditingController(text: tempCode)
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: tempCode.length),
                        ),
                      decoration: const InputDecoration(
                        labelText: 'Lọc theo mã tủ (chứa chuỗi)',
                        hintText: 'VD: TNH0024',
                      ),
                      onChanged: (value) {
                        tempCode = value;
                      },
                    ),
                    const SizedBox(height: 8),
                    if (tempRadius != null && _liveUserPos == null)
                      const Text(
                        'Chưa có vị trí hiện tại, bán kính sẽ áp dụng khi lấy được vị trí.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _radiusFilterMeters = null;
                              _codeFilterQuery = '';
                            });
                            Navigator.of(context).pop();
                          },
                          child: const Text('Xóa lọc'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _radiusFilterMeters = tempRadius;
                              _codeFilterQuery = tempCode.trim();
                            });
                            Navigator.of(context).pop();
                          },
                          child: const Text('Áp dụng'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _recenterToUser() {
    final user = _liveUserPos;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa lấy được vị trí hiện tại.')),
      );
      return;
    }

    setState(() {
      _followUser = true;
      _showRecenterButton = false;
    });

    _mapController.move(LatLng(user.latitude, user.longitude), _currentZoom);
  }

  Future<void> _openNavigation(CabinetRecord record) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${record.latitudeRef},${record.longitudeRef}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openRecordBottomSheet(CabinetRecord record) async {
    final updated = await showModalBottomSheet<CabinetRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.95,
        child: CabinetDetailPage(
          record: record.copyWith(),
          defaultInspectorName: widget.defaultInspectorName,
        ),
      ),
    );

    if (updated == null) return;

    final index = _records.indexWhere((item) => item.id == updated.id);
    if (index >= 0) {
      setState(() {
        _records[index] = updated;
      });
      await widget.onRecordUpdated(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật tủ ${updated.name} từ bản đồ.')),
      );
    }
  }

  Widget _buildUserDirectionMarker() {
    final angle = _headingDeg * math.pi / 180;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: 2),
          ),
        ),
        Transform.rotate(
          angle: angle,
          child: const Icon(Icons.navigation, color: Colors.blue, size: 24),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleRecords = _filteredRecords;
    final center = visibleRecords.isNotEmpty
        ? LatLng(
            visibleRecords.first.latitudeRef,
            visibleRecords.first.longitudeRef,
          )
        : _records.isNotEmpty
        ? LatLng(_records.first.latitudeRef, _records.first.longitudeRef)
        : _liveUserPos != null
        ? LatLng(_liveUserPos!.latitude, _liveUserPos!.longitude)
        : const LatLng(21.0285, 105.8542);

    return KeyboardDismissOnTap(
      child: Scaffold(
        appBar: AppBar(
          title: TextRobotoAutoBold('Bản đồ', fontSize: 18),
          actions: [
            buttonOnlyIcon(
              iconColor: Colors.black,
              size: Dimens.iconSizeMid,
              visualDensity: minimumVisualDensity,
              onPress: () async {
                _isSearchOpen = true;
                CabinetRecord? selected;
                try {
                  selected = await showSearch<CabinetRecord?>(
                    context: context,
                    delegate: _CabinetSearchDelegate(visibleRecords),
                  );
                } finally {
                  _isSearchOpen = false;
                }

                if (selected != null && mounted) {
                  _focusOnRecord(selected);
                }
              },
              iconData: Icons.search,
            ),
            hSpacer10(),
            buttonOnlyIcon(
              onPress: _openFilter,
              iconData: Icons.filter_alt_outlined,
              iconColor: Colors.black,
              size: Dimens.iconSizeMid,
              visualDensity: minimumVisualDensity,
            ),
            hSpacer10(),
            PopupMenuButton<_MapTileType>(
              tooltip: 'Đổi loại bản đồ',
              icon: const Icon(Icons.layers),
              initialValue: _mapTileType,
              onSelected: (value) {
                if (value == _mapTileType) return;
                final clampedZoom = _currentZoom.clamp(
                  3.0,
                  _maxInteractiveZoom,
                );
                setState(() {
                  _mapTileType = value;
                  _currentZoom = clampedZoom;
                });
                _mapController.move(_mapController.camera.center, clampedZoom);
              },
              itemBuilder: (context) => _MapTileType.values
                  .map(
                    (type) => CheckedPopupMenuItem<_MapTileType>(
                      value: type,
                      checked: type == _mapTileType,
                      child: Text(type.labelVi),
                    ),
                  )
                  .toList(),
            ),
            hSpacer10(),
            buttonOnlyIcon(
              onPress: () => setState(() => _followUser = !_followUser),
              iconData: _followUser ? Icons.gps_fixed : Icons.gps_not_fixed,
              iconColor: colorViettel,
              size: Dimens.iconSizeMid,
              visualDensity: minimumVisualDensity,
            ),
            hSpacer10(),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 17,
                  maxZoom: _maxInteractiveZoom,
                  minZoom: 3,
                  onPositionChanged: (camera, hasGesture) {
                    _currentZoom = camera.zoom;
                    _updateRecenterVisibility(camera.center);
                    if (hasGesture && _followUser) {
                      setState(() => _followUser = false);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: _mapTileType.urlTemplate,
                    userAgentPackageName: 'cabinet_checker',
                    maxNativeZoom: _mapTileType.maxNativeZoom,
                    maxZoom: _maxInteractiveZoom,
                  ),
                  MarkerLayer(
                    markers: [
                      ...visibleRecords.map((record) {
                        final style = getLocationMarkerStyle(record);
                        return Marker(
                          point: LatLng(
                            record.latitudeRef,
                            record.longitudeRef,
                          ),
                          width: 40,
                          height: 40,
                          child: Tooltip(
                            message: '${record.name} - ${style.statusLabel}',
                            child: InkWell(
                              onTap: () => _openRecordBottomSheet(record),
                              onLongPress: () => _openNavigation(record),
                              child: Icon(
                                widget.markerIconType.iconData,
                                color: style.color,
                              ),
                            ),
                          ),
                        );
                      }),
                      if (_liveUserPos != null)
                        Marker(
                          point: LatLng(
                            _liveUserPos!.latitude,
                            _liveUserPos!.longitude,
                          ),
                          width: 48,
                          height: 48,
                          child: _buildUserDirectionMarker(),
                        ),
                    ],
                  ),
                ],
              ),
              IgnorePointer(
                child: Center(
                  child: Icon(
                    Icons.add,
                    size: 28,
                    color: Colors.red.withOpacity(0.85),
                  ),
                ),
              ),
              if (_showRecenterButton)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10, bottom: 10),
                      child: Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withOpacity(0.92),
                        elevation: 2,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Quay về vị trí hiện tại',
                          onPressed: _recenterToUser,
                          icon: const Icon(Icons.my_location),
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(10),
                            minimumSize: const Size(40, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CabinetSearchDelegate extends SearchDelegate<CabinetRecord?> {
  _CabinetSearchDelegate(this.records);

  final List<CabinetRecord> records;

  @override
  String get searchFieldLabel => 'Tìm mã tủ...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Xóa',
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Đóng',
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildResultList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildResultList(context);

  Widget _buildResultList(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? records.take(20).toList()
        : records
              .where((record) => record.id.toLowerCase().contains(normalized))
              .take(30)
              .toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('Không tìm thấy mã tủ phù hợp.'));
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: Text(item.id),
          subtitle: Text(item.name),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: () => close(context, item),
        );
      },
    );
  }
}
