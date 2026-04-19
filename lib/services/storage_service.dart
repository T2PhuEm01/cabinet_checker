import 'dart:io';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/cabinet_dataset.dart';

class StorageService {
  static const String _legacyFileName = 'cabinet_workspace.json';
  static const String _boxName = 'cabinet_workspace_db';
  static const String _workspaceKey = 'workspace_state';

  static bool _hiveInitialized = false;

  Future<CabinetWorkspaceState> loadWorkspace() async {
    final box = await _openBox();
    final raw = box.get(_workspaceKey);
    if (raw is Map) {
      return CabinetWorkspaceState.fromMap(Map<String, dynamic>.from(raw));
    }

    final migrated = await _migrateFromLegacyJsonIfNeeded(box);
    if (migrated != null) {
      return migrated;
    }

    return CabinetWorkspaceState(datasets: <CabinetDataset>[]);
  }

  Future<void> saveWorkspace(CabinetWorkspaceState state) async {
    final box = await _openBox();
    await box.put(_workspaceKey, state.toMap());
  }

  Future<Box<dynamic>> _openBox() async {
    final dir = await getApplicationDocumentsDirectory();
    if (!_hiveInitialized) {
      Hive.init(dir.path);
      _hiveInitialized = true;
    }
    return Hive.isBoxOpen(_boxName)
        ? Hive.box<dynamic>(_boxName)
        : await Hive.openBox<dynamic>(_boxName);
  }

  Future<CabinetWorkspaceState?> _migrateFromLegacyJsonIfNeeded(
    Box<dynamic> box,
  ) async {
    final legacyFile = await _getLegacyFile();
    if (!legacyFile.existsSync()) return null;

    final raw = await legacyFile.readAsString();
    if (raw.trim().isEmpty) return null;

    final map = jsonDecode(raw);
    if (map is! Map<String, dynamic>) return null;

    final state = CabinetWorkspaceState.fromMap(map);
    await box.put(_workspaceKey, state.toMap());
    return state;
  }

  Future<File> _getLegacyFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_legacyFileName');
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    return file;
  }
}
