import 'dart:convert';
import 'dart:io';

import 'package:fk/data/paths.dart';
import 'package:fk/diagnostics.dart';
import 'package:fk/models/known_stations_model.dart';

class TailedLogs {
  final Map<String, Tailer> _tailers = {};

  void startOrStopStation(StationModel station) {
    final addr = station.ephemeral?.addr;
    Loggers.state.i(
        "tail: startOrStopStation ${station.deviceId} ${station.connected} $addr");
    final tailer = _tailers[station.deviceId];
    if (station.connected && addr != null) {
      if (tailer == null) {
        // Start tailing station...
        final tailer = Tailer(
          deviceId: station.deviceId,
          addr: station.ephemeral!.addr,
        );
        _tailers[station.deviceId] = tailer;
        tailer.start();
      } else {
        tailer.start();
      }
    } else {
      tailer?.stop();
    }
  }
}

class Tailer {
  final String deviceId;
  final String addr;
  final CompleteLogLogger logger = CompleteLogLogger();
  Socket? _socket;

  Tailer({required this.deviceId, required this.addr});

  Future<void> start() async {
    if (_socket != null) {
      return;
    }
    final ip = addr.split(":").first;
    Loggers.stations.i("$deviceId tailing $ip");
    try {
      _socket = await Socket.connect(ip, 23);

      final now = DateTime.now();
      await append("$now Connected\n\n");

      _socket!.listen((List<int> event) async {
        final logs = utf8.decode(event);
        logger.log(logs);
        await append(logs);
      }, onDone: () async {
        Loggers.stations.i("$deviceId done");
        _socket = null;
        await start();
      }, onError: (error) async {
        Loggers.stations.w("$deviceId $error");
        _socket = null;
        await start();
      });
    } catch (error) {
      Loggers.stations.w("$deviceId $error");
      await Future.delayed(const Duration(minutes: 30));
      await start();
    }
  }

  void stop() async {
    if (_socket != null) {
      await _socket!.close();
      _socket = null;
    }
  }

  Future<void> append(String text) async {
    final file = await Paths.deviceLogs(deviceId);
    await file.writeAsString(text.replaceAll(String.fromCharCode(0x0), ""),
        mode: FileMode.append);
  }
}

class CompleteLogLogger {
  String buffered = "";

  void log(String text) {
    buffered += text;

    final lastNl = buffered.lastIndexOf("\n");
    if (lastNl >= 0) {
      final lines = buffered.substring(0, lastNl).split("\n");
      final last = buffered.substring(lastNl);
      buffered = last;

      for (final line in lines) {
        if (line.isNotEmpty) {
          Loggers.stations.i(line);
        }
      }
    }
  }
}
