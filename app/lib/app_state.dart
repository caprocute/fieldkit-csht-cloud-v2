import 'dart:convert';
import 'dart:math';
import 'package:fk/meta.dart';
import 'package:fk/sync/components/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';

import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:fk/gen/api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:exponential_back_off/exponential_back_off.dart';
import 'package:protobuf/protobuf.dart';
import 'package:uuid/uuid.dart';
import 'package:fk_data_protocol/fk-data.pb.dart' as proto;
import 'models/known_stations_model.dart';

import 'diagnostics.dart';
import 'dispatcher.dart';
import 'station_notifications.dart';

// Type definitions for JSON structures
typedef JsonMap = Map<String, Object?>;
typedef JsonList = List<Object?>;

const uuid = Uuid();

class SyncStatus {
  int uploaded;
  int downloaded;

  SyncStatus({required this.uploaded, required this.downloaded});
}

class UpdatePortal {
  final PortalAccounts portalAccounts;
  final Map<String, ExponentialBackOff> _active = {};
  final Map<String, AddOrUpdatePortalStation> _updates = {};

  UpdatePortal(
      {required this.portalAccounts, required AppEventDispatcher dispatcher}) {
    dispatcher.addListener<DomainMessage_StationRefreshed>((refreshed) async {
      final deviceId = refreshed.field0.deviceId;

      // Always update what we'll be sending to the server. So when we do succeed it's the fresh data.
      _updates[deviceId] = AddOrUpdatePortalStation(
          name: refreshed.field0.name,
          deviceId: deviceId,
          locationName: "",
          statusPb: refreshed.field2);

      await tick();
    });
  }

  Future<bool> updateAll(UnmodifiableListView<StationModel> stations) async {
    for (final station in stations) {
      final config = station.config;
      if (config != null && config.pb != null) {
        _updates[station.deviceId] = AddOrUpdatePortalStation(
            name: config.name,
            deviceId: station.deviceId,
            locationName: "",
            statusPb: hex.encode(config.pb!));
      } else {
        Loggers.state.w("${station.deviceId} no config $config");
      }
    }

    await tick();

    return true;
  }

  Future<bool> tick() async {
    for (final kv in _updates.entries) {
      final deviceId = kv.key;
      final update = kv.value;
      final name = update.name;

      if (_active.containsKey(deviceId) &&
          _active[deviceId]!.isProcessRunning()) {
        Loggers.state.i("$deviceId $name portal update active");
        continue;
      } else {
        Loggers.state.i(
            "$deviceId $name portal update (${update.statusPb.length} bytes)");
      }

      final account = portalAccounts.getAccountForDevice(deviceId);
      final tokens = account?.tokens;
      if (account != null && tokens != null) {
        final backOff = ExponentialBackOff(
          interval: const Duration(milliseconds: 2000),
          maxDelay: const Duration(seconds: 60 * 5),
          maxAttempts: 10,
          maxRandomizationFactor: 0.0,
        );

        _active[deviceId] = backOff;

        final update = await backOff.start(() async {
          final idIfOk = await addOrUpdateStationInPortal(
              tokens: tokens, station: _updates[deviceId]!);
          portalAccounts.markValid(account);
          if (idIfOk == null) {
            Loggers.state.w("$deviceId permissions-conflict");
          } else {
            Loggers.state.t("$deviceId refreshed portal-id=$idIfOk");
          }
        }, retryIf: (e) => e is PortalError_Connecting, onRetry: (e) {});

        if (update.isLeft()) {
          final error = update.getLeftValue();
          if (error is PortalError_Authentication) {
            Loggers.state.e("$deviceId portal: auth $e");
          } else {
            Loggers.state.e("$deviceId portal: $error");
          }
        }
      } else {
        Loggers.state.w("$deviceId need-auth");
      }
    }

    Loggers.state.t("portal: tick");

    return true;
  }
}

class AuthenticationStatus extends ChangeNotifier {
  AuthenticationStatus(
      PortalStateMachine portalState, PortalAccounts accounts) {
    portalState.addListener(() {
      if (portalState.state == PortalState.loaded) {
        accounts.validate();
      }
      if (portalState.state == PortalState.validated) {
        accounts.refreshFirmware();
      }
    });
  }
}

class ModuleAndStation {
  final StationConfig station;
  final ModuleConfig module;

  ModuleAndStation(this.station, this.module);
}

const String globalOperationKey = "Global";

class StationOperations extends ChangeNotifier {
  final StationNotifications _stationNotifications;
  final Map<String, List<Operation>> _active = {};

  StationOperations(
      {required AppEventDispatcher dispatcher,
      required StationNotifications stationNotifications})
      : _stationNotifications = stationNotifications {
    dispatcher.addListener<DomainMessage_UpgradeProgress>((upgradeProgress) {
      getOrCreate<UpgradeOperation>(
              () => UpgradeOperation(upgradeProgress.field0.firmwareId.toInt()),
              upgradeProgress.field0.deviceId)
          .update(upgradeProgress);
      notifyListeners();
    });
    dispatcher.addListener<DomainMessage_DownloadProgress>((transferProgress) {
      if (transferProgress is TransferStatus_Downloading) {
        _stationNotifications.startSync();
        getOrCreate<TransferOperation>(
                () => DownloadOperation(status: transferProgress.field0.status),
                transferProgress.field0.deviceId)
            .update(transferProgress);
        notifyListeners();
      }
      if (transferProgress is TransferStatus_Completed || transferProgress is TransferStatus_Failed) {
        _stationNotifications.endSync();
      }
    });
    dispatcher.addListener<DomainMessage_UploadProgress>((transferProgress) {
      if (transferProgress is TransferStatus_Uploading) {
        _stationNotifications.startSync();
        getOrCreate<TransferOperation>(
                () => UploadOperation(status: transferProgress.field0.status),
                transferProgress.field0.deviceId)
            .update(transferProgress);
        notifyListeners();
      }
      if (transferProgress is TransferStatus_Completed || transferProgress is TransferStatus_Failed) {
        _stationNotifications.endSync();
      }
    });
    dispatcher
        .addListener<DomainMessage_FirmwareDownloadStatus>((downloadProgress) {
      getOrCreate<FirmwareDownloadOperation>(
              FirmwareDownloadOperation.new, globalOperationKey)
          .update(downloadProgress);
      notifyListeners();
    });
  }

