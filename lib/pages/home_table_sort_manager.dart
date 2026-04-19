import 'package:cabinet_checker/models/cabinet_record.dart';

enum HomeTableSortField { none, stt, distance }

class HomeTableSortState {
  const HomeTableSortState({required this.field, required this.ascending});

  const HomeTableSortState.none()
    : field = HomeTableSortField.none,
      ascending = true;

  final HomeTableSortField field;
  final bool ascending;

  bool get isStt => field == HomeTableSortField.stt;
  bool get isDistance => field == HomeTableSortField.distance;
}

class HomeTableSortManager {
  const HomeTableSortManager._();

  static HomeTableSortState toggleStt(HomeTableSortState current) {
    if (current.field == HomeTableSortField.stt) {
      return HomeTableSortState(
        field: HomeTableSortField.stt,
        ascending: !current.ascending,
      );
    }
    return const HomeTableSortState(
      field: HomeTableSortField.stt,
      ascending: true,
    );
  }

  static HomeTableSortState toggleDistance(HomeTableSortState current) {
    if (current.field == HomeTableSortField.distance) {
      return HomeTableSortState(
        field: HomeTableSortField.distance,
        ascending: !current.ascending,
      );
    }
    return const HomeTableSortState(
      field: HomeTableSortField.distance,
      ascending: true,
    );
  }

  static List<CabinetRecord> applySort({
    required List<CabinetRecord> records,
    required HomeTableSortState state,
  }) {
    if (state.field == HomeTableSortField.none || records.length < 2) {
      return records;
    }

    final sorted = List<CabinetRecord>.from(records);

    if (state.field == HomeTableSortField.stt) {
      if (!state.ascending) {
        return sorted.reversed.toList();
      }
      return sorted;
    }

    sorted.sort((a, b) {
      final aDistance = a.distanceToUserMeters;
      final bDistance = b.distanceToUserMeters;

      if (aDistance == null && bDistance == null) return 0;
      if (aDistance == null) return 1;
      if (bDistance == null) return -1;
      return aDistance.compareTo(bDistance);
    });

    if (!state.ascending) {
      return sorted.reversed.toList();
    }
    return sorted;
  }
}
