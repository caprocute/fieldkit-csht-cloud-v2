import 'package:fk/diagnostics.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:fk/sync/components/connectivity_service.dart';
import 'package:fk/sync/components/data_status_widget.dart';
import 'package:fk/sync/components/formatting.dart';
import 'package:fk/sync/components/upload_alert_banner.dart';
import 'package:provider/provider.dart';
import 'package:fk/app_state.dart';
import 'package:fk/models/known_stations_model.dart';
import 'package:fk/no_stations_widget.dart';
import 'package:fk/common_widgets.dart';
import 'package:fk/components/last_connected.dart';
import 'package:simple_circular_progress_bar/simple_circular_progress_bar.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Enum to define acknowledgment statuses for syncing
enum Ack { unnecessary, download, upload }

Widget padAll(Widget child) {
  return Padding(
    padding: const EdgeInsets.all(14),
    child: child,
  );
}

class DataSyncTab extends StatelessWidget {
  const DataSyncTab({super.key});

  @override
  Widget build(BuildContext context) {
    final KnownStationsModel knownStations =
        context.watch<KnownStationsModel>();
    final StationOperations stationOperations =
        context.watch<StationOperations>();
    final TasksModel tasks = context.watch<TasksModel>();

    return DataSyncPage(
      known: knownStations,
      stationOperations: stationOperations,
      tasks: tasks,
    );
  }
}

class DataSyncPage extends StatelessWidget {
  final KnownStationsModel known;
  final TasksModel tasks;
  final StationOperations stationOperations;

  const DataSyncPage({
    super.key,
    required this.known,
    required this.tasks,
    required this.stationOperations,
  });

  @override
  Widget build(BuildContext context) {
    // Check if the device is connected to the network
    final isConnected = context.watch<ConnectivityService>().isConnected;

    // Filter and prepare a list of stations with their sync status
    final loginTasks = tasks.getAll<LoginTask>();
    final stations = known.stations
        .where((station) => station.config != null)
        .map((station) => WakeWhileSyncingWidget(
              station: station,
              child: StationSyncWidget(
                tasks: tasks,
                stationOperations: stationOperations,
                isConnected: isConnected,
                station: station,
                downloadTask: tasks.getMaybeOne<DownloadTask>(station.deviceId),
                uploadTask: tasks.getMaybeOne<UploadTask>(station.deviceId),
              ),
            ))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.dataSyncTitle),
      ),
      body: ListView(
        children: [
          UploadAlertBanner(
            login: loginTasks.isEmpty,
            isConnected: isConnected,
            uploadTask: stations.isEmpty
                ? null
                : tasks.getMaybeOne<UploadTask>(known.stations.first.deviceId),
          ),
          // Display help widget if no stations are available
          if (stations.isEmpty) const NoStationsHelpWidget(showImage: true),
          // Display each station's sync status
          ...stations,
        ],
      ),
    );
  }
}

class SyncExpansionTile extends StatefulWidget {
  final Widget title;
  final List<Widget> children;

  const SyncExpansionTile({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  SyncExpansionTileState createState() => SyncExpansionTileState();
}

class SyncExpansionTileState extends State<SyncExpansionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween(begin: 0.0, end: 0.5).animate(_controller);
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffd8dce0), width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          onExpansionChanged: (expanded) => _toggleExpansion(),
          title: widget.title,
          tilePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          trailing: RotationTransition(
            turns: _animation,
            child: const Icon(Icons.expand_more,
                size: 32,
                color: Color(0xffd8dce0),
                semanticLabel: 'Expand and Collapse'),
          ),
          children: widget.children,
        ),
      ),
    );
  }
}

class AcknowledgeSyncWidget extends StatefulWidget {
  final bool downloading;
  final bool uploading;
  final bool failed;
  final int? readings;
  final int? total;
  final Widget child;

  const AcknowledgeSyncWidget({
    super.key,
    required this.downloading,
    required this.uploading,
    required this.failed,
    required this.readings,
    required this.total,
    required this.child,
  });

  @override
  State<StatefulWidget> createState() => _AcknowledgeSyncState();
}

class _AcknowledgeSyncState extends State<AcknowledgeSyncWidget> {
  Ack _ack = Ack.unnecessary;
  int? _readings;
  int? _total;

  @override
  void didUpdateWidget(covariant AcknowledgeSyncWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_total == null && widget.total != null) {
      _total = widget.total;
      Loggers.ui.i("ack: total: $_total");
    }

    if (widget.readings != null) {
      _readings = widget.readings;
    }

    if (oldWidget.downloading != widget.downloading && !widget.downloading) {
      _ack = Ack.download;
      Loggers.ui.i("ack: download");
    }