  T getOrCreate<T extends Operation>(T Function() factory, String deviceId) {
    if (!_active.containsKey(deviceId)) {
      _active[deviceId] = List.empty(growable: true);
    }
    for (final operation in _active[deviceId] ?? List.empty()) {
      if (operation is T) {
        return operation;
      }
    }
    Loggers.state.i("creating $T");
    final operation = factory();
    _active[deviceId]!.add(operation);
    return operation;
  }

  List<T> getAll<T extends Operation>(String deviceId) {
    final List<Operation> station = _active[deviceId] ?? List.empty();
    return station.whereType<T>().toList();
  }

  List<T> getBusy<T extends Operation>(String deviceId) {
    return getAll<T>(deviceId).where((op) => !op.done).toList();
  }

  bool isBusy(String deviceId) {
    return getBusy<Operation>(deviceId).isNotEmpty;
  }

  void dismiss(Operation operation) {
    operation.dismiss();
    notifyListeners();
  }
}

abstract class Operation extends ChangeNotifier {
  bool dismissed = false;

  void update(DomainMessage message);

  void dismiss() {
    dismissed = true;
  }

  void undismiss() {
    dismissed = false;
  }

  bool get done;

  bool get busy => !done;
}

abstract class TransferOperation extends Operation {
  TransferStatus status;

  TransferOperation({required this.status});

  @override
  void update(DomainMessage message) {
    if (message is DomainMessage_DownloadProgress) {
      status = message.field0.status;
      notifyListeners();
    }
    if (message is DomainMessage_UploadProgress) {
      status = message.field0.status;
      notifyListeners();
    }
  }

  @override
  bool get done =>
      status is TransferStatus_Completed || status is TransferStatus_Failed;

  double get completed {
    final status = this.status;
    if (status is TransferStatus_Uploading) {
      return status.field0.bytesUploaded / status.field0.totalBytes;
    }
    if (status is TransferStatus_Downloading) {
      return status.field0.received / status.field0.total;
    }
    if (status is TransferStatus_Completed) {
      return 100.0;
    }
    return 0.0;
  }
}

class DownloadOperation extends TransferOperation {
  DownloadOperation({required super.status});

  TransferStatus_Downloading? get _downloading =>
      status as TransferStatus_Downloading;

  int get first => _downloading?.field0.first?.toInt() ?? 0;
  int get received => _downloading?.field0.received.toInt() ?? 0;
  int get total => _downloading?.field0.total.toInt() ?? 0;
  int get started => _downloading?.field0.started.toInt() ?? 0;
}

class UploadOperation extends TransferOperation {
  UploadOperation({required super.status});

  TransferStatus_Uploading? get _uploading =>
      status as TransferStatus_Uploading;

  int get totalReadings => _uploading?.field0.totalReadings.toInt() ?? 0;
  int get totalBytes => _uploading?.field0.totalBytes.toInt() ?? 0;
  int get readingsUploaded => _uploading?.field0.readingsUploaded.toInt() ?? 0;
  int get bytesUploaded => _uploading?.field0.bytesUploaded.toInt() ?? 0;
}

class FirmwareComparison {
  final LocalFirmware local;
  final FirmwareInfo station;
  final String label;
  final DateTime localTime;
  final DateTime stationTime;
  final bool newer;

  FirmwareComparison(
      {required this.local,
      required this.station,
      required this.label,
      required this.localTime,
      required this.stationTime,
      required this.newer});

  factory FirmwareComparison.compare(
      LocalFirmware local, FirmwareInfo station) {
    final stationTime =
        DateTime.fromMillisecondsSinceEpoch(station.time.toInt() * 1000);
    final localTime = DateTime.fromMillisecondsSinceEpoch(local.time.toInt());
    final newer =
        local.label != station.label && localTime.isAfter(stationTime);
    return FirmwareComparison(
        local: local,
        station: station,
        label: local.label,
        localTime: localTime,
        stationTime: stationTime,
        newer: newer);
  }

  @override
  String toString() {
    return "FirmwareComparison<Local<${local.id}, ${local.label}, $localTime}>, Station<${station.label}, $stationTime>, $newer>";
  }
}

class UpgradeOperation extends Operation {
  int firmwareId;
  UpgradeStatus status = const UpgradeStatus.starting();
  UpgradeError? error;

  UpgradeOperation(this.firmwareId);

  @override
  void update(DomainMessage message) {
    if (message is DomainMessage_UpgradeProgress) {
      final upgradeStatus = message.field0.status;
      if (upgradeStatus is UpgradeStatus_Failed) {
        error = upgradeStatus.field0;
        Loggers.state.i("upgrade: $error");
      } else {
        error = null;
        Loggers.state.t("upgrade: $upgradeStatus");
      }
      firmwareId = message.field0.firmwareId.toInt();
      status = upgradeStatus;
      undismiss();
      notifyListeners();
    }
  }

  @override
  bool get done => dismissed;

  @override
  bool get busy => !(status is UpgradeStatus_Completed ||
      status is UpgradeStatus_Failed ||
      status is UpgradeStatus_ReconnectTimeout);
}

class FirmwareDownloadOperation extends Operation {
  FirmwareDownloadStatus status = const FirmwareDownloadStatus.checking();

  @override
  void update(DomainMessage message) {
    if (message is DomainMessage_FirmwareDownloadStatus) {
      status = message.field0;
      notifyListeners();
    }
  }

  @override
  bool get done =>
      status is FirmwareDownloadStatus_Completed ||
      status is FirmwareDownloadStatus_Failed;
}

class LocalFirmwareBranchInfo {
  final String branch;
  final String? version;
  final String? sha;

  LocalFirmwareBranchInfo(
      {required this.version, required this.branch, required this.sha});

