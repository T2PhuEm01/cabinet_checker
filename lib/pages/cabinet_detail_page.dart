import 'dart:async';
import 'dart:io';

import 'package:cabinet_checker/models/cabinet_record.dart';
import 'package:cabinet_checker/services/camera_service.dart';
import 'package:cabinet_checker/utils/button_util.dart';
import 'package:cabinet_checker/utils/colors.dart';
import 'package:cabinet_checker/utils/dimens.dart';
import 'package:cabinet_checker/utils/spacers.dart';
import 'package:cabinet_checker/utils/text_field_util.dart';
import 'package:cabinet_checker/utils/text_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

class CabinetDetailPage extends StatefulWidget {
  const CabinetDetailPage({
    super.key,
    required this.record,
    this.defaultInspectorName = '',
  });

  final CabinetRecord record;
  final String defaultInspectorName;

  @override
  State<CabinetDetailPage> createState() => _CabinetDetailPageState();
}

class _CabinetDetailPageState extends State<CabinetDetailPage> {
  final CameraService _cameraService = CameraService();
  late CabinetRecord _record;
  late final TextEditingController _notesController;
  late final TextEditingController _inspectorController;
  late final TextEditingController _otherIssueController;
  DateTime? _selectedCheckedDate;
  bool _pendingPickAfterTimestamp = false;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _notesController = TextEditingController(text: _record.notes);
    final inspectorText = _record.inspectorName.trim().isEmpty
        ? widget.defaultInspectorName
        : _record.inspectorName;
    _inspectorController = TextEditingController(text: inspectorText);
    _otherIssueController = TextEditingController(text: _record.otherIssueType);
    final last = _record.lastCheckedAt;
    if (last != null) {
      _selectedCheckedDate = DateTime(last.year, last.month, last.day);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _inspectorController.dispose();
    _otherIssueController.dispose();
    super.dispose();
  }

  void _saveAndPop() {
    _record.notes = _notesController.text.trim();
    _record.inspectorName = _inspectorController.text.trim();
    _record.otherIssueType = _otherIssueController.text.trim();
    final now = DateTime.now();
    if (_selectedCheckedDate != null) {
      _record.lastCheckedAt = DateTime(
        _selectedCheckedDate!.year,
        _selectedCheckedDate!.month,
        _selectedCheckedDate!.day,
        now.hour,
        now.minute,
        now.second,
      );
    } else if (_record.lastCheckedAt == null) {
      _record.lastCheckedAt = now;
    }
    Navigator.of(context).pop(_record);
  }

