import 'dart:collection';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:fk/data/records.dart';
import 'package:fk/diagnostics.dart';
import 'package:fk_data_protocol/fk-data.pb.dart' as proto;
import 'package:intl/intl.dart';

import 'paths.dart';

class ExportEvent {
  final bool success;
  final bool done;
  final bool empty;
  final int? readings;
  final double progress;
  final String? file;

  ExportEvent(
      {required this.success,
      required this.done,
      required this.progress,
      required this.file,
      required this.empty,
      required this.readings});
}

class Exporter extends Visitor {
  final DateFormat formatter = DateFormat('MM/dd/yyyy HH:MM:ss');
  final String deviceId;
  final HashMap<String, proto.ModuleInfo> _modules = HashMap();
  final List<String> _moduleOrder = List.empty(growable: true);
  proto.DataRecord? _meta;
  IOSink? _writing;

  Exporter({required this.deviceId});

  Stream<ExportEvent> exportAll() async* {
    try {
      final files = await Paths.findDataFiles(deviceId);
      if (files.isEmpty) {
        Loggers.state.i("Export: empty $deviceId $files");
        yield ExportEvent(
          empty: true,
          done: true,
          success: false,
          progress: 1.0,
          file: null,
          readings: null,
        );
        return;
      }

      final dir = await Paths.deviceData(deviceId);
      final id = newTimeId();
      final path = "${dir.path}/$id.csv";
      final temp = File("$path-temp");

      _writing = temp.openWrite();

      Loggers.state.i("Export: writing CSV");

      final walker = RecordWalker(deviceId: deviceId);

      await for (final progress in walker.walkAll(this)) {
        yield ExportEvent(
          success: true,
          done: false,
          progress: progress,
          file: null,
          empty: false,
          readings: 0,
        );
        await _writing!.flush();
      }

      Loggers.state.i("Export: flushing");
      await _writing!.flush();

      Loggers.state.i("Export: closing");
      await _writing!.close();

      Loggers.state.i("Export: prepending header");
      final csv = File(path);
      final writing = csv.openWrite();

      // Write header, now that we know all about the modules and their column offsets.
      writing.write("unix_time,time,data_record,meta_record,uptime");
      writing.write(",gps,latitude,longitude,altitude,gps_time,note");
      for (final id in _moduleOrder) {
        final module = _modules[id]!;
        writing.write(",module_index,module_position,module_name");
        for (final sensor in module.sensors) {
          writing.write(",${sensor.name}");
          writing.write(",${sensor.name}_raw_v");
        }
      }
      writing.write("\n");

      // Now copy the columnar data to the file, after the header.
      await for (final bytes in temp.openRead()) {
        writing.add(bytes);
      }

      await writing.close();

      Loggers.state.i("Export: deleting temporary $temp");

      await temp.delete();

      Loggers.state.i("Export: wrote $path");

      final zipPath = "$path.zip";
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      await encoder.addFile(csv);
      await encoder.close();

      Loggers.state.i("Export: wrote $zipPath");

      Loggers.state.i("Export: deleting uncompressed $path");

      await csv.delete();

      yield ExportEvent(
        success: true,
        done: true,
        progress: 1.0,
        file: zipPath,
        empty: false,
        readings: 0,
      );
    } catch (e) {
      Loggers.state.e("Error: $e");
      yield ExportEvent(
        success: false,
        done: true,
        progress: 1.0,
        file: null,
        empty: false,
        readings: 0,
      );
      rethrow;
    }
  }

  @override
  Future<void> visitRecord(proto.DataRecord record, double progress) async {
    if (record.metadata.isInitialized() &&
        record.metadata.hasDeviceId() &&
        record.modules.isNotEmpty) {
      for (final module in record.modules) {
        final id = hex.encode(module.id);
        if (!_modules.containsKey(id)) {
          Loggers.state.i("Module ${_modules.length} ${module.name}");
          _modules[id] = module;
          _moduleOrder.add(id);
        }
      }

      _meta = record;
    }

    final readings = record.readings;
    if (readings.isInitialized() && readings.hasReading()) {
      final millis = readings.time.toInt() * 1000;
      List<String> row = [
        formatter.format(DateTime.fromMillisecondsSinceEpoch(millis)),
        readings.time.toString(),
        readings.reading.toString(),
        readings.meta.toString(),
        readings.uptime.toString(),
        readings.location.fix.toString(),
        readings.location.latitude.toString(),
        readings.location.longitude.toString(),
        readings.location.altitude.toString(),
        readings.location.time.toString(),
        "" // note
      ];

      final HashMap<String, List<String>> modules = HashMap();

      for (final (index, sensorGroup) in readings.sensorGroups.indexed) {
        final module = _meta!.modules[index];
        final id = hex.encode(module.id);

        List<String> columns = [
          index.toString(),
          sensorGroup.module.toString(),
          module.name,
        ];

        for (final sensor in sensorGroup.readings) {
          columns.add(sensor.calibratedValue.toString());
          columns.add(sensor.uncalibratedValue.toString());
        }

        modules[id] = columns;
      }

      for (final id in _moduleOrder) {
        if (modules.containsKey(id)) {
          final columns = modules[id]!;
          row.addAll(columns);
        } else {
          row.add("");
          row.add("");
          row.add("");
          row.addAll(_modules[id]!.sensors.map((_) => ""));
        }
      }

      _writing!.write(row.join(","));
      _writing!.write("\n");
    }
  }

  Future<PossibleExport> calculate() async {
    final files = await Paths.findDataFiles(deviceId);
    final readings = files.map((f) => f.meta.tail - f.meta.head).sum;
    return PossibleExport(readings: readings);
  }
}

class PossibleExport {
  final int readings;

  PossibleExport({required this.readings});
}