  static LocalFirmwareBranchInfo? parse(String label) {
    if (label.length >= 8) {
      final version = label.split('-').first;
      final lastDash = label.lastIndexOf("-");
      if (lastDash > 0) {
        final sha = label.substring(lastDash + 1);
        final RegExp hex = RegExp("[0..9abcdef]+");
        if (hex.hasMatch(sha)) {
          final branch = label.substring(version.length + 1, lastDash);
          final maybeDot = branch.indexOf(".");
          if (maybeDot > 0) {
            return LocalFirmwareBranchInfo(
                version: version,
                branch: branch.substring(0, maybeDot),
                sha: sha);
          } else {
            return LocalFirmwareBranchInfo(
                version: version, branch: branch, sha: sha);
          }
        }
      }
    }
    return LocalFirmwareBranchInfo(version: null, branch: label, sha: null);
  }

  @override
  String toString() {
    return "BranchInfo($version, $branch, $sha)";
  }
}

class AvailableFirmwareModel extends ChangeNotifier {
  final List<LocalFirmware> _firmware = [];

  UnmodifiableListView<LocalFirmware> get firmware =>
      UnmodifiableListView(_firmware);

  AvailableFirmwareModel({required AppEventDispatcher dispatcher}) {
    dispatcher
        .addListener<DomainMessage_AvailableFirmware>((availableFirmware) {
      _firmware.clear();
      _firmware.addAll(availableFirmware.field0);
      notifyListeners();
    });
  }

  Future<void> upgrade(String deviceId, LocalFirmware firmware) async {
    await upgradeStation(deviceId: deviceId, firmware: firmware, swap: true);
  }
}

class WifiNetwork {
  String? ssid;
  String? password;
  bool preferred;

  WifiNetwork(
      {required this.ssid, required this.password, required this.preferred});
}

class Event {
  final proto.Event data;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(data.time * 1000);

  Event({required this.data});

  static Event from(proto.Event e) {
    if (e.system == proto.EventSystem.EVENT_SYSTEM_LORA) {
      return LoraEvent(data: e);
    }
    if (e.system == proto.EventSystem.EVENT_SYSTEM_RESTART) {
      return RestartEvent(data: e);
    }
    return UnknownEvent(data: e);
  }
}

class UnknownEvent extends Event {
  UnknownEvent({required super.data});
}

class RestartEvent extends Event {
  /*
  enum ResetReason {
      FK_RESET_REASON_POR    = 1,
      FK_RESET_REASON_BOD12  = 2,
      FK_RESET_REASON_BOD33  = 4,
      FK_RESET_REASON_NVM    = 8,
      FK_RESET_REASON_EXT    = 16,
      FK_RESET_REASON_WDT    = 32,
      FK_RESET_REASON_SYST   = 64,
      FK_RESET_REASON_BACKUP = 128
  };
  */

  String get reason {
    if (data.code == 1) return "POR";
    if (data.code == 2) return "BOD12";
    if (data.code == 4) return "BOD33";
    if (data.code == 8) return "NVM";
    if (data.code == 16) return "EXT";
    if (data.code == 32) return "WDT";
    if (data.code == 64) return "SYST";
    if (data.code == 128) return "BACKUP";
    return "Unknown";
  }

  RestartEvent({required super.data});
}

enum LoraCode {
  joinOk,
  joinFail,
  confirmedSend,
  unknown,
}

class LoraEvent extends Event {
  LoraCode get code {
    if (data.code == 1) return LoraCode.joinOk;
    if (data.code == 2) return LoraCode.joinFail;
    if (data.code == 3) return LoraCode.confirmedSend;
    return LoraCode.unknown;
  }

  LoraEvent({required super.data});
}

class StationConfiguration extends ChangeNotifier {
  final KnownStationsModel knownStations;
  final PortalAccounts portalAccounts;
  final String deviceId;

  StationModel get config => knownStations.find(deviceId)!;

  String get name => config.config!.name;

  List<NetworkConfig> get networks =>
      config.ephemeral?.networks ?? List.empty();

  bool get isAutomaticUploadEnabled =>
      config.ephemeral?.transmission?.enabled ?? false;

  LoraConfig? get loraConfig => config.ephemeral?.lora;

  StationConfiguration(
      {required this.knownStations,
      required this.portalAccounts,
      required this.deviceId}) {
    knownStations.addListener(() {
      notifyListeners();
    });
    // Watch for token changes, can affect if we can enable automatic uploading.
    portalAccounts.addListener(() {
      notifyListeners();
    });
  }

  List<Event> events() {
    final Uint8List? bytes = config.ephemeral?.events;
    if (bytes == null || bytes.isEmpty) {
      return List.empty();
    }
    try {
      final CodedBufferReader reader = CodedBufferReader(bytes);
      final List<int> delimited = reader.readBytes();
      try {
        final proto.DataRecord record = proto.DataRecord.fromBuffer(delimited);
        return record.events.map((e) => Event.from(e)).toList();
      } catch (e) {
        Loggers.state.w("malformed protobuf: $e");
        Loggers.state.w("$bytes (${bytes.length})");
        Loggers.state.i("$delimited (${delimited.length})");
        return List.empty();
      }
    } catch (e) {
      Loggers.state.w("malformed buffer: $e");
      Loggers.state.w("$bytes (${bytes.length})");
      return List.empty();
    }
  }

  Future<void> addNetwork(
      List<NetworkConfig> existing, WifiNetwork network) async {
    final int keeping = existing.isEmpty ? 1 : 0;
    final List<WifiNetworkConfig> networks =
        List<int>.generate(2, (i) => i).map((index) {
      if (keeping == index) {
        return WifiNetworkConfig(
            index: BigInt.from(index), keeping: true, preferred: false);
      } else {
        return WifiNetworkConfig(
            index: BigInt.from(index),
            keeping: false,
            preferred: false,
            ssid: network.ssid!,
            password: network.password!);
      }
    }).toList();

    await configureWifiNetworks(
        deviceId: deviceId, config: WifiNetworksConfig(networks: networks));
  }