  String _formatDateOnly(DateTime value) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year}';
  }

  Future<void> _pickCheckedDate() async {
    final base =
        _selectedCheckedDate ?? _record.lastCheckedAt ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _selectedCheckedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _copyCabinetId() async {
    await Clipboard.setData(ClipboardData(text: _record.id));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã copy mã tủ: ${_record.id}')));
  }

  Future<void> _captureWithTimestampApp() async {
    final opened = await _cameraService.openTimestampCameraOnly();
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Chưa cài Timestamp Camera Free. Mở Play Store để cài.',
          ),
          action: SnackBarAction(
            label: 'Play Store',
            onPressed: () => _cameraService.openTimestampCameraOrStore(),
          ),
        ),
      );
      return;
    }

    _pendingPickAfterTimestamp = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Timestamp đã mở. Chụp ảnh xong quay lại app, ảnh sẽ được chọn để đính kèm.',
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final paths = await _cameraService.pickMultipleFromGallery();
    if (paths.isEmpty) return;

    setState(() {
      _record.photos.addAll(
        paths.map(
          (path) => CabinetPhoto(
            path: path,
            capturedAt: DateTime.now(),
            source: 'gallery',
          ),
        ),
      );
    });
  }

  Future<void> _removePhoto(CabinetPhoto photo) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa ảnh'),
        content: const Text('Bạn có chắc muốn xóa ảnh này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() {
      _record.photos.remove(photo);
    });

    try {
      final file = File(photo.path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa khỏi danh sách nhưng chưa xóa được file ảnh.'),
        ),
      );
    }
  }

  Widget _buildClearSuffix(TextEditingController controller) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.text.trim().isEmpty) {
          return const SizedBox.shrink();
        }
        return IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: controller.clear,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardDismissOnTap(
      child: Scaffold(
        appBar: AppBar(
          title: TextRobotoAutoBold(_record.name, fontSize: 18),
          actions: [
            IconButton(
              tooltip: 'Copy mã tủ',
              onPressed: _copyCabinetId,
              icon: const Icon(Icons.copy),
            ),
            TextButton(onPressed: _saveAndPop, child: const Text('Lưu')),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextRobotoAutoNormal('Mã tủ: ${_record.id}', fontSize: 14),
                TextRobotoAutoNormal(
                  'Tọa độ chuẩn: ${_record.latitudeRef}, ${_record.longitudeRef}',
                  fontSize: 14,
                ),
                vSpacer10(),
                Row(
                  children: [
                    Expanded(
                      child: buttonRoundedWithIcon(
                        iconData: Icons.camera,
                        text: 'Mở Timestamp',
                        bgColor: colorViettel,
                        textColor: Colors.white,
                        textDirection: TextDirection.ltr,
                        onPress: _captureWithTimestampApp,
                      ),
                    ),
                    hSpacer10(),
                    Expanded(
                      child: buttonRoundedWithIcon(
                        iconData: Icons.photo_library,
                        text: 'Thêm từ thư viện',
                        bgColor: Colors.blue,
                        textColor: Colors.white,
                        textDirection: TextDirection.ltr,
                        onPress: _pickFromGallery,
                      ),
                    ),
                  ],
                ),
                vSpacer10(),
                TextRobotoAutoBold(
                  'Ảnh minh chứng (${_record.photos.length})',
                  fontSize: 14,
                ),
                vSpacer10(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _record.photos.map((photo) {
                    return SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () {
                                showDialog<void>(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: Image.file(
                                      File(photo.path),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                );
                              },
                              child: Image.file(
                                File(photo.path),
                                fit: BoxFit.cover,
                                cacheWidth: 220,
                                filterQuality: FilterQuality.low,
                                errorBuilder: (context, error, stackTrace) =>
                                    const ColoredBox(
                                      color: Colors.black12,
                                      child: Icon(Icons.broken_image),
                                    ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _removePhoto(photo),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                vSpacer10(),
                TextRobotoAutoBold(
                  'Trạng thái kiểm tra',
                  fontSize: Dimens.regularFontSizeExtraMid,
                ),
                vSpacer5(),
                Container(
                  width: double.infinity,
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: lightDivider),
                    borderRadius: BorderRadius.circular(
                      Dimens.radiusCornerSmall,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<InspectionStatus>(
                      isDense: true,
                      value: _record.inspectionStatus,
                      hint: TextRobotoAutoNormal(
                        'Trạng thái kiểm tra',
                        fontSize: Dimens.regularFontSizeExtraMid,
                      ),
                      items: InspectionStatus.values
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.labelVi),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _record.inspectionStatus = value);
                        }
                      },
                    ),
                  ),
                ),
                vSpacer10(),
                TextRobotoAutoBold('Kết quả kiểm tra', fontSize: 14),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: _record.isPassed,
                        onChanged: (value) {
                          if (value == true) {
                            setState(() => _record.isPassed = true);
                          }
                        },
                        title: TextRobotoAutoNormal('Đạt', fontSize: 14),
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: !_record.isPassed,
                        onChanged: (value) {
                          if (value == true) {
                            setState(() => _record.isPassed = false);
                          }
                        },
                        title: TextRobotoAutoNormal('Không đạt', fontSize: 14),
                      ),
                    ),
                  ],
                ),
                vSpacer10(),
                TextRobotoAutoBold(
                  'Mức độ',
                  fontSize: Dimens.regularFontSizeExtraMid,
                ),
                vSpacer5(),
                Container(
                  width: double.infinity,
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: lightDivider),
                    borderRadius: BorderRadius.circular(
                      Dimens.radiusCornerSmall,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SeverityLevel>(
                      isDense: true,
                      value: _record.severity,

                      items: SeverityLevel.values
                          .map(
                            (level) => DropdownMenuItem(
                              value: level,
                              child: Text(level.labelVi),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _record.severity = value);
                        }
                      },
                    ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _record.wrongPosition,
                  onChanged: (value) =>
                      setState(() => _record.wrongPosition = value ?? false),
                  title: const Text('Sai vị trí tọa độ'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _record.hangingCable,
                  onChanged: (value) =>
                      setState(() => _record.hangingCable = value ?? false),
                  title: const Text('Treo lơ lửng không đúng cột'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _record.unfixedCable,
                  onChanged: (value) =>
                      setState(() => _record.unfixedCable = value ?? false),
                  title: const Text('Dây cáp chưa buộc cố định'),
                ),
                textFieldWithSuffixIcon(
                  controller: _otherIssueController,
                  labelText: 'Loại lỗi khác',
                  suffixIcon: _buildClearSuffix(_otherIssueController),
                ),
                vSpacer10(),
                textFieldWithSuffixIcon(
                  controller: _inspectorController,
                  labelText: 'Người kiểm tra',
                  suffixIcon: _buildClearSuffix(_inspectorController),
                ),
                vSpacer10(),

                TextRobotoAutoBold('Thời gian kiểm tra', fontSize: 14),
                vSpacer5(),
                if (_record.lastCheckedAt == null)
                  TextRobotoAutoNormal(
                    'Chưa có thời gian trước đó. Khi bấm Lưu sẽ lấy thời gian hiện tại.',
                    fontSize: 13,
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextRobotoAutoNormal(
                        'Ngày đang áp dụng: ${_formatDateOnly(_selectedCheckedDate ?? _record.lastCheckedAt!)}',
                        fontSize: 13,
                      ),
                      TextRobotoAutoNormal(
                        'Giờ/phút/giây sẽ tự lấy tại thời điểm bấm Lưu.',
                        fontSize: 13,
                      ),
                      vSpacer5(),
                      OutlinedButton.icon(
                        onPressed: _pickCheckedDate,
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Chọn ngày tháng năm'),
                      ),
                    ],
                  ),
                vSpacer10(),
                textFieldWithSuffixIcon(
                  controller: _notesController,
                  labelText: 'Ghi chú',
                  maxLines: 4,
                  suffixIcon: _buildClearSuffix(_notesController),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
