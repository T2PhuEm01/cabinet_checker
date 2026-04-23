import 'package:cabinet_checker/models/cabinet_dataset.dart';
import 'package:cabinet_checker/models/cabinet_record.dart';
import 'package:flutter/material.dart';

class HomeDatasetSelectionResult {
  const HomeDatasetSelectionResult({
    required this.selectedDatasetId,
    required this.records,
    required this.message,
  });

  final String selectedDatasetId;
  final List<CabinetRecord> records;
  final String message;
}

class HomeDatasetDeleteResult {
  const HomeDatasetDeleteResult({
    required this.datasets,
    required this.selectedDatasetId,
    required this.records,
    required this.message,
  });

  final List<CabinetDataset> datasets;
  final String? selectedDatasetId;
  final List<CabinetRecord> records;
  final String message;
}

class HomeDatasetManager {
  static HomeDatasetSelectionResult selectDataset({
    required List<CabinetDataset> datasets,
    required String datasetId,
  }) {
    final dataset = datasets.firstWhere((item) => item.id == datasetId);
    return HomeDatasetSelectionResult(
      selectedDatasetId: dataset.id,
      records: List<CabinetRecord>.from(dataset.records),
      message: 'Đang xem file: ${dataset.fileName}',
    );
  }

  static HomeDatasetDeleteResult deleteDataset({
    required List<CabinetDataset> datasets,
    required String datasetId,
    required String? selectedDatasetId,
    required List<CabinetRecord> currentRecords,
  }) {
    final deleting = datasets.firstWhere((item) => item.id == datasetId);
    final nextDatasets = List<CabinetDataset>.from(datasets)
      ..removeWhere((item) => item.id == datasetId);

    String? nextSelected = selectedDatasetId;
    List<CabinetRecord> nextRecords = List<CabinetRecord>.from(currentRecords);

    if (selectedDatasetId == datasetId) {
      if (nextDatasets.isEmpty) {
        nextSelected = null;
        nextRecords = <CabinetRecord>[];
      } else {
        final next = nextDatasets.first;
        nextSelected = next.id;
        nextRecords = List<CabinetRecord>.from(next.records);
      }
    }

    return HomeDatasetDeleteResult(
      datasets: nextDatasets,
      selectedDatasetId: nextSelected,
      records: nextRecords,
      message: 'Đã xóa file ${deleting.fileName}',
    );
  }

  static void showDatasetManagerSheet({
    required BuildContext context,
    required List<CabinetDataset> datasets,
    required String? selectedDatasetId,
    required void Function(String datasetId) onSelect,
    required Future<void> Function(String datasetId) onDelete,
    required Future<void> Function() onBackup,
    required Future<void> Function() onRestore,
  }) {
    showModalBottomSheet<void>(
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Danh sách file đã import')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await onBackup();
                        },
                        icon: const Icon(Icons.backup_outlined),
                        label: const Text('Sao lưu'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await onRestore();
                        },
                        icon: const Icon(Icons.restore),
                        label: const Text('Khôi phục'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Khi sao lưu, bạn sẽ được chọn vị trí lưu file backup (.json). '
                  'Khôi phục nên chọn file có tên cabinet_workspace_backup_*.json.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              if (datasets.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Chưa có file nào được import.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    shrinkWrap: true,
                    itemCount: datasets.length,
                    itemBuilder: (context, index) {
                      final dataset = datasets[index];
                      final isSelected = dataset.id == selectedDatasetId;
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
                          onSelect(dataset.id);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await onDelete(dataset.id);
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
}