  Future<void> removeNetwork(NetworkConfig network) async {
    final List<WifiNetworkConfig> networks =
        List<int>.generate(2, (i) => i).map((index) {
      if (network.index.toInt() == index) {
        return WifiNetworkConfig(
            index: BigInt.from(index),
            keeping: false,
            preferred: false,
            ssid: "",
            password: "");
      } else {
        return WifiNetworkConfig(
            index: BigInt.from(index), keeping: true, preferred: false);
      }
    }).toList();

    await configureWifiNetworks(
        deviceId: deviceId, config: WifiNetworksConfig(networks: networks));
  }

  bool canEnableWifiUploading() {
    final account = portalAccounts.getAccountForDevice(deviceId);
    return account != null && account.tokens != null;
  }

  Future<void> enableWifiUploading() async {
    final account = portalAccounts.getAccountForDevice(deviceId);
    if (account == null) {
      Loggers.state.i(
          "No account for device $deviceId (hasAny: ${portalAccounts.hasAnyValidTokens()})");
      return;
    }

    if (account.tokens == null) {
      Loggers.state.w("No tokens for account.");
      return;
    }

    await configureWifiTransmission(
        deviceId: deviceId,
        config: WifiTransmissionConfig(
            tokens: account.tokens,
            schedule: const Schedule_Every(12 * 60 * 60)));
  }

  Future<void> disableWifiUploading() async {
    await configureWifiTransmission(
        deviceId: deviceId,
        config: const WifiTransmissionConfig(tokens: null, schedule: null));
  }

  Future<void> configureLora(LoraTransmissionConfig config) async {
    await configureLoraTransmission(deviceId: deviceId, config: config);
  }

  Future<void> verifyLora() async {
    await verifyLoraTransmission(deviceId: deviceId);
  }

  Future<void> deploy(DeployConfig config) async {
    await configureDeploy(deviceId: deviceId, config: config);
  }

  Future<void> schedules(ScheduleConfig config) async {
    await configureSchedule(deviceId: deviceId, config: config);
  }
}

abstract class Task {
  final String key_ = uuid.v1();

  String get key => key_;

  bool isFor(String deviceId) {
    return false;
  }
}

abstract class DeviceTask extends Task {
  String get deviceId;
}

abstract class TaskFactory<M> extends ChangeNotifier {
  final List<M> _tasks = List.empty(growable: true);

  List<M> get tasks => List.unmodifiable(_tasks);

  List<T> getAll<T extends Task>() {
    return tasks.whereType<T>().toList();
  }
}

class DeployTaskFactory extends TaskFactory<DeployTask> {
  final KnownStationsModel knownStations;

  DeployTaskFactory({required this.knownStations}) {
    knownStations.addListener(() {
      _tasks.clear();
      _tasks.addAll(create());
      notifyListeners();
    });
  }

  List<DeployTask> create() {
    final List<DeployTask> tasks = List.empty(growable: true);
    for (final station in knownStations.stations) {
      if (station.ephemeral != null && station.ephemeral?.deployment == null) {
        tasks.add(DeployTask(station: station));
      }
    }
    return tasks;
  }
}

class DeployTask extends Task {
  final StationModel station;

  DeployTask({required this.station});

  @override
  bool isFor(String deviceId) {
    return station.deviceId == deviceId;
  }
}

class LastLogged {
  final Map<String, String> _loggedAt = {};

  bool shouldLog(String deviceId, String message) {
    final existing = _loggedAt[deviceId];
    if (existing != null) {
      if (existing == message) {
        return false;
      }
    }

    _loggedAt[deviceId] = message;

    return true;
  }

  void logChanges<T extends DeviceTask>(List<T> tasks) {
    final Map<String, String> removed = {..._loggedAt};
    for (final task in tasks) {
      final message = "${task.deviceId} CHANGE $task";
      if (shouldLog(task.deviceId, message)) {
        Loggers.state.i(message);
      }
      removed.remove(task.deviceId);
    }

    for (final entry in removed.entries) {
      Loggers.state.i("REMOVED ${entry.value}");
      _loggedAt.remove(entry.key);
    }
  }
}

class UpgradeTaskFactory extends TaskFactory<UpgradeTask> {
  final AvailableFirmwareModel availableFirmware;
  final KnownStationsModel knownStations;
  final LastLogged _logged = LastLogged();

  UpgradeTaskFactory(
      {required this.availableFirmware, required this.knownStations}) {
    listener() {
      _tasks.clear();
      _tasks.addAll(create());
      notifyListeners();
    }

    availableFirmware.addListener(listener);
    knownStations.addListener(listener);
  }

  List<UpgradeTask> create() {
    final List<UpgradeTask> tasks = List.empty(growable: true);
    for (final station in knownStations.stations) {
      final firmware = station.firmware;
      if (firmware != null) {
        for (final local in availableFirmware.firmware) {
          final comparison = FirmwareComparison.compare(local, firmware);
          if (comparison.newer) {
            tasks.add(UpgradeTask(station: station, comparison: comparison));
            break;
          }
        }
      }
    }

    _logged.logChanges(tasks);

    return tasks;
  }
}

class UpgradeTask extends DeviceTask {
  final StationModel station;
  final FirmwareComparison comparison;

  UpgradeTask({required this.station, required this.comparison});

  @override
  String toString() {
    return "UpgradeTask ${station.config?.name} $comparison";
  }

  @override
  bool isFor(String deviceId) {
    return station.deviceId == deviceId;
  }

  @override
  String get deviceId => station.deviceId;
}

class DownloadTaskFactory extends TaskFactory<DownloadTask> {
  List<NearbyStation> _nearby = List.empty();
  List<RecordArchive> _archives = List.empty();
  final Map<String, int> _records = {};
  final Map<String, String> _generations = {};
  final LastLogged _logged = LastLogged();

  DownloadTaskFactory(
      {required KnownStationsModel knownStations,
      required AppEventDispatcher dispatcher}) {
    dispatcher.addListener<DomainMessage_StationRefreshed>((refreshed) {
      _records[refreshed.field0.deviceId] =
          refreshed.field0.data.records.toInt();
      _generations[refreshed.field0.deviceId] = refreshed.field0.generationId;
      _tasks.clear();
      _tasks.addAll(create());
      notifyListeners();
    });

    dispatcher.addListener<DomainMessage_NearbyStations>((nearby) {
      _nearby = nearby.field0;
      _tasks.clear();
      _tasks.addAll(create());
      notifyListeners();
    });

    dispatcher.addListener<DomainMessage_RecordArchives>((archives) {
      _archives = archives.field0;
      _tasks.clear();
      _tasks.addAll(create());
      notifyListeners();
    });
  }

