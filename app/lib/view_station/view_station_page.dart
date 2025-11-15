import 'package:fk/common_widgets.dart';
import 'package:fk/constants.dart';
import 'package:fk/deploy/deploy_page.dart';
import 'package:fk/models/known_stations_model.dart';
import 'package:fk/providers.dart';
import 'package:fk/view_station/module_widgets.dart';
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:fk/components/last_connected.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fk/view_station/no_modules.dart';

import '../gen/api.dart';
import '../app_state.dart';
import '../meta.dart';
import '../unknown_station_page.dart';
import 'configure_station.dart';

class ViewStationRoute extends StatelessWidget {
  final String deviceId;

  const ViewStationRoute({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Consumer<KnownStationsModel>(
      builder: (context, knownStations, child) {
        var station = knownStations.find(deviceId);
        if (station == null) {
          return const NoSuchStationPage();
        } else {
          return StationProviders(
              deviceId: deviceId, child: ViewStationPage(station: station));
        }
      },
    );
  }
}

class ViewStationPage extends StatefulWidget {
  final StationModel station;

  const ViewStationPage({super.key, required this.station});

  @override
  // ignore: library_private_types_in_public_api
  _ViewStationPageState createState() => _ViewStationPageState();
}

class _ViewStationPageState extends State<ViewStationPage> {
  @override
  Widget build(BuildContext context) {
    final ModuleConfigurations moduleConfigurations =
        context.watch<ModuleConfigurations>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.station.config!.name),
        bottom: widget.station.ephemeral?.deployment != null
            ? PreferredSize(
                preferredSize: Size.zero,
                child: Text(
                  "${AppLocalizations.of(context)!.deployedAt} ${DateFormat.yMd().format(DateTime.fromMillisecondsSinceEpoch(widget.station.ephemeral!.deployment!.startTime.toInt() * 1000))}",
                ),
              )
            : moduleConfigurations.areAllModulesCalibrated(
                        widget.station, context) ==
                    false
                ? PreferredSize(
                    preferredSize: Size.zero,
                    child: Text(
                      AppLocalizations.of(context)!.readyToCalibrate,
                    ),
                  )
                : PreferredSize(
                    preferredSize: Size.zero,
                    child: Text(
                      AppLocalizations.of(context)!.readyToDeploy,
                    ),
                  ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConfigureStationRoute(
                        deviceId: widget.station.deviceId),
                  ),
                );
              },
              child: SvgPicture.asset("resources/images/icon_configure.svg",
                  semanticsLabel: AppLocalizations.of(context)!.configureIcon)),
        ],
      ),
      body: ListView(children: [
        HighLevelsDetails(station: widget.station),
      ]),
    );
  }
}

class BatteryIndicator extends StatelessWidget {
  final bool enabled;
  final double level;
  final double size;

  const BatteryIndicator(
      {super.key,
      required this.enabled,
      required this.level,
      required this.size});

  String icon() {
    final String prefix = enabled ? "normal" : "grayed";
    if (level >= 95) {
      return "resources/images/battery/${prefix}_100.png";
    }
    if (level >= 80) {
      return "resources/images/battery/${prefix}_80.png";
    }
    if (level >= 60) {
      return "resources/images/battery/${prefix}_60.png";
    }
    if (level >= 40) {
      return "resources/images/battery/${prefix}_40.png";
    }
    if (level >= 20) {
      return "resources/images/battery/${prefix}_20.png";
    }
    return "resources/images/battery/${prefix}_0.png";
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Container(
        margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
        child: ListTile(
            leading: Semantics(
              label: AppLocalizations.of(context)!.batteryIcon,
              child: Image.asset(icon(), cacheWidth: 16),
            ),
            title: Text(localizations.batteryLife,
                style: TextStyle(fontSize: size)),
            subtitle: Text("$level%", style: TextStyle(fontSize: size))));
  }
}

class MemoryIndicator extends StatelessWidget {
  final bool enabled;
  final int bytesUsed;
  final double size;

  const MemoryIndicator(
      {super.key,
      required this.enabled,
      required this.bytesUsed,
      required this.size});

  String icon() {
    if (enabled) {
      return "resources/images/memory/icon.png";
    }
    return "resources/images/memory/icon_gray.png";
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return ListTile(
        leading: Semantics(
          label: AppLocalizations.of(context)!.memoryIcon,
          child: Image.asset(icon(), cacheWidth: 16),
        ),
        title:
            Text(localizations.memoryUsage, style: TextStyle(fontSize: size)),
        subtitle: Text(
            AppLocalizations.of(context)!
                .bytesUsed((bytesUsed / 1048576).toStringAsFixed(2)),
            style: TextStyle(fontSize: size)));
  }
}

