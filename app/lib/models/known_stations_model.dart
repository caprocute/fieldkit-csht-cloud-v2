import 'package:collection/collection.dart';
import 'package:fk/app_state.dart';
import 'package:fk/diagnostics.dart';
import 'package:fk/dispatcher.dart';
import 'package:fk/gen/api.dart';
import 'package:fk/preferences.dart';
import 'package:fk/state/tailing.dart';
import 'package:flutter/material.dart';
import 'package:fk/http_sync.dart';
import 'package:fk/data/records.dart' as records;
import 'package:fk/http_sync.dart' as http_sync;

class StationModel extends ChangeNotifier {
  final String deviceId;
  StationConfig? config;
  EphemeralConfig? ephemeral;
  SyncingProgress? syncing;
  FirmwareInfo? get firmware => config?.firmware;
  bool connected;
  SyncStatus? syncStatus;

  StationModel({
    required this.deviceId,
    this.config,
    this.connected = false,
  });
}

class KnownStationsModel extends ChangeNotifier {
  final AppEventDispatcher dispatcher;
  final Map<String, StationModel> _stations = {};
  final Map<String, HttpSync> _syncs = {};
  final TailedLogs _logs = TailedLogs();

  UnmodifiableListView<StationModel> get stations =>
      UnmodifiableListView(_stations.values);

  KnownStationsModel({required this.dispatcher}) {
    dispatcher.addListener<DomainMessage_NearbyStations>((nearby) {
      final byDeviceId = {};
      for (final station in nearby.field0) {
        findOrCreate(station.deviceId);
        byDeviceId[station.deviceId] = station;
      }
      for (final station in _stations.values) {
        station.connected = byDeviceId.containsKey(station.deviceId);
        // Connection status change detection - needed for notifications via AppState
      }
      notifyListeners();
    });

    dispatcher.addListener<DomainMessage_StationRefreshed>((refreshed) async {
      final station = findOrCreate(refreshed.field0.deviceId);
      station.config = refreshed.field0;
      station.ephemeral = refreshed.field1;
      station.connected = true;

      final prefs = AppPreferences();
      final tailStationLogs = await prefs.getTailStationLogs();
      if (tailStationLogs) {
        _logs.startOrStopStation(station);
      }

      final deviceId = station.deviceId;
      final name = station.config?.name;
      final udp = station.ephemeral?.capabilities.udp;
      final firmware = station.config?.firmware;
      final fw = "${firmware?.label}/${firmware?.time}";
      final readings = station.config?.data.records;
      final battery = station.config?.battery.voltage;
      final solar = station.config?.solar.voltage;

      Loggers.state.i(
          "$deviceId $name readings=$readings battery=$battery solar=$solar fw=$fw udp=$udp");

      notifyListeners();
    });

    dispatcher.addListener<DomainMessage_DownloadProgress>((transferProgress) {
      applyTransferProgress(transferProgress.field0);
    });

    dispatcher.addListener<DomainMessage_UploadProgress>((transferProgress) {
      applyTransferProgress(transferProgress.field0);
    });

    dispatcher.addListener<DomainMessage_RecordArchives>((archives) {
      final byDeviceId = archives.field0.groupListsBy((a) => a.deviceId);
      for (final entry in byDeviceId.entries) {
        final uploaded = (entry.value
                .where((e) => e.uploaded != null)
                .map((e) => e.tail)
                .maxOrNull ??
            0);
        final downloaded = entry.value.map((e) => e.tail).max.toInt();
        // Loggers.state.i("${entry.key} uploaded=$uploaded downloaded=$downloaded");
        findOrCreate(entry.key).syncStatus =
            SyncStatus(uploaded: uploaded, downloaded: downloaded);
      }
    });

    _load();
  }

  void applyTransferProgress(TransferProgress transferProgress) {
    final deviceId = transferProgress.deviceId;
    final station = findOrCreate(deviceId);
    final status = transferProgress.status;
    if (status is TransferStatus_Downloading) {
      station.syncing = SyncingProgress(
          download: DownloadOperation(status: status),
          upload: null,
          failed: false);

      // If we're downloading from a station we know the station is connected.
      // We can still be connected and uploading, but we don't know that's the case since
      // uploads can happen (and usually do) when disconnected.
      station.connected = true;
    }
    if (status is TransferStatus_Uploading) {
      station.syncing = SyncingProgress(
          download: null,
          upload: UploadOperation(status: status),
          failed: false);
    }
    if (status is TransferStatus_Completed) {
      station.syncing = null;
    }
    if (status is TransferStatus_Failed) {
      station.syncing =
          SyncingProgress(download: null, upload: null, failed: true);
    }

    notifyListeners();
  }

  void _load() async {
    final stations = await getMyStations();
    Loggers.state.i("stations: ${stations.length} stations");
    for (var station in stations) {
      findOrCreate(station.deviceId).config = station;
      Loggers.state.i("stations: ${station.deviceId} ${station.name}");
    }
    Loggers.state.i("stations: loaded");
    notifyListeners();
  }

  StationModel? find(String deviceId) {
    return _stations[deviceId];
  }

  StationModel findOrCreate(String deviceId) {
    _stations.putIfAbsent(deviceId, () => StationModel(deviceId: deviceId));
    return _stations[deviceId]!;
  }

  Future<void> forget(String deviceId) async {
    await forgetStation(deviceId: deviceId);
    _stations.remove(deviceId);
    notifyListeners();
  }

  Future<void> startDownloading(
      {required String deviceId,
      required int? first,
      required int last}) async {
    final station = find(deviceId);
    if (station == null) {
      Loggers.state.w("$deviceId station missing");
      return;
    }

    final syncing = station.syncing;
    if (syncing != null) {
      if (!syncing.failed) {
        Loggers.state.w("$deviceId already syncing (downloading)");
        return;
      }
    }

    final prefs = AppPreferences();
    final httpSync = await prefs.getHttpSync();
    if (!httpSync) {
      final progress = await startDownload(
          deviceId: deviceId,
          first: first == null ? null : BigInt.from(first),
          total: BigInt.from(last));
      applyTransferProgress(progress);
    } else {
      if (_syncs.containsKey(deviceId)) {
        Loggers.state.w("$deviceId already syncing");
      }
      final addr = station.ephemeral?.addr;
      if (addr != null) {
        final generation = station.config!.generationId;
        final name = station.config!.name;
        final meta = http_sync.DownloadMeta(
            id: records.newTimeId(),
            deviceId: deviceId,
            generation: generation,
            head: first ?? 0,
            tail: last,
            name: name,
            last: false);
        final sync = HttpSync(dispatcher: dispatcher, addr: addr, meta: meta);
        sync.start();
        _syncs[deviceId] = sync;
      }
    }
  }

  Future<void> startUploading(
      {required String deviceId,
      required Tokens tokens,
      required List<RecordArchive> files}) async {
    final station = find(deviceId);
    if (station == null) {
      Loggers.state.w("$deviceId station missing");
      return;
    }

    final syncing = station.syncing;
    if (syncing != null) {
      if (!syncing.failed) {
        Loggers.state.w("$deviceId already syncing (uploading)");
        return;
      }
    }

    final progress =
        await startUpload(deviceId: deviceId, tokens: tokens, files: files);
    applyTransferProgress(progress);
  }

  ModuleAndStation? findModule(ModuleIdentity moduleIdentity) {
    for (final station in stations) {
      final config = station.config;
      if (config != null) {
        for (final module in config.modules) {
          if (module.identity == moduleIdentity) {
            return ModuleAndStation(config, module);
          }
        }
      }
    }
    return null;
  }
}