  DownloadTask? getTask(NearbyStation nearby) {
    final int? total = _records[nearby.deviceId];
    if (total != null) {
      if (_generations.containsKey(nearby.deviceId)) {
        final String generationId = _generations[nearby.deviceId]!;

        // Find already downloaded archives.
        final archivesById = _archives.groupListsBy((a) => a.deviceId);
        final Iterable<RecordArchive>? archives = archivesById[nearby.deviceId]
            ?.where((archive) => archive.generationId == generationId);

        if (archives != null && archives.isNotEmpty) {
          // Some records have already been downloaded.
          final int first = archives.map((archive) => archive.tail).max.toInt();
          // Loggers.state.i("download: first=$first total=$total ${total - first}");
          return DownloadTask(
              deviceId: nearby.deviceId, total: total, first: first);
        } else {
          // Nothing has been downloaded yet.
          Loggers.state.w("${nearby.deviceId} no archives");
          return DownloadTask(
              deviceId: nearby.deviceId, total: total, first: 0);
        }
      } else {
        Loggers.state.w("${nearby.deviceId} no generation");
        return null;
      }
    } else {
      Loggers.state.w("${nearby.deviceId} no total records");
      return null;
    }
  }

  List<DownloadTask> create() {
    final List<DownloadTask> tasks = List.empty(growable: true);
    for (final nearby in _nearby) {
      final task = getTask(nearby);
      if (task != null) {
        tasks.add(task);
      }
    }

    _logged.logChanges(tasks);

    return tasks;
  }
}

class DownloadTask extends DeviceTask {
  @override
  final String deviceId;
  final int total;
  final int? first;

  bool get hasReadings {
    return first != null && total - first! > 0;
  }

  DownloadTask({required this.deviceId, required this.total, this.first});

  @override
  String toString() {
    return "DownloadTask($deviceId, $first, $total)";
  }

  @override
  bool isFor(String deviceId) {
    return this.deviceId == deviceId;
  }
}

class UploadTaskFactory extends TaskFactory<UploadTask> {
  final PortalAccounts portalAccounts;
  final PortalStateMachine portalStateMachine;
  final List<RecordArchive> _archives = List.empty(growable: true);
  final LastLogged _logged = LastLogged();

  UploadTaskFactory(
      {required this.portalAccounts,
      required this.portalStateMachine,
      required AppEventDispatcher dispatcher}) {
    portalAccounts.addListener(() {
      _tasks.clear();
      _tasks.addAll(create());
      notifyListeners();
    });

    portalStateMachine.addListener(() {
      _tasks.clear();
      _tasks.addAll(create());
      notifyListeners();
    });

    dispatcher.addListener<DomainMessage_RecordArchives>((archives) {
      _archives.clear();
      _archives.addAll(archives.field0);
      _tasks.clear();
      _tasks.addAll(create());
      notifyListeners();
    });
  }

  UploadTask getTask(MapEntry<String, List<RecordArchive>> entry) {
    final account = portalAccounts.getAccountForDevice(entry.key);

    // Always create an UploadTask, regardless of authentication status.
    if (account == null || account.tokens == null) {
      // User needs to login.
      return UploadTask(
          deviceId: entry.key,
          files: entry.value,
          tokens: null,
          problem: UploadProblem.authentication);
    } else {
      if (account.validity == Validity.connectivity) {
        // User *may* need to login, or could just have connectivity issues.
        return UploadTask(
            deviceId: entry.key,
            files: entry.value,
            tokens: account.tokens,
            problem: UploadProblem.connectivity);
      } else {
        // User is good to try uploading.
        return UploadTask(
            deviceId: entry.key,
            files: entry.value,
            tokens: account.tokens,
            problem: UploadProblem.none);
      }
    }
  }

  List<UploadTask> create() {
    final List<UploadTask> tasks = List.empty(growable: true);
    final pending = _archives
        .where((a) => a.uploaded == null)
        .groupListsBy((a) => a.deviceId);
    for (final entry in pending.entries) {
      tasks.add(getTask(entry));
    }

    _logged.logChanges(tasks);

    return tasks;
  }
}

enum UploadProblem {
  none,
  authentication,
  connectivity,
}

class UploadTask extends DeviceTask {
  @override
  final String deviceId;
  final List<RecordArchive> files;
  final Tokens? tokens;
  final UploadProblem problem;

  UploadTask(
      {required this.deviceId,
      required this.files,
      required this.tokens,
      required this.problem});

  bool get allowed => problem == UploadProblem.none;

  int get total =>
      files.map((e) => e.tail - e.head).reduce((a, b) => a + b).toInt();

  @override
  String toString() {
    return "UploadTask($deviceId, $total records ${files.length} files $problem)";
  }

  @override
  bool isFor(String deviceId) {
    return this.deviceId == deviceId;
  }
}

class LoginTask extends Task {
  LoginTask();
}

class LoginTaskFactory extends TaskFactory<LoginTask> {
  final PortalAccounts portalAccounts;

  LoginTaskFactory({required this.portalAccounts}) {
    portalAccounts.addListener(() {
      _tasks.clear();
      if (!portalAccounts.hasAnyValidTokens()) {
        _tasks.add(LoginTask());
      }
      notifyListeners();
    });
  }
}

class TasksModel extends ChangeNotifier {
  final List<TaskFactory> factories = List.empty(growable: true);

