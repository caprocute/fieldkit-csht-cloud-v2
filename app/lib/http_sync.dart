import 'dart:convert';
import 'dart:io';

import 'package:fk/configuration.dart';
import 'package:collection/collection.dart';
import 'package:fk/diagnostics.dart';
import 'package:fk/dispatcher.dart';
import 'package:fk/gen/api.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Type definitions for JSON structures
typedef JsonMap = Map<String, Object?>;
typedef JsonList = List<Object?>;

class HttpSync {
  final AppEventDispatcher dispatcher;
  final String addr;
  final DownloadMeta meta;

  bool completed = false;
  bool failed = false;
  int received = 0;

  HttpSync({required this.dispatcher, required this.addr, required this.meta});

  Future<void> start() async {
    final now = DateTime.now();

    await setStationBusy(deviceId: meta.deviceId, busy: true);

    Loggers.state
        .i("${meta.deviceId} #${meta.head} -> #${meta.tail} (${meta.total})");

    dispatch(TransferStatus.downloading(DownloadProgress(
        started: BigInt.from(now.millisecondsSinceEpoch),
        completed: 0,
        total: BigInt.from(0),
        received: BigInt.from(0))));

    // Start by getting the total size of all the records we intend to get, this
    // is necessary for progress display, otherwise we'd skip this.
    final client = http.Client();
    final url = meta.makeUrl(addr);
    final response = await client
        .send(http.Request("HEAD", url))
        // Long enough to calculate the total length we'll be asking for.
        .timeout(const Duration(seconds: 30));
    final totalLength = response.contentLength;

    Loggers.state.i("${meta.deviceId} totalLength=$totalLength");

    // Directory is per device/station, only create once.
    final directory = await Paths.deviceData(meta.deviceId);
    await directory.create(recursive: true);

    try {
      final chunks = meta.chunks(10000);
      Loggers.state.i("${meta.deviceId} chunks=${chunks.length}");

      for (final chunk in chunks) {
        Loggers.state.i("${meta.deviceId} ${chunk.id} ${chunk.total}");

        final path = await Paths.dataFile(meta.deviceId, chunk.id);
        final writing = File(path);
        final sink = writing.openWrite();

        try {
          final url = chunk.makeUrl(addr);
          Loggers.state.i("${meta.deviceId} $url");
          final req = http.Request("GET", url);
          final response = await client
              .send(req)
              // Hopefully, long enough to get one chunk.
              .timeout(const Duration(minutes: 10));

          await response.stream.map((s) {
            received += s.length;

            dispatch(TransferStatus.downloading(DownloadProgress(
                started: BigInt.from(now.millisecondsSinceEpoch),
                completed: received / totalLength!,
                total: BigInt.from(totalLength),
                received: BigInt.from(received))));

            return s;
          }).pipe(sink);

          Loggers.state.i("${meta.deviceId} writing meta");

          final serializedMeta = jsonEncode(chunk);
          final metaPath = "$path.json";

          final metaFile = File(metaPath);
          await metaFile.writeAsString(serializedMeta);

          Loggers.state.i("${meta.deviceId} sleep");

          await Future.delayed(const Duration(seconds: 5));
        } catch (e) {
          Loggers.state.w("${meta.deviceId} sync failed $e");

          await sink.close();
          await writing.delete();

          dispatch(const TransferStatus.failed());
          failed = true;

          break;
        } finally {
          Loggers.state.i("${meta.deviceId} chunk done");
        }
      }

      dispatch(const TransferStatus.completed());

      Loggers.state.i("${meta.deviceId} chunks done");
    } catch (e) {
      Loggers.state.w("${meta.deviceId} sync failed $e");

      dispatch(const TransferStatus.failed());
      failed = true;
    } finally {
      Loggers.state.i("${meta.deviceId} check archives");

      // We check for archives no matter what, because some chunks may have
      // worked and we want the status to reflect that.
      await checkForArchives();

      await setStationBusy(deviceId: meta.deviceId, busy: false);

      completed = true;

      Loggers.state.i("${meta.deviceId} done");
    }
  }

  void dispatch(TransferStatus status) {
    dispatcher.dispatch(DomainMessage.downloadProgress(
        TransferProgress(deviceId: meta.deviceId, status: status)));
  }
}

String newSyncId() {
  final DateFormat formatter = DateFormat('yyyyMMdd_HHmmss');
  final now = DateTime.now();
  return formatter.format(now);
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

class Paths {
  static Future<Directory> deviceData(String deviceId) async {
    final cfg = await Configuration.load();
    final storage = cfg.storagePath;
    return Directory("$storage/fk-data/$deviceId");
  }

  static Future<String> dataFile(String deviceId, String id) async {
    final directory = await Paths.deviceData(deviceId);
    return "${directory.path}/$id.fkpb";
  }

  static Future<List<DataFile>> findDataFiles(String deviceId) async {
    final dir = await Paths.deviceData(deviceId);
    final entries = await dir.list(recursive: false).toList();
    final List<DataFile> files = List.empty(growable: true);
    for (final entry in entries) {
      if (entry.path.endsWith(".fkpb.json")) {
        final file = File(entry.path);
        final body = await file.readAsString();
        try {
          final file = DataFile(
            path: entry.path.replaceAll(".json", ""),
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
  final DownloadMeta meta;

  DataFile({required this.path, required this.meta});
}
