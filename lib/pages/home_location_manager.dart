import 'package:cabinet_checker/models/cabinet_record.dart';
import 'package:geolocator/geolocator.dart';

class HomeLocationManager {
  static void applyDistanceFromCurrentPosition({
    required Position currentPosition,
    required List<CabinetRecord> records,
  }) {
    for (final record in records) {
      record.distanceToUserMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        record.latitudeRef,
        record.longitudeRef,
      );

      if (record.latitudeActual != null && record.longitudeActual != null) {
        record.coordinateDeviationMeters = Geolocator.distanceBetween(
          record.latitudeRef,
          record.longitudeRef,
          record.latitudeActual!,
          record.longitudeActual!,
        );
      }
    }
  }

  static String formatMeters(double? value) {
    if (value == null) return '-';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)} km';
    return '${value.toStringAsFixed(0)} m';
  }
}