  TasksModel(
      {required AvailableFirmwareModel availableFirmware,
      required KnownStationsModel knownStations,
      required PortalAccounts portalAccounts,
      required PortalStateMachine portalStateMachine,
      required AppEventDispatcher dispatcher,
      required ConnectivityService connectivityService}) {
    factories.add(LoginTaskFactory(portalAccounts: portalAccounts));
    factories.add(DeployTaskFactory(knownStations: knownStations));
    factories.add(UploadTaskFactory(
        portalAccounts: portalAccounts,
        portalStateMachine: portalStateMachine,
        dispatcher: dispatcher));
    factories.add(DownloadTaskFactory(
        knownStations: knownStations, dispatcher: dispatcher));
    factories.add(UpgradeTaskFactory(
        availableFirmware: availableFirmware, knownStations: knownStations));
    for (final TaskFactory f in factories) {
      f.addListener(notifyListeners);
    }
  }

  List<T> getAll<T extends Task>() {
    return factories.map((f) => f.getAll<T>()).flattened.toList();
  }

  List<T> getAllFor<T extends Task>(String deviceId) {
    return factories
        .map((f) => f.getAll<T>())
        .flattened
        .where((task) => task.isFor(deviceId))
        .toList();
  }

  T? getMaybeOne<T extends Task>(String deviceId) {
    final all = getAllFor<T>(deviceId);
    if (all.length > 1) {
      throw ArgumentError("Excepted one and only one Task");
    }
    if (all.length == 1) {
      return all[0];
    }
    return null;
  }
}

class AppState {
  final AppEventDispatcher dispatcher;
  final KnownStationsModel knownStations;
  final ModuleConfigurations moduleConfigurations;
  final AuthenticationStatus authenticationStatus;
  final PortalAccounts portalAccounts;
  final AvailableFirmwareModel firmware;
  final StationOperations stationOperations;
  final TasksModel tasks;
  final UpdatePortal updatePortal;
  final ConnectivityService connectivityService;
  final StationNotifications _stationNotifications = StationNotifications();

  AppState._(
      this.dispatcher,
      this.knownStations,
      this.moduleConfigurations,
      this.authenticationStatus,
      this.portalAccounts,
      this.firmware,
      this.stationOperations,
      this.tasks,
      this.updatePortal,
      this.connectivityService) {
    _initializeNotifications();
  }

  void _initializeNotifications() {
    _stationNotifications.initialize();

    knownStations.addListener(_onStationsChanged);
  }

  void _onStationsChanged() {
    for (final station in knownStations.stations) {
      final stationName = station.config?.name;
      _stationNotifications.updateStationConnection(
          station.deviceId, station.connected,
          stationName: stationName);
    }
  }

  static AppState build(
      AppEventDispatcher dispatcher, ConnectivityService connectivityService) {
    final stationOperations = StationOperations(
        dispatcher: dispatcher, stationNotifications: StationNotifications());
    final firmware = AvailableFirmwareModel(dispatcher: dispatcher);
    final knownStations = KnownStationsModel(dispatcher: dispatcher);
    final moduleConfigurations =
        ModuleConfigurations(knownStations: knownStations);
    final PortalStateMachine portalState = PortalStateMachine();
    final portalAccounts = PortalAccounts(portalState: portalState);
    final authenticationStatus =
        AuthenticationStatus(portalState, portalAccounts);
    final tasks = TasksModel(
      availableFirmware: firmware,
      knownStations: knownStations,
      portalAccounts: portalAccounts,
      portalStateMachine: portalState,
      dispatcher: dispatcher,
      connectivityService: ConnectivityService(),
    );
    final updatePortal =
        UpdatePortal(portalAccounts: portalAccounts, dispatcher: dispatcher);
    final connectivityService = ConnectivityService();

    return AppState._(
      dispatcher,
      knownStations,
      moduleConfigurations,
      authenticationStatus,
      portalAccounts,
      firmware,
      stationOperations,
      tasks,
      updatePortal,
      connectivityService,
    );
  }

  late final AppLifecycleListener _listener;
  DateTime? _periodicRan;

  AppState start() {
    _everyFiveMinutes();

    _listener = AppLifecycleListener(
      onStateChange: (AppLifecycleState state) {
        Loggers.state.i("lifecycle: $state");

        if (state == AppLifecycleState.resumed) {
          if (_periodicRan != null &&
              DateTime.now().difference(_periodicRan!).inSeconds < 30) {
            Loggers.state.i("periodic: $_periodicRan");
          } else {
            _periodic();
          }
        }
      },
    );

    // Mark app as fully loaded after a short delay to prevent initial connection notifications
    Future.delayed(const Duration(seconds: 2), () {
      _stationNotifications.setAppFullyLoaded();
    });

    return this;
  }

  AppState stop() {
    _listener.dispose();

    return this;
  }

  Future<void> _periodic() async {
    _periodicRan = DateTime.now();

    await portalAccounts.refreshFirmware();

    await updatePortal.updateAll(knownStations.stations);
  }

  Future<void> _everyFiveMinutes() async {
    while (true) {
      await Future.delayed(const Duration(minutes: 5));

      await _periodic();
    }
  }

  StationConfiguration configurationFor(String deviceId) {
    return StationConfiguration(
        knownStations: knownStations,
        portalAccounts: portalAccounts,
        deviceId: deviceId);
  }
}

class AppEnv {
  AppEventDispatcher dispatcher;
  ValueNotifier<AppState?> _appState;

  AppEnv._(this.dispatcher, {AppState? appState})
      : _appState = ValueNotifier(appState);

  AppEnv.appState(AppEventDispatcher dispatcher)
      : this._(
          dispatcher,
          appState: AppState.build(dispatcher, ConnectivityService()).start(),
        );

  ValueListenable<AppState?> get appState => _appState;
}

class SyncingProgress extends ChangeNotifier {
  final DownloadOperation? download;
  final UploadOperation? upload;
  final bool failed;

  double? get completed {
    if (download != null) {
      return download?.completed ?? 0;
    }
    if (upload != null) {
      return upload?.completed ?? 0;
    }
    return null;
  }

  SyncingProgress({this.download, this.upload, required this.failed});
}

extension CompletedProperty on UploadProgress {
  double get completed {
    return bytesUploaded / totalBytes;
  }
}

class ModuleIdentity {
  final String moduleId;

