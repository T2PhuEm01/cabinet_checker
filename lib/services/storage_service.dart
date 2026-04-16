import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';

import '../models/cabinet_dataset.dart';

class StorageService {
  static const String _fileName = 'cabinet_workspace.json';

  Future<CabinetWorkspaceState> loadWorkspace() async {
    final file = await _getFile();
    if (!file.existsSync()) {
      return CabinetWorkspaceState(datasets: <CabinetDataset>[]);
    }
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return CabinetWorkspaceState(datasets: <CabinetDataset>[]);
    }
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return CabinetWorkspaceState.fromMap(map);
  }

  Future<void> saveWorkspace(CabinetWorkspaceState state) async {
    final file = await _getFile();
    await file.writeAsString(jsonEncode(state.toMap()));
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_fileName');
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    return file;
  }
}
