import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/cabinet_record.dart';
import '../utils/location_marker_style.dart';
import 'cabinet_detail_page.dart';

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
  late List<CabinetRecord> _records;
  Position? _liveUserPos;
  double _headingDeg = 0;
  bool _followUser = true;
  StreamSubscription<Position>? _positionSub;

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
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
          if (!mounted) return;
          setState(() {
            _liveUserPos = position;
            if (position.heading >= 0) {
              _headingDeg = position.heading;
            }
          });

          if (_followUser) {
            _mapController.move(
              LatLng(position.latitude, position.longitude),
              _mapController.camera.zoom,
            );
          }
        });
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
    final center = _records.isNotEmpty
        ? LatLng(_records.first.latitudeRef, _records.first.longitudeRef)
        : _liveUserPos != null
        ? LatLng(_liveUserPos!.latitude, _liveUserPos!.longitude)
        : const LatLng(21.0285, 105.8542);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ tủ cáp (Vệ tinh)'),
        actions: [
          IconButton(
            tooltip: _followUser
                ? 'Tắt bám theo vị trí'
                : 'Bật bám theo vị trí',
            onPressed: () => setState(() => _followUser = !_followUser),
            icon: Icon(_followUser ? Icons.gps_fixed : Icons.gps_not_fixed),
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 17,
          onPositionChanged: (camera, hasGesture) {
            if (hasGesture && _followUser) {
              setState(() => _followUser = false);
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'cabinet_checker',
          ),
          MarkerLayer(
            markers: [
              ..._records.map((record) {
                final style = getLocationMarkerStyle(record);
                return Marker(
                  point: LatLng(record.latitudeRef, record.longitudeRef),
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
    );
  }
}