  ModuleIdentity({required this.moduleId});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ModuleIdentity && other.moduleId == moduleId;
  }

  @override
  int get hashCode => moduleId.hashCode;

  @override
  String toString() {
    return "ModuleIdentity($moduleId)";
  }
}

extension Identity on ModuleConfig {
  ModuleIdentity get identity => ModuleIdentity(moduleId: moduleId);
}

extension PortalTransmissionTokens on TransmissionToken {
  // Path.dart provides a global 'url' that's a Context and annoyingly binds
  // here without specifying local.
  Map<String, String> toJson() => {
        'token': token,
        // ignore: unnecessary_this
        'url': this.url,
      };

  static TransmissionToken fromJson(JsonMap data) {
    final token = data['token'] as String;
    final url = data['url'] as String;
    return TransmissionToken(token: token, url: url);
  }
}

extension PortalTokens on Tokens {
  JsonMap toJson() => {
        'token': token,
        'transmission': transmission.toJson(),
      };

  static Tokens fromJson(JsonMap data) {
    final token = data['token'] as String;
    final transmissionData = data['transmission'] as JsonMap;
    final transmission = PortalTransmissionTokens.fromJson(transmissionData);
    return Tokens(token: token, transmission: transmission);
  }
}

enum Validity {
  unchecked,
  valid,
  invalid,
  connectivity,
}

class PortalAccount extends ChangeNotifier {
  final String email;
  final String name;
  final Tokens? tokens;
  final bool active;
  final Validity validity;

  PortalAccount(
      {required this.email,
      required this.name,
      required this.tokens,
      required this.active,
      required this.validity});

  factory PortalAccount.fromJson(JsonMap data) {
    final email = data['email'] as String;
    final name = data['name'] as String;
    final active = data['active'] as bool;
    final tokensData = data["tokens"] as JsonMap?;
    final tokens =
        tokensData != null ? PortalTokens.fromJson(tokensData) : null;
    return PortalAccount(
        email: email,
        name: name,
        tokens: tokens,
        active: active,
        validity: Validity.unchecked);
  }

  factory PortalAccount.fromAuthenticated(Authenticated authenticated) {
    return PortalAccount(
        email: authenticated.email,
        name: authenticated.name,
        tokens: authenticated.tokens,
        active: true,
        validity: Validity.valid);
  }

  JsonMap toJson() => {
        'email': email,
        'name': name,
        'tokens': tokens?.toJson(),
        'active': active,
      };

  PortalAccount invalid() {
    return PortalAccount(
        email: email,
        name: name,
        tokens: null,
        active: active,
        validity: Validity.invalid);
  }

  PortalAccount valid() {
    return PortalAccount(
        email: email,
        name: name,
        tokens: tokens,
        active: active,
        validity: Validity.valid);
  }

  PortalAccount connectivity() {
    return PortalAccount(
        email: email,
        name: name,
        tokens: tokens,
        active: active,
        validity: Validity.connectivity);
  }

  PortalAccount withActive(bool active) {
    return PortalAccount(
        email: email,
        name: name,
        tokens: tokens,
        active: active,
        validity: validity);
  }
}

enum PortalState {
  started,
  loading,
  loaded,
  validating,
  validated,
}

class PortalStateMachine extends ChangeNotifier {
  PortalState _state = PortalState.started;

  PortalState get state => _state;

  void transition(PortalState to) {
    if (_state != to) {
      Loggers.state.i("portal: $to");
      _state = to;
      notifyListeners();
    }
  }
}

enum AccountError {
  invalidCredentials,
  serverError,
  unknownError,
}

class PortalAccounts extends ChangeNotifier {
  static const secureStorageKey = "fk.accounts";

  final PortalStateMachine portalState;
  final List<PortalAccount> _accounts = List.empty(growable: true);

  UnmodifiableListView<PortalAccount> get accounts =>
      UnmodifiableListView(_accounts);

  PortalAccount? get active => _accounts.where((a) => a.active).first;

  PortalAccounts({required this.portalState});

  static List<PortalAccount> fromJson(JsonMap data) {
    final accountsData = data['accounts'] as JsonList;
    return accountsData
        .map((accountData) => PortalAccount.fromJson(accountData as JsonMap))
        .toList();
  }

  JsonMap toJson() => {
        'accounts': _accounts.map((a) => a.toJson()).toList(),
      };

  Future<PortalAccounts> load() async {
    Loggers.state.i("portal: loading");

    try {
      const storage = FlutterSecureStorage();
      String? value = await storage.read(key: secureStorageKey);
      if (value != null) {
        try {
          final loaded = PortalAccounts.fromJson(jsonDecode(value) as JsonMap);
          _accounts.clear();
          _accounts.addAll(loaded);
        } catch (e) {
          Loggers.state.e("portal: $e");
        }
      }
    } catch (e) {
      Loggers.state.e("portal: fatal-exception: $e");
    } finally {
      portalState.transition(PortalState.loaded);
      notifyListeners();
    }

    return this;
  }

  Future<void> refreshFirmware() async {
    try {
      // Refresh unauthenticated to get the production firmware.
      Loggers.state.i("firmware: unauthenticated");
      await cacheFirmware(tokens: null, background: true);

      // Request per-user development/testing firmware.
      for (PortalAccount account in _accounts) {
        Loggers.state.i("firmware: authenticated");
        await cacheFirmware(tokens: account.tokens, background: true);
      }
    } catch (e) {
      Loggers.main.e("firmware: $e");
    }
  }

  Future<PortalAccounts> _save() async {
    const storage = FlutterSecureStorage();
    final serialized = jsonEncode(toJson());
    await storage.write(key: secureStorageKey, value: serialized);
    return this;
  }

  Future<PortalAccount> _authenticate(String email, String password) async {
    final authenticated =
        await authenticatePortal(email: email, password: password);
    return PortalAccount.fromAuthenticated(authenticated);
  }

  Future<AccountError?> registerAccount(
      String email, String password, String name, bool tncAccept) async {
    try {
      await registerPortalAccount(
          email: email, password: password, name: name, tncAccount: tncAccept);
      return null;
    } catch (error) {
      if (error is PortalError_Authentication) {
        return AccountError.invalidCredentials;
      } else {
        return AccountError.serverError;
      }
    }
  }

