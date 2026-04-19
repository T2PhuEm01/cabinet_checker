import 'package:cabinet_checker/models/cabinet_dataset.dart';
import 'package:cabinet_checker/services/location_service.dart';
import 'package:cabinet_checker/services/kmz_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

enum ImportKmzStatus { success, canceled, empty, error }

enum CurrentLocationStatus { success, error }

class ImportKmzResult {
  const ImportKmzResult({required this.status, this.dataset, this.error});

  final ImportKmzStatus status;
  final CabinetDataset? dataset;
  final Object? error;
}

class CurrentLocationResult {
  const CurrentLocationResult({
    required this.status,
    this.position,
    this.error,
  });

  final CurrentLocationStatus status;
  final Position? position;
  final Object? error;
}

class HomeController extends GetxController {
  HomeController({KmzService? kmzService, LocationService? locationService})
    : _kmzService = kmzService ?? KmzService(),
      _locationService = locationService ?? LocationService();

  final KmzService _kmzService;
  final LocationService _locationService;
  final TextEditingController searchController = TextEditingController();

  Future<LocationPermissionState> ensureLocationPermission() {
    return _locationService.ensureLocationPermission();
  }

  void clearInputData() {
    searchController.clear();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<ImportKmzResult> importKmz() async {
    try {
      final imported = await _kmzService.importKmz();
      if (imported == null) {
        return const ImportKmzResult(status: ImportKmzStatus.canceled);
      }

      if (imported.records.isEmpty) {
        return const ImportKmzResult(status: ImportKmzStatus.empty);
      }

      final dataset = CabinetDataset(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: imported.fileName,
        importedAt: DateTime.now(),
        records: imported.records,
      );

      return ImportKmzResult(status: ImportKmzStatus.success, dataset: dataset);
    } catch (error) {
      return ImportKmzResult(status: ImportKmzStatus.error, error: error);
    }
  }

  Future<CurrentLocationResult> refreshCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      return CurrentLocationResult(
        status: CurrentLocationStatus.success,
        position: position,
      );
    } catch (error) {
      return CurrentLocationResult(
        status: CurrentLocationStatus.error,
        error: error,
      );
    }
  }
}
