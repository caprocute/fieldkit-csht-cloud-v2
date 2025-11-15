import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:fk/configuration.dart';
import 'package:fk/diagnostics.dart';

// Type definitions for JSON structures
typedef JsonMap = Map<String, Object?>;
typedef JsonList = List<Object?>;

class Paths {
  static Future<Directory> deviceData(String deviceId) async {
    final storage = Configuration.instance.storagePath;
    return Directory("$storage/fk-data/$deviceId");
  }

  static Future<File> deviceLogs(String deviceId) async {
    final storage = Configuration.instance.storagePath;
    return File("$storage/fk-data/$deviceId/logs.txt");
  }

  static Future<String> dataFile(String deviceId, String id) async {
    final directory = await Paths.deviceData(deviceId);
    return "${directory.path}/$id.fkpb";
  }

  static Future<List<DataFile>> findDataFiles(String deviceId) async {
    final dir = await Paths.deviceData(deviceId);
    if (!await dir.exists()) {
      return List.empty();
    }
    final entries = await dir.list(recursive: false).toList();
    final List<DataFile> files = List.empty(growable: true);
    for (final entry in entries) {
      if (entry.path.endsWith(".fkpb.json")) {
        final file = File(entry.path);
        final body = await file.readAsString();
        final dataPath = entry.path.replaceAll(".json", "");
        final size = await File(dataPath).length();
        try {
          final file = DataFile(
            path: dataPath,
            size: size,
            meta: DownloadMeta.fromJson(jsonDecode(body)),
          );
          files.add(file);
        } catch (e) {
          Loggers.state.e("${entry.path} malformed: $e");
        }
      }
    }
    return files.sortedBy<num>((meta) {
      return meta.meta.head;
    });
  }
}

class DataFile {
  final String path;
  final int size;
  final DownloadMeta meta;

  DataFile({required this.path, required this.size, required this.meta});
}

class DownloadMeta {
  final String id;
  final String deviceId;
  final String generation;
  final int head;
  final int tail;
  final String name;
  final bool last;

  DownloadMeta({
    required this.id,
    required this.deviceId,
    required this.generation,
    required this.head,
    required this.tail,
    required this.name,
    required this.last,
  });

  int get total => tail - head;

  Uri makeUrl(String addr) {
    return Uri.parse("http://$addr/fk/v1/download/data?first=$head&last=$tail");
  }

  List<DownloadMeta> chunks(int size) {
    List<DownloadMeta> chunks = [];
    DownloadMeta? remainder = this;
    do {
      final (chunk, r) = remainder!.splitChunk(size);
      chunks.add(chunk);
      remainder = r;
    } while (remainder != null);

    return chunks;
  }

  (DownloadMeta, DownloadMeta?) splitChunk(int size) {
    if (tail - head > size) {
      final first = DownloadMeta(
          id: "${id}_$head",
          deviceId: deviceId,
          generation: generation,
          head: head,
          tail: head + size,
          name: name,
          last: false);
      final remainder = DownloadMeta(
          id: id,
          deviceId: deviceId,
          generation: generation,
          head: head + size,
          tail: tail,
          name: name,
          last: false);
      return (first, remainder);
    } else {
      final first = DownloadMeta(
          id: "${id}_$head",
          deviceId: deviceId,
          generation: generation,
          head: head,
          tail: tail,
          name: name,
          last: true);
      return (first, null);
    }
  }

  JsonMap toJson() => {
        'sync_id': id,
        'device_id': deviceId,
        'generation_id': generation,
        'head': head,
        'tail': tail,
        'data_name': "$id.fkpb",
        'headers': {
          'Fk-DeviceId': deviceId,
          'Fk-Blocks': "$head,$tail",
          'Fk-Generation': generation,
          'Fk-DeviceName': name,
          'Fk-Type': 'data'
        }
      };

  static DownloadMeta fromJson(JsonMap data) {
    final id = data['sync_id'] as String;
    final deviceId = data['device_id'] as String;
    final generationId = data['generation_id'] as String;
    final head = data['head'] as int;
    final tail = data['tail'] as int;
    final headers = data['headers'] as JsonMap;
    final name = headers['Fk-DeviceName'] as String;
    return DownloadMeta(
        id: id,
        deviceId: deviceId,
        generation: generationId,
        head: head,
        tail: tail,
        name: name,
        last: false);
  }

  @override
  String toString() {
    return "Meta<$deviceId $generation $id head=#$head tail=#$tail>";
  }
}