  Future<PortalAccount> _add(PortalAccount account) async {
    _removeByEmail(account.email);
    _accounts.add(account);
    await _save();
    Loggers.state.i("portal: add");
    notifyListeners();
    return account;
  }

  Future<AccountError?> addOrUpdate(String email, String password) async {
    try {
      final account = await _authenticate(email, password);
      await _add(account);
      return null;
    } catch (error) {
      if (error is PortalError_Authentication) {
        return AccountError.invalidCredentials;
      } else {
        return AccountError.serverError;
      }
    }
  }

  Future<void> activate(PortalAccount account) async {
    final updated =
        _accounts.map((iter) => iter.withActive(account == iter)).toList();
    _accounts.clear();
    _accounts.addAll(updated);
    await _save();
    Loggers.state.i("portal: activate");
    notifyListeners();
  }

  bool _removeByEmail(String email) {
    var filtered = _accounts.where((iter) => iter.email != email).toList();
    if (filtered.length == _accounts.length) {
      return false;
    }
    _accounts.clear();
    _accounts.addAll(filtered);
    return true;
  }

  Future<void> delete(PortalAccount account) async {
    _removeByEmail(account.email);
    await _save();
    Loggers.state.i("portal: delete");
    notifyListeners();
  }

  Future<PortalAccount> validateAccount(PortalAccount account) async {
    final tokens = account.tokens;
    if (tokens != null) {
      try {
        return PortalAccount.fromAuthenticated(
            await validateTokens(tokens: tokens));
      } on PortalError_Authentication catch (e) {
        Loggers.state.e("portal(validate): $e");
        return account.invalid();
      } on PortalError_Connecting catch (e) {
        Loggers.state.e("portal(connectivity): $e");
        return account;
      } catch (e) {
        Loggers.state.e("portal(unknown): $e");
        return account;
      }
    }
    return account;
  }

  Future<PortalAccounts> validate() async {
    portalState.transition(PortalState.validating);

    final validating = _accounts.map((e) => e).toList();
    _accounts.clear();
    for (final iter in validating) {
      final tokens = iter.tokens;
      if (tokens != null) {
        _accounts.add(await validateAccount(iter));
      } else {
        _accounts.add(iter);
      }
    }

    await _save();

    portalState.transition(PortalState.validated);

    notifyListeners();

    return this;
  }

  PortalAccount? getAccountForDevice(String deviceId) {
    if (_accounts.isEmpty) {
      return null;
    }
    return _accounts[0];
  }

  bool hasAnyValidTokens() {
    final maybeTokens = _accounts
        .where((e) => e.validity == Validity.valid)
        .map((e) => e.tokens)
        .where((e) => e != null)
        .firstOrNull;
    return maybeTokens != null;
  }

  void markValid(PortalAccount account) {
    _accounts.removeWhere((el) => el.email == account.email);
    _accounts.add(account.valid());
    Loggers.state.t("portal: mark-valid");
    notifyListeners();
  }
}

class ModuleConfiguration {
  final proto.ModuleConfiguration? configuration;

  ModuleConfiguration(this.configuration);

  List<proto.Calibration> get calibrations => configuration?.calibrations ?? [];

  bool get isCalibrated => calibrations.isNotEmpty;
}

class ModuleConfigurations extends ChangeNotifier {
  final KnownStationsModel knownStations;
  final Map<ModuleIdentity, String?> _forLoggingChanges = {};

  ModuleConfigurations({required this.knownStations}) {
    knownStations.addListener(() {
      notifyListeners();
    });
  }

  void _logChanges(ModuleIdentity identity, Uint8List? config) {
    final encoded = config == null ? null : base64.encode(config);
    if (!_forLoggingChanges.containsKey(identity) ||
        _forLoggingChanges[identity] != encoded) {
      Loggers.state.i("$identity cfg: `$encoded`");
      _forLoggingChanges[identity] = encoded;
    }
  }

  ModuleConfiguration find(ModuleIdentity moduleIdentity) {
    final stationAndModule = knownStations.findModule(moduleIdentity);
    final configuration = stationAndModule?.module.configuration;
    _logChanges(moduleIdentity, configuration);
    if (configuration == null || configuration.isEmpty) {
      return ModuleConfiguration(null);
    }

    final CodedBufferReader reader = CodedBufferReader(configuration);
    final List<int> delimited = reader.readBytes();
    return ModuleConfiguration(proto.ModuleConfiguration.fromBuffer(delimited));
  }

  Future<void> clear(ModuleIdentity moduleIdentity) async {
    final mas = knownStations.findModule(moduleIdentity);
    if (mas != null) {
      await retryOnFailure(() async {
        await clearCalibration(
            deviceId: mas.station.deviceId,
            module: BigInt.from(mas.module.position));
      });
    } else {
      Loggers.state.e("Unknown module identity $moduleIdentity");
    }
  }

  Future<void> calibrateModule(
      ModuleIdentity moduleIdentity, Uint8List data) async {
    final mas = knownStations.findModule(moduleIdentity);
    if (mas != null) {
      await retryOnFailure(() async {
        await calibrate(
            deviceId: mas.station.deviceId,
            module: BigInt.from(mas.module.position),
            data: data);
      });
    } else {
      Loggers.state.e("Unknown module identity $moduleIdentity");
    }
  }

  Future<void> retryOnFailure(Future<void> Function() work) async {
    for (var i = 0; i < 3; ++i) {
      try {
        return await work();
      } catch (e) {
        Loggers.state.e("$e");
        Loggers.state.w("retrying");
      }
    }
  }

  bool areAllModulesCalibrated(StationModel station, BuildContext context) {
    final config = station.config;
    if (config != null) {
      for (final module in config.modules) {
        final moduleIdentity = module.identity;
        final moduleConfig = find(moduleIdentity);
        final localizations = AppLocalizations.of(context)!;
        final localized = LocalizedModule.get(module, localizations);
        if (moduleConfig.calibrations.isEmpty && localized.canCalibrate) {
          return false;
        }
      }
      return true;
    }
    return false;
  }
}