    if (oldWidget.uploading != widget.uploading && !widget.uploading) {
      _ack = Ack.upload;
      Loggers.ui.i("ack: upload");
    }
  }

  void _dismiss() {
    setState(() {
      _ack = Ack.unnecessary;
      _readings = null;
      _total = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ack == Ack.unnecessary) {
      return widget.child;
    } else {
      int? readings = _readings;
      if (readings == null) {
        // Paranoid check.
        Loggers.ui.w("Null readings in AcknowledgeSyncWidget");
        readings = 0;
      }
      int? total = _total;
      if (total == null) {
        // Paranoid check.
        Loggers.ui.w("Null total in AcknowledgeSyncWidget");
        total = 0;
      }
      if (_ack == Ack.download) {
        if (widget.failed) {
          Loggers.ui.w("ack: download-failed $readings / $total");

          return DownloadFailedWidget(
            readings: readings,
            total: total,
            onDismissed: _dismiss,
          );
        } else {
          return DownloadedWidget(
            total: total,
            onDismissed: _dismiss,
          );
        }
      }

      if (_ack == Ack.upload) {
        if (widget.failed) {
          return UploadFailedWidget(
            total: total,
            onDismissed: _dismiss,
          );
        } else {
          return UploadedWidget(
            total: total,
            onDismissed: _dismiss,
          );
        }
      }

      return const OopsBug();
    }
  }
}

class WakeWhileSyncingWidget extends StatefulWidget {
  final Widget child;
  final StationModel station;

  const WakeWhileSyncingWidget(
      {super.key, required this.child, required this.station});

  @override
  State<StatefulWidget> createState() => _WakeWhileSyncingState();
}

class _WakeWhileSyncingState extends State<WakeWhileSyncingWidget> {
  bool _wakelockEnabled = false;

  @override
  void didUpdateWidget(WakeWhileSyncingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handleWakelockState();
  }

  @override
  void dispose() {
    if (_wakelockEnabled) {
      Loggers.ui.i("wakelock: disable");
      WakelockPlus.disable();
    }
    super.dispose();
  }

  Future<void> _handleWakelockState() async {
    final isSyncing = widget.station.syncing != null &&
        widget.station.syncing?.failed != true;

    if (isSyncing && !_wakelockEnabled) {
      Loggers.ui.i("wakelock: enable");
      await WakelockPlus.enable();
      setState(() => _wakelockEnabled = true);
    } else if (!isSyncing && _wakelockEnabled) {
      Loggers.ui.i("wakelock: disable");
      await WakelockPlus.disable();
      setState(() => _wakelockEnabled = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class StationSyncWidget extends StatelessWidget {
  final StationModel station;
  final TasksModel tasks;
  final StationOperations stationOperations;
  final bool isConnected;
  final DownloadTask? downloadTask;
  final UploadTask? uploadTask;

  const StationSyncWidget({
    super.key,
    required this.tasks,
    required this.stationOperations,
    required this.isConnected,
    required this.station,
    required this.downloadTask,
    required this.uploadTask,
  });

  bool get isSyncing =>
      station.syncing != null && station.syncing?.failed != true;
  bool get isFailed => station.syncing?.failed == true;
  bool get isDownloading => station.syncing?.download != null;
  bool get isUploading => station.syncing?.upload != null;
  bool get requiresFirmwareUpdate =>
      station.connected &&
      station.ephemeral != null &&
      !(station.ephemeral?.capabilities.udp ?? false);

  int? get transferring {
    if (station.syncing?.download != null) {
      return station.syncing!.download!.total - (downloadTask?.first ?? 0);
    }
    if (station.syncing?.upload != null) {
      return station.syncing!.upload!.totalReadings;
    }

    return null;
  }

  int get downloadable {
    final task = downloadTask;
    if (task == null) {
      return 0;
    }
    return task.total - (task.first ?? 0);
  }

  int? get downloaded {
    int? received = station.syncing?.download?.received;
    if (received == null) {
      return null;
    }

    return received - (downloadTask?.first ?? 0);
  }

  int get uploadable => (uploadTask?.total ?? 0);

  bool get suspicious {
    final d = downloaded;
    final t = transferring;
    if (t == null || d == null) {
      return false;
    }
    return (t < 0) || (d > t);
  }

  @override
  Widget build(BuildContext context) {
    if (suspicious) {
      Loggers.ui.w("suspicious syncing=${station.syncing} task=$downloadTask");
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: SyncExpansionTile(
        title: GenericListItemHeader(
          title: station.config!.name,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                LastConnected(
                  lastConnected: station.config?.lastSeen,
                  connected: station.connected,
                  size: MediaQuery.of(context).size.width / 300 > 2
                      ? 2
                      : MediaQuery.of(context).size.width / 300,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(),
          ),
          AcknowledgeSyncWidget(
              downloading: isDownloading,
              uploading: isUploading,
              readings: downloaded,
              total: transferring,
              failed: isFailed,
              child: _buildActions(context)),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (requiresFirmwareUpdate) {
      return FirmwareUpdateWidget(
        readings: localizations.readingsDownloadable(downloadable),
        station: station,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          _buildActionRow(
            left: _downloadLeft(context, localizations),
            right: _downloadRight(),
          ),
          const SizedBox(height: 8),
          _buildActionRow(
            left: _uploadLeft(context, localizations),
            right: _uploadRight(),
          ),
        ],
      ),
    );
  }

  Widget _downloadLeft(BuildContext context, AppLocalizations localizations) {
    final total = localizations.readingsDownloadable(downloadable);
    if (isDownloading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(total),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
                child: Semantics(
                  label: AppLocalizations.of(context)!.downloadingIcon,
                  child: Image.asset("resources/images/icon_downloading.png"),
                ),
              ),
              Text(
                  localizations.downloadProgress(downloaded ?? 0, downloadable),
                  style: const TextStyle(fontSize: 12)),
            ],
          )
        ],
      );
    }
    return _twoMessages(total, localizations.readytoDownload);
  }

  Widget _downloadRight() {
    if (station.syncing?.download != null) {
      return _buildProgressIndicator(station.syncing!.download!.completed);
    }
    if (station.syncing != null && station.syncing?.failed != true) {
      return const DownloadButtonWidget(task: null);
    }
    return DownloadButtonWidget(task: downloadTask);
  }

  Widget _uploadLeft(BuildContext context, AppLocalizations localizations) {
    final total = localizations.readingsUploadable(uploadable);
    if (isUploading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(total),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
                child: Semantics(
                  label: AppLocalizations.of(context)!.uploadingIcon,
                  child: Image.asset("resources/images/icon_uploading.png"),
                ),
              ),
              Text(localizations.uploadProgress,
                  style: const TextStyle(fontSize: 12)),
            ],
          )
        ],
      );
    }
    return _twoMessages(total, localizations.readytoUpload);
  }

  Widget _uploadRight() {
    if (station.syncing?.upload != null) {
      return _buildProgressIndicator(station.syncing!.upload!.completed);
    }
    if (station.syncing != null && station.syncing?.failed != true) {
      return const UploadButtonWidget(task: null);
    }
    return UploadButtonWidget(task: uploadTask);
  }

  Widget _buildActionRow({
    required Widget left,
    required Widget right,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: left,
          ),
          right,
        ],
      ),
    );
  }

  Widget _twoMessages(String first, String second) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(first),
        Text(second, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildProgressIndicator(double completedPercentage) {
    return Row(
      children: [
        const ElapsedTimeDisplay(),
        const SizedBox(width: 5),
        SizedBox(
          width: 40,
          height: 40,
          child: SimpleCircularProgressBar(
            // Force Stateful progress to rebuild whenever percentage changes.
            key: ValueKey(completedPercentage),
            progressStrokeWidth: 4,
            backStrokeWidth: 4,
            backColor: const Color(0xfff4f5f7),
            animationDuration: 0,
            progressColors: const [Color(0xFF1b80c9)],
            valueNotifier: ValueNotifier<double>(completedPercentage * 100),
            onGetText: (double value) {
              return Text(
                '${value.toStringAsFixed(1)}%',
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              );
            },
          ),
        ),
      ],
    );
  }
}

