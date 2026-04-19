import 'package:flutter/material.dart';

import '../models/cabinet_record.dart';
import '../utils/location_marker_style.dart';

class CabinetTable extends StatelessWidget {
  const CabinetTable({
    super.key,
    required this.rows,
    required this.columnWidths,
    required this.markerIconType,
    required this.tableScrollController,
    required this.formatMeters,
    required this.onRecordTap,
    this.onSttHeaderTap,
    this.onDistanceHeaderTap,
    this.isSortByStt = false,
    this.isSortByDistance = false,
    this.sortAscending = true,
  });

  final List<CabinetRecord> rows;
  final List<double> columnWidths;
  final LocationMarkerIconType markerIconType;
  final ScrollController tableScrollController;
  final String Function(double? value) formatMeters;
  final void Function(CabinetRecord record) onRecordTap;
  final VoidCallback? onSttHeaderTap;
  final VoidCallback? onDistanceHeaderTap;
  final bool isSortByStt;
  final bool isSortByDistance;
  final bool sortAscending;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        width: columnWidths.reduce((a, b) => a + b),
        child: Column(
          children: [
            _TableHeader(
              columnWidths: columnWidths,
              onSttHeaderTap: onSttHeaderTap,
              onDistanceHeaderTap: onDistanceHeaderTap,
              isSortByStt: isSortByStt,
              isSortByDistance: isSortByDistance,
              sortAscending: sortAscending,
            ),
            Expanded(
              child: ListView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                cacheExtent: 600,
                controller: tableScrollController,
                itemExtent: 42,
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final item = rows[index];
                  return _TableRow(
                    index: index,
                    item: item,
                    columnWidths: columnWidths,
                    markerIconType: markerIconType,
                    formatMeters: formatMeters,
                    onTap: () => onRecordTap(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.columnWidths,
    required this.onSttHeaderTap,
    required this.onDistanceHeaderTap,
    required this.isSortByStt,
    required this.isSortByDistance,
    required this.sortAscending,
  });

  final List<double> columnWidths;
  final VoidCallback? onSttHeaderTap;
  final VoidCallback? onDistanceHeaderTap;
  final bool isSortByStt;
  final bool isSortByDistance;
  final bool sortAscending;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderCell(text: '', width: columnWidths[0]),
        _HeaderCell(
          text: _buildSortLabel('STT', isSortByStt, sortAscending),
          width: columnWidths[1],
          onTap: onSttHeaderTap,
        ),
        _HeaderCell(text: 'Mã tủ', width: columnWidths[2]),
        _HeaderCell(text: 'Lat chuẩn', width: columnWidths[3]),
        _HeaderCell(text: 'Lng chuẩn', width: columnWidths[4]),
        _HeaderCell(
          text: _buildSortLabel('Khoảng cách', isSortByDistance, sortAscending),
          width: columnWidths[5],
          onTap: onDistanceHeaderTap,
        ),
        _HeaderCell(text: 'Sai số', width: columnWidths[6]),
        _HeaderCell(text: 'Trạng thái', width: columnWidths[7]),
        _HeaderCell(text: 'Mức độ', width: columnWidths[8]),
        _HeaderCell(text: 'Ảnh', width: columnWidths[9]),
      ],
    );
  }

  String _buildSortLabel(String base, bool active, bool ascending) {
    if (!active) return base;
    return ascending ? '$base ↑' : '$base ↓';
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.index,
    required this.item,
    required this.columnWidths,
    required this.markerIconType,
    required this.formatMeters,
    required this.onTap,
  });

  final int index;
  final CabinetRecord item;
  final List<double> columnWidths;
  final LocationMarkerIconType markerIconType;
  final String Function(double? value) formatMeters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = getLocationMarkerStyle(item);

    return RepaintBoundary(
      child: InkWell(
        key: ValueKey(item.id),
        onTap: onTap,
        child: Row(
          children: [
            _LocationStatusCell(
              width: columnWidths[0],
              iconData: markerIconType.iconData,
              color: style.color,
              statusLabel: style.statusLabel,
            ),
            _DataCell(text: '${index + 1}', width: columnWidths[1]),
            _DataCell(text: item.id, width: columnWidths[2]),
            _DataCell(
              text: item.latitudeRef.toStringAsFixed(6),
              width: columnWidths[3],
            ),
            _DataCell(
              text: item.longitudeRef.toStringAsFixed(6),
              width: columnWidths[4],
            ),
            _DataCell(
              text: formatMeters(item.distanceToUserMeters),
              width: columnWidths[5],
            ),
            _DataCell(
              text: formatMeters(item.coordinateDeviationMeters),
              width: columnWidths[6],
            ),
            _DataCell(
              text: item.inspectionStatus.labelVi,
              width: columnWidths[7],
            ),
            _DataCell(text: item.severity.labelVi, width: columnWidths[8]),
            _DataCell(text: '${item.photos.length}', width: columnWidths[9]),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.text, required this.width, this.onTap});

  final String text;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cell = Container(
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

    if (onTap == null) return cell;

    return InkWell(onTap: onTap, child: cell);
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell({required this.text, required this.width});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
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
}

class _LocationStatusCell extends StatelessWidget {
  const _LocationStatusCell({
    required this.width,
    required this.iconData,
    required this.color,
    required this.statusLabel,
  });

  final double width;
  final IconData iconData;
  final Color color;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
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
        message: statusLabel,
        child: Icon(iconData, size: 18, color: color),
      ),
    );
  }
}
