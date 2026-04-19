import 'dart:io';
import 'dart:convert';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';

import '../models/cabinet_record.dart';

class ImportedCabinetFile {
  ImportedCabinetFile({
    required this.fileName,
    required this.records,
  });

  final String fileName;
  final List<CabinetRecord> records;
}

class KmzService {
  Future<ImportedCabinetFile?> importKmz() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['kmz', 'kml'],
    );

    if (result == null) return null;

    final fileName = result.files.single.name;
    final filePath = result.files.single.path;
    if (filePath == null) return null;

    final file = File(filePath);
    final lowercasePath = file.path.toLowerCase();

    String kmlContent = '';

    /// Nếu là KMZ → giải nén
    if (lowercasePath.endsWith('.kmz')) {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final archiveFile in archive) {
        if (!archiveFile.name.toLowerCase().endsWith('.kml')) continue;
        if (!archiveFile.isFile) continue;

        final content = archiveFile.content;
        if (content is List<int>) {
          kmlContent = utf8.decode(content, allowMalformed: true);
          break;
        }

        if (content is String) {
          kmlContent = content;
          break;
        }
      }
    }

    /// Nếu là KML
    else {
      kmlContent = await file.readAsString();
    }

    if (kmlContent.trim().isEmpty) {
      throw const FormatException('KMZ/KML không chứa dữ liệu KML hợp lệ.');
    }

    // Parse XML in a background isolate to avoid blocking UI thread.
    final parsed = await Isolate.run(() => _parseKmlContent(kmlContent));
    return ImportedCabinetFile(fileName: fileName, records: parsed);
  }
}

List<CabinetRecord> _parseKmlContent(String kmlContent) {
  final cabinets = <CabinetRecord>[];
  final document = XmlDocument.parse(kmlContent);
  final placemarks = document.findAllElements('Placemark');
  final seenIds = <String>{};

  for (final place in placemarks) {
    final nameElement = place.findElements('name');
    final coordinatesElement = place.findAllElements('coordinates');
    if (nameElement.isEmpty || coordinatesElement.isEmpty) continue;

    final name = nameElement.first.innerText.trim();
    final coordText = coordinatesElement.first.innerText.trim();
    final firstPoint = coordText.split(RegExp(r'\s+')).first;
    final coords = firstPoint.split(',');
    if (coords.length < 2) continue;

    final longitude = double.tryParse(coords[0]);
    final latitude = double.tryParse(coords[1]);
    if (longitude == null || latitude == null) continue;

    final cleanName = name.isEmpty ? 'Unnamed Cabinet' : name;
    var id = cleanName;
    var idx = 1;
    while (seenIds.contains(id)) {
      id = '$cleanName-$idx';
      idx += 1;
    }
    seenIds.add(id);

    cabinets.add(
      CabinetRecord(
        id: id,
        name: cleanName,
        latitudeRef: latitude,
        longitudeRef: longitude,
      ),
    );
  }

  return cabinets;
}