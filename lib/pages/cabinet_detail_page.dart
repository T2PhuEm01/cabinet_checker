import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/cabinet_record.dart';
import '../services/camera_service.dart';

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

class _CabinetDetailPageState extends State<CabinetDetailPage>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  late CabinetRecord _record;
  late final TextEditingController _notesController;
  late final TextEditingController _inspectorController;
  late final TextEditingController _otherIssueController;
  Timer? _timeTicker;
  DateTime? _checkedAt;
  bool _autoCheckedTime = true;
  bool _pendingPickAfterTimestamp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _record = widget.record;
    _checkedAt = _record.lastCheckedAt;
    _autoCheckedTime = _record.lastCheckedAt == null;
    if (_autoCheckedTime) {
      _checkedAt = DateTime.now();
      _startCheckedTimeTicker();
    }
    _notesController = TextEditingController(text: _record.notes);
    final inspectorText = _record.inspectorName.trim().isEmpty
        ? widget.defaultInspectorName
        : _record.inspectorName;
    _inspectorController = TextEditingController(text: inspectorText);
    _otherIssueController = TextEditingController(text: _record.otherIssueType);
  }

  @override
  void dispose() {
    _timeTicker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _notesController.dispose();
    _inspectorController.dispose();
    _otherIssueController.dispose();
    super.dispose();
  }

  void _startCheckedTimeTicker() {
    _timeTicker?.cancel();
    _timeTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_autoCheckedTime) return;
      setState(() {
        _checkedAt = DateTime.now();
      });
    });
  }

  void _setAutoCheckedTime(bool enabled) {
    setState(() {
      _autoCheckedTime = enabled;
      if (enabled) {
        _checkedAt = DateTime.now();
      }
    });

    if (enabled) {
      _startCheckedTimeTicker();
    } else {
      _timeTicker?.cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingPickAfterTimestamp) {
      _pendingPickAfterTimestamp = false;
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        _pickFromGallery();
      });
    }
  }

  void _saveAndPop() {
    _record.notes = _notesController.text.trim();
    _record.inspectorName = _inspectorController.text.trim();
    _record.otherIssueType = _otherIssueController.text.trim();
    _record.lastCheckedAt = _checkedAt ?? DateTime.now();
    Navigator.of(context).pop(_record);
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Chưa đặt (sẽ lấy thời gian hiện tại khi Lưu)';

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}:${twoDigits(value.second)}';
  }

  Future<void> _pickCheckedDate() async {
    if (_autoCheckedTime) {
      _setAutoCheckedTime(false);
    }
    final base = _checkedAt ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      _checkedAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        base.hour,
        base.minute,
        base.second,
      );
    });
  }

  Future<void> _pickCheckedTime() async {
    if (_autoCheckedTime) {
      _setAutoCheckedTime(false);
    }
    final base = _checkedAt ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) return;

    setState(() {
      _checkedAt = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
        base.second,
      );
    });
  }

  void _setCheckedSecond(int second) {
    if (_autoCheckedTime) {
      _setAutoCheckedTime(false);
    }
    final base = _checkedAt ?? DateTime.now();
    setState(() {
      _checkedAt = DateTime(
        base.year,
        base.month,
        base.day,
        base.hour,
        base.minute,
        second,
      );
    });
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
    final path = await _cameraService.pickFromGallery();
    if (path == null) return;

    setState(() {
      _record.photos.add(
        CabinetPhoto(path: path, capturedAt: DateTime.now(), source: 'gallery'),
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

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_record.name),
        actions: [TextButton(onPressed: _saveAndPop, child: const Text('Lưu'))],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + safeBottom + 24),
        children: [
          Text('Mã tủ: ${_record.id}'),
          Text('Tọa độ chuẩn: ${_record.latitudeRef}, ${_record.longitudeRef}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _captureWithTimestampApp,
                icon: const Icon(Icons.camera),
                label: const Text('Mở Timestamp'),
              ),
              ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Thêm từ thư viện'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Ảnh minh chứng (${_record.photos.length})'),
          const SizedBox(height: 6),
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
          const SizedBox(height: 8),
          DropdownButtonFormField<InspectionStatus>(
            initialValue: _record.inspectionStatus,
            decoration: const InputDecoration(labelText: 'Trạng thái kiểm tra'),
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
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _record.isPassed,
            onChanged: (value) =>
                setState(() => _record.isPassed = value ?? false),
            title: const Text('Tủ đạt yêu cầu'),
            subtitle: Text(_record.isPassed ? 'Đạt' : 'Không đạt'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<SeverityLevel>(
            initialValue: _record.severity,
            decoration: const InputDecoration(labelText: 'Mức độ'),
            items: SeverityLevel.values
                .map(
                  (level) =>
                      DropdownMenuItem(value: level, child: Text(level.name)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _record.severity = value);
              }
            },
          ),
          const SizedBox(height: 8),
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
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _record.otherIssue,
            onChanged: (value) =>
                setState(() => _record.otherIssue = value ?? false),
            title: const Text('Lỗi khác'),
          ),
          TextField(
            controller: _otherIssueController,
            decoration: const InputDecoration(labelText: 'Loại lỗi khác'),
          ),
          TextField(
            controller: _inspectorController,
            decoration: const InputDecoration(labelText: 'Người kiểm tra'),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Thời gian kiểm tra'),
            subtitle: Text(_formatDateTime(_checkedAt)),
            trailing: IconButton(
              tooltip: 'Xóa thời gian',
              onPressed: () {
                if (_autoCheckedTime) {
                  _setAutoCheckedTime(false);
                }
                setState(() => _checkedAt = null);
              },
              icon: const Icon(Icons.clear),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _autoCheckedTime,
            onChanged: _setAutoCheckedTime,
            title: const Text('Tự chạy thời gian (Timer)'),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickCheckedDate,
                icon: const Icon(Icons.calendar_month),
                label: const Text('Chọn ngày'),
              ),
              OutlinedButton.icon(
                onPressed: _pickCheckedTime,
                icon: const Icon(Icons.access_time),
                label: const Text('Chọn giờ'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  if (_autoCheckedTime) {
                    _setAutoCheckedTime(false);
                  }
                  setState(() => _checkedAt = DateTime.now());
                },
                icon: const Icon(Icons.update),
                label: const Text('Lấy hiện tại'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: (_checkedAt ?? DateTime.now()).second,
            decoration: const InputDecoration(labelText: 'Giây'),
            items: List<DropdownMenuItem<int>>.generate(
              60,
              (index) => DropdownMenuItem<int>(
                value: index,
                child: Text(index.toString().padLeft(2, '0')),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                _setCheckedSecond(value);
              }
            },
          ),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}
