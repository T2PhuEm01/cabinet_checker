import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

import '../../services/export_service.dart';

enum ExportRecordStatusFilter { all, checked, notChecked, recheckNeeded }

enum ExportDestination { files, googleSheets }

extension ExportDestinationLabel on ExportDestination {
  String get labelVi {
    switch (this) {
      case ExportDestination.files:
        return 'Tải file về máy';
      case ExportDestination.googleSheets:
        return 'Đẩy lên Google Sheets';
    }
  }
}

extension ExportRecordStatusFilterLabel on ExportRecordStatusFilter {
  String get labelVi {
    switch (this) {
      case ExportRecordStatusFilter.all:
        return 'Tất cả';
      case ExportRecordStatusFilter.checked:
        return 'Đã kiểm';
      case ExportRecordStatusFilter.notChecked:
        return 'Chưa kiểm';
      case ExportRecordStatusFilter.recheckNeeded:
        return 'Cần kiểm lại';
    }
  }
}

class ExportOptions {
  const ExportOptions({
    required this.destination,
    required this.statusFilter,
    required this.imageMode,
    this.appsScriptUrl,
    this.sheetName,
    this.fromDate,
    this.toDate,
  });

  final ExportDestination destination;
  final ExportRecordStatusFilter statusFilter;
  final ExportImageMode imageMode;
  final String? appsScriptUrl;
  final String? sheetName;
  final DateTime? fromDate;
  final DateTime? toDate;
}

Future<ExportOptions?> showExportOptionsDialog({
  required BuildContext context,
  required String? initialAppsScriptUrl,
  required String defaultSheetName,
  required void Function(String message) showStatusMessage,
}) async {
  const destination = ExportDestination.googleSheets;
  ExportRecordStatusFilter statusFilter = ExportRecordStatusFilter.all;
  const imageMode = ExportImageMode.original;
  DateTime? fromDate;
  DateTime? toDate;
  String appsScriptUrlValue = initialAppsScriptUrl ?? '';
  String sheetNameValue = defaultSheetName;

  final result = await showDialog<ExportOptions>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickFromDate() async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: fromDate ?? now,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked == null) return;
            setDialogState(() {
              fromDate = picked;
              if (toDate != null && toDate!.isBefore(fromDate!)) {
                toDate = fromDate;
              }
            });
          }

          Future<void> pickToDate() async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: toDate ?? fromDate ?? now,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked == null) return;
            setDialogState(() {
              toDate = picked;
              if (fromDate != null && toDate!.isBefore(fromDate!)) {
                fromDate = toDate;
              }
            });
          }

          return KeyboardDismissOnTap(
            child: AlertDialog(
              title: const Text('Tùy chọn xuất báo cáo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<ExportRecordStatusFilter>(
                        value: statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Trạng thái xuất',
                        ),
                        items: ExportRecordStatusFilter.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.labelVi),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => statusFilter = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: appsScriptUrlValue,
                      decoration: const InputDecoration(
                        labelText: 'URL Google Apps Script (/exec)',
                        hintText: 'https://script.google.com/macros/s/.../exec',
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      onChanged: (value) => appsScriptUrlValue = value,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: sheetNameValue,
                      decoration: const InputDecoration(
                        labelText: 'Tên trang tính cho lần xuất này',
                        hintText: 'VD: BaoCao_20260417_0930',
                      ),
                      autocorrect: false,
                      onChanged: (value) => sheetNameValue = value,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ảnh gốc sẽ gửi lên Apps Script để lưu Drive, không bị giảm chất lượng như XLSX.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Từ ngày'),
                      subtitle: Text(
                        fromDate == null
                            ? 'Không giới hạn'
                            : _formatDateOnly(fromDate!),
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Xóa',
                            onPressed: () =>
                                setDialogState(() => fromDate = null),
                            icon: const Icon(Icons.clear),
                          ),
                          IconButton(
                            tooltip: 'Chọn ngày',
                            onPressed: pickFromDate,
                            icon: const Icon(Icons.calendar_month),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Đến ngày'),
                      subtitle: Text(
                        toDate == null
                            ? 'Không giới hạn'
                            : _formatDateOnly(toDate!),
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Xóa',
                            onPressed: () =>
                                setDialogState(() => toDate = null),
                            icon: const Icon(Icons.clear),
                          ),
                          IconButton(
                            tooltip: 'Chọn ngày',
                            onPressed: pickToDate,
                            icon: const Icon(Icons.calendar_month),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    final scriptUrl = appsScriptUrlValue.trim();
                    final sheetName = sheetNameValue.trim();
                    if (scriptUrl.isEmpty) {
                      showStatusMessage(
                        'Vui lòng nhập URL Google Apps Script.',
                      );
                      return;
                    }
                    if (sheetName.isEmpty) {
                      showStatusMessage(
                        'Vui lòng nhập tên trang tính cần tạo.',
                      );
                      return;
                    }

                    Navigator.of(context).pop(
                      ExportOptions(
                        destination: destination,
                        statusFilter: statusFilter,
                        imageMode: imageMode,
                        appsScriptUrl: scriptUrl.isEmpty ? null : scriptUrl,
                        sheetName: sheetName.isEmpty ? null : sheetName,
                        fromDate: fromDate,
                        toDate: toDate,
                      ),
                    );
                  },
                  child: const Text('Xuất'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  return result;
}

String _formatDateOnly(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