class TimerCircle extends StatelessWidget {
  final bool enabled;
  final int? deployed;
  final double size;

  const TimerCircle(
      {super.key,
      required this.enabled,
      required this.deployed,
      required this.size});

  Color color() {
    if (enabled) {
      if (deployed == null) {
        return Colors.black;
      } else {
        return AppColors.logoBlue;
      }
    }
    return Colors.grey;
  }

  String label() {
    if (deployed == null) {
      return "00:00:00";
    } else {
      final deployed =
          DateTime.fromMillisecondsSinceEpoch(this.deployed! * 1000);
      final e = DateTime.now().toUtc().difference(deployed);
      final days = e.inDays;
      final hours = e.inHours - (days * 24);
      final minutes = e.inMinutes - (hours * 60);
      final paddedHours = hours.toString().padLeft(2, '0');
      final paddedMins = minutes.toString().padLeft(2, '0');
      return "$days:$paddedHours:$paddedMins";
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Container(
        margin: const EdgeInsets.all(10),
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(color: color(), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label(),
              style: TextStyle(fontSize: size * 5 / 3, color: Colors.white)),
          Text(localizations.daysHoursMinutes,
              style: TextStyle(fontSize: size, color: Colors.white)),
        ]));
  }
}

class HighLevelsDetails extends StatelessWidget {
  final StationModel station;

  StationConfig get config => station.config!;

  const HighLevelsDetails({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final ModuleConfigurations moduleConfigurations =
        context.watch<ModuleConfigurations>();
    final modulesCalibrated =
        moduleConfigurations.areAllModulesCalibrated(station, context);

    final battery = config.battery.percentage;
    final bytesUsed = config.meta.size + config.data.size;
    final size = ((MediaQuery.of(context).size.width / 28) > 20)
        ? 20
        : (MediaQuery.of(context).size.width / 28);

    final modules = config.modules.sorted(defaultModuleSorter).map((module) {
      return ModuleInfo(
        module: module,
        showSensors: true,
        alwaysShowCalibrate: false,
      );
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: SizedBox(
            height: station.ephemeral?.deployment == null ? 350 : 260,
            child: Stack(
              children: [
                Positioned.fill(
                  top: 32,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: TimerCircle(
                                      enabled: station.connected,
                                      deployed: station.ephemeral?.deployment
                                                  ?.startTime ==
                                              null
                                          ? station
                                              .ephemeral?.deployment?.startTime
                                              .toInt()
                                          : null,
                                      size: size.toDouble(),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      BatteryIndicator(
                                          enabled: station.connected,
                                          level: battery,
                                          size: size.toDouble()),
                                      MemoryIndicator(
                                          enabled: station.connected,
                                          bytesUsed: bytesUsed.toInt(),
                                          size: size.toDouble())
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Deploy button disabled
                          if (!station.connected &&
                              station.ephemeral?.deployment == null &&
                              modules.length > 1)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                              width: double.infinity,
                              height: 50,
                              color: Colors.grey.shade300,
                              child: TextButton(
                                onPressed: null,
                                child: Text(
                                  AppLocalizations.of(context)!.deployButton,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            )
                          // Deploy button enabled
                          else if (station.ephemeral?.deployment == null &&
                              station.connected &&
                              modulesCalibrated &&
                              modules.length > 1)
                            Container(
                              padding: const EdgeInsets.all(10),
                              width: 400,
                              height: 80,
                              child: ElevatedTextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DeployStationRoute(
                                        deviceId: station.deviceId,
                                      ),
                                    ),
                                  );
                                },
                                text:
                                    AppLocalizations.of(context)!.deployButton,
                              ),
                            )
                          else if (station.ephemeral?.deployment ==
                              null) // Deploy button disabled otherwise
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                              width: double.infinity,
                              height: 70,
                              color: Colors.grey.shade300,
                              child: TextButton(
                                onPressed: null,
                                child: Text(
                                  AppLocalizations.of(context)!.deployButton,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            )
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        child: LastConnected(
                            lastConnected: station.config?.lastSeen,
                            connected: station.connected,
                            size: 1)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (modules.length ==
            1) // Note: This is on purpose, checking for only diagnostics module
          NoModulesWidget(station: station)
        else
          Column(children: modules),
      ],
    );
  }
}
