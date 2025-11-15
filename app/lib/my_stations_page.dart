import 'package:fk/models/known_stations_model.dart';
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'common_widgets.dart';
import 'gen/api.dart';
import 'app_state.dart';
import 'location_widgets.dart';
import 'map_widget.dart';
import 'no_stations_widget.dart';
import 'view_station/view_station_page.dart';

class StationsTab extends StatefulWidget {
  const StationsTab({super.key});

  @override
  // ignore: no_logic_in_create_state
  State<StatefulWidget> createState() => _StationsTabState();
}

class _StationsTabState extends State<StationsTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<KnownStationsModel>(
      builder: (context, knownStations, child) {
        return ProvideLocation(
          child: ListStationsPage(knownStations: knownStations),
        );
      },
    );
  }
}

class ListStationsPage extends StatelessWidget {
  final KnownStationsModel knownStations;

  const ListStationsPage({super.key, required this.knownStations});

  @override
  Widget build(BuildContext context) {
    final List<Widget> map = [const SizedBox(height: 200, child: MapWidget())];

    final cards = knownStations.stations.map((station) {
      return station.config == null
          ? DiscoveringStationCard(station: station)
          : StationCard(station: station);
    }).toList();

    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.myStationsTitle),
      ),
      body: ListView(
        children: [
          ...map,
          const SizedBox(height: 50.0),
          ...cards,
          if (cards.isEmpty) const NoStationsHelpWidget(showImage: false),
        ],
      ),
    );
  }
}

class TinyOperation extends StatelessWidget {
  final Operation operation;

  const TinyOperation({super.key, required this.operation});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final String operationText;

    if (operation is UploadOperation) {
      operationText = localizations.busyUploading;
    } else if (operation is DownloadOperation) {
      operationText = localizations.busyDownloading;
    } else if (operation is UpgradeOperation) {
      operationText = localizations.busyUpgrading;
    } else {
      operationText = localizations.busyWorking;
    }

    return WH.align(WH.padPage(Text(operationText)));
  }
}

class StationCard extends StatelessWidget {
  final StationModel station;

  StationConfig get config => station.config!;

  const StationCard({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final operations = context
        .watch<StationOperations>()
        .getBusy<Operation>(config.deviceId)
        .where((op) => op.done);
    final localizations = AppLocalizations.of(context)!;
    final ModuleConfigurations moduleConfigurations =
        context.watch<ModuleConfigurations>();

    final icon = ConnectedStatusIcon(connected: station.connected);

    final tinyOperations =
        operations.map((op) => TinyOperation(operation: op)).toList();
    final subtitle =
        _buildSubtitle(context, moduleConfigurations, localizations);

    return Container(
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color.fromRGBO(212, 212, 212, 1)),
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
        child: Column(
          children: [
            ListTile(
              title: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(config.name),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: subtitle,
              ),
              trailing: icon,
              dense: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ViewStationRoute(deviceId: station.deviceId),
                  ),
                );
              },
            ),
            if (tinyOperations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(children: tinyOperations),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle(
      BuildContext context,
      ModuleConfigurations moduleConfigurations,
      AppLocalizations localizations) {
    if (station.ephemeral?.deployment != null) {
      final deploymentDate = DateTime.fromMillisecondsSinceEpoch(
          station.ephemeral!.deployment!.startTime.toInt() * 1000);
      return Text(
          "${localizations.deployedAt} ${DateFormat.yMd().format(deploymentDate)}");
    }

    if (!moduleConfigurations.areAllModulesCalibrated(station, context)) {
      return Text(localizations.readyToCalibrate);
    }

    return Text(localizations.readyToDeploy);
  }
}

class DiscoveringStationCard extends StatelessWidget {
  final StationModel station;

  const DiscoveringStationCard({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.contacting),
    );
  }
}