class DownloadButtonWidget extends StatelessWidget {
  final DownloadTask? task;

  const DownloadButtonWidget({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return ActionButton(
      label: localizations.download,
      iconPath: 'resources/images/icon_light_download.svg',
      onPressed: task == null ? null : () => _startDownload(context),
    );
  }

  Future<void> _startDownload(BuildContext context) async {
    await context.read<KnownStationsModel>().startDownloading(
          deviceId: task!.deviceId,
          first: task!.first,
          last: task!.total,
        );
  }
}

class UploadButtonWidget extends StatelessWidget {
  final UploadTask? task;

  const UploadButtonWidget({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return ActionButton(
      label: localizations.upload,
      iconPath: 'resources/images/icon_light_upload.svg',
      onPressed:
          task == null || !task!.allowed ? null : () => _startUpload(context),
    );
  }

  Future<void> _startUpload(BuildContext context) async {
    await context.read<KnownStationsModel>().startUploading(
          deviceId: task!.deviceId,
          tokens: task!.tokens!,
          files: task!.files,
        );
  }
}

class ElapsedTimeDisplay extends StatefulWidget {
  const ElapsedTimeDisplay({super.key});

  @override
  State<ElapsedTimeDisplay> createState() => _ElapsedTimeDisplayState();
}

class _ElapsedTimeDisplayState extends State<ElapsedTimeDisplay> {
  late final Stopwatch _stopwatch;
  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _ticker = Stream.periodic(
        const Duration(seconds: 1), (_) => _stopwatch.elapsed.inSeconds);
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _ticker,
      builder: (context, snapshot) {
        final elapsed = Duration(seconds: snapshot.data ?? 0);
        final elapsedTimeString =
            '${elapsed.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(elapsed.inSeconds.remainder(60)).toString().padLeft(2, '0')}';
        return Text(elapsedTimeString, style: const TextStyle(fontSize: 10));
      },
    );
  }
}
