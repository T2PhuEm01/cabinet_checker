import 'package:geolocator/geolocator.dart';

enum LocationPermissionState { granted, serviceDisabled, denied, deniedForever }

class LocationService {
  Future<LocationPermissionState> ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionState.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionState.deniedForever;
    }

    if (permission == LocationPermission.denied) {
      return LocationPermissionState.denied;
    }

    return LocationPermissionState.granted;
  }

  Future<Position> getCurrentPosition() async {
    final permissionState = await ensureLocationPermission();
    if (permissionState == LocationPermissionState.serviceDisabled) {
      throw Exception('Location services are disabled.');
    }

    if (permissionState == LocationPermissionState.denied ||
        permissionState == LocationPermissionState.deniedForever) {
      throw Exception('Location permission is denied.');
    }

    return Geolocator.getCurrentPosition();
  }

  double distanceBetween({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
