import 'package:fk/diagnostics.dart';
import 'package:fk/models/known_stations_model.dart';
import 'package:fk/reader/screens.dart';
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'pdf_viewer.dart';
import 'package:url_launcher/link.dart';
import 'package:flutter/services.dart';
import 'package:fk/calibration/calibration_page.dart';
import 'package:fk/calibration/calibration_model.dart';
import 'package:fk/settings/report_issue_page.dart';
import 'package:provider/provider.dart';
import 'package:flows/flows.dart' show ContentFlows;
import 'package:fk/gen/api.dart';
import 'package:open_settings_plus/open_settings_plus.dart';

class ModuleSetup {
  final String key;
  final String assetPath;
  final String titleKey;
  final List<String> setupScreens;

  const ModuleSetup({
    required this.key,
    required this.assetPath,
    required this.titleKey,
    required this.setupScreens,
  });
}

// This is the widget that should be used in the app
class HelpTab extends StatefulWidget {
  static const _moduleSetups = [
    ModuleSetup(
      key: "modules.water.ph",
      assetPath: "resources/images/icon_module_water_ph_gray.png",
      titleKey: "phModuleSetup",
      setupScreens: [
        "onboarding.water.ph.01",
        "onboarding.water.ph.02",
        "onboarding.water.ph.03"
      ],
    ),
    ModuleSetup(
      key: "modules.water.temp",
      assetPath: "resources/images/icon_module_water_temp_gray.png",
      titleKey: "waterTempModuleSetup",
      setupScreens: ["onboarding.water.temp.01", "onboarding.water.temp.02"],
    ),
    ModuleSetup(
      key: "modules.water.ec",
      assetPath: "resources/images/icon_module_water_ec_gray.png",
      titleKey: "conductivityModuleSetup",
      setupScreens: ["onboarding.water.ec.01", "onboarding.water.ec.02"],
    ),
    ModuleSetup(
      key: "modules.water.dox",
      assetPath: "resources/images/icon_module_water_do_gray.png",
      titleKey: "doModuleSetup",
      setupScreens: ["onboarding.water.dox.01", "onboarding.water.dox.02"],
    ),
  ];

  static const _textStyle = TextStyle(
    fontSize: 14.0,
    fontFamily: 'Avenir',
    fontWeight: FontWeight.normal,
    color: Colors.black,
    decoration: TextDecoration.none,
  );

  const HelpTab({super.key});

  @override
  State<HelpTab> createState() => _HelpTabState();
}

class _HelpTabState extends State<HelpTab> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        appBar: AppBar(title: Text(localizations.helpTitle)),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            ExpansionTile(
              title:
                  Text(AppLocalizations.of(context)!.stationSetupInstructions),
              children: [
                ListTile(
                  leading: const Icon(Icons.build),
                  title: Text(AppLocalizations.of(context)!.assembleStation),
                  onTap: () => _navigateToFlow(context, const [
                    "onboarding.02",
                    "onboarding.03",
                    "onboarding.04",
                    "onboarding.05",
                    "onboarding.06",
                    "onboarding.07",
                    "onboarding.08",
                    "onboarding.09",
                    "onboarding.10",
                    "onboarding.11",
                    "onboarding.12",
                    "onboarding.13",
                    "onboarding.14"
                  ], onForward: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PdfViewerPage(
                            initialPage: null, searchQuery: null),
                      ),
                    );
                  }),
                ),
                ListTile(
                  leading: const Icon(Icons.wifi),
                  title: Text(AppLocalizations.of(context)!.connectStation),
                  onTap: () => _navigateToFlow(
                    context,
                    const ["wifi.01", "wifi.02"],
                    onForward: () {
                      Navigator.pop(context);
                      _openWifiSettings(context);
                    },
                  ),
                ),
                _buildModuleSetupTiles(context),
                ListTile(
                  leading: Semantics(
                    label: AppLocalizations.of(context)!.distanceModuleIcon,
                    child: Image.asset(
                        "resources/images/icon_module_distance_gray.png",
                        width: 28,
                        height: 28),
                  ),
                  title:
                      Text(AppLocalizations.of(context)!.distanceModuleSetup),
                  onTap: () => _navigateToFlow(context, const [
                    "onboarding.distance.01",
                    "onboarding.distance.02",
                    "onboarding.distance.03"
                  ]),
                ),
                ListTile(
                  leading: Semantics(
                    label: AppLocalizations.of(context)!.weatherModuleIcon,
                    child: Image.asset(
                        "resources/images/icon_module_weather_gray.png",
                        width: 28,
                        height: 28),
                  ),
                  title: Text(AppLocalizations.of(context)!.weatherModuleSetup),
                  onTap: () => _navigateToFlow(context, const [
                    "onboarding.weather.01",
                    "onboarding.weather.02",
                    "onboarding.weather.03",
                    "onboarding.weather.04",
                    "onboarding.weather.05",
                    "onboarding.weather.06"
                  ]),
                ),
              ],
            ),
            const Divider(),
            Link(
              uri: Uri.parse(
                  'https://productguide.fieldkit.org/product-guide/set-up-station/#ready-to-deploy'),
              target: LinkTarget.blank,
              builder: (BuildContext ctx, FollowLink? openLink) {
                return ListTile(
                  onTap: openLink,
                  title: Text(localizations.helpCheckList),
                );
              },
            ),
            const Divider(),
            ListTile(
                title: Text(localizations.offlineProductGuide),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (BuildContext context) => const PdfViewerPage(
                          initialPage: null, searchQuery: null),
                    ),
                  );
                }),
            const Divider(),
            ListTile(
              title: Text(localizations.helpUploadLogs),
              onTap: () async {
                final localizations = AppLocalizations.of(context)!;
                final messenger = ScaffoldMessenger.of(context);
                final overlay = context.loaderOverlay;
                try {
                  overlay.show();
                  await ShareDiagnostics().upload();
                  messenger.showSnackBar(SnackBar(
                    content: Text(localizations.logsUploaded),
                  ));
                } finally {
                  overlay.hide();
                }
              },
            ),
            const Divider(),
            ListTile(
              title: Text(localizations.helpCreateBackup),
              onTap: () async {
                final localizations = AppLocalizations.of(context)!;
                final messenger = ScaffoldMessenger.of(context);
                final overlay = context.loaderOverlay;
                try {
                  overlay.show();
                  final file = await Backup().create();
                  if (file != null) {
                    final res = await SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(file)],
                        text: localizations.backupShareMessage,
                        subject: localizations.backupShareSubject,
                      ),
                    );

                    Loggers.ui.i("backup: $res");

                    messenger.showSnackBar(SnackBar(
                      content: Text(localizations.helpBackupCreated),
                    ));
                  } else {
                    messenger.showSnackBar(SnackBar(
                      content: Text(localizations.helpBackupFailed),
                    ));
                  }
                } finally {
                  overlay.hide();
                }
              },
            ),
            const Divider(),
            ListTile(
              title: Text(localizations.reportIssue),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) => const ReportIssuePage(),
                ),
              ),
            ),
            const Divider(),
            ListTile(
              title: Text(localizations.appVersion),
            ),
            FutureBuilder<String>(
              future: _getAppVersion(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text(
                    localizations.errorLoadingVersion,
                    style: HelpTab._textStyle,
                  );
                } else {
                  return GestureDetector(
                    onLongPress: () {
                      final data =
                          "${localizations.appVersion}: ${snapshot.data ?? ''} \n ${getCommitRefName() ?? localizations.developerBuild} \n ${getCommitSha() ?? localizations.developerBuild}";
                      Clipboard.setData(ClipboardData(text: data));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(data)),
                      );
                    },
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 30.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: DefaultTextStyle.of(context).style,
                              children: [
                                TextSpan(
                                  text: localizations.appVersion,
                                  style: HelpTab._textStyle,
                                ),
                                const TextSpan(
                                  text: ': ',
                                  style: HelpTab._textStyle,
                                ),
                                TextSpan(
                                  text: snapshot.data ?? '',
                                  style: HelpTab._textStyle,
                                ),
                                const TextSpan(
                                  text: '\n',
                                  style: HelpTab._textStyle,
                                ),
                                TextSpan(
                                  text: getCommitRefName() ??
                                      localizations.developerBuild,
                                  style: HelpTab._textStyle,
                                ),
                                const TextSpan(
                                  text: '\n',
                                  style: HelpTab._textStyle,
                                ),
                                TextSpan(
                                  text: getCommitSha() ??
                                      localizations.developerBuild,
                                  style: HelpTab._textStyle,
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getAppVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return info.version;
  }

  void _navigateToFlow(
    BuildContext context,
    List<String> screenNames, {
    VoidCallback? onForward,
    VoidCallback? onSkip,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProvideContentFlowsWidget(
          eager: false,
          child: MultiScreenFlow(
            screenNames: screenNames,
            onComplete: onForward ?? () => Navigator.pop(context),
            onSkip: onSkip ?? () => Navigator.pop(context),
            showProgress: true,
          ),
        ),
      ),
    );
  }

  Widget _buildModuleSetupTiles(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final knownStations = context.read<KnownStationsModel>();

    return Column(
      children: HelpTab._moduleSetups.map((setup) {
        return ListTile(
          leading: Semantics(
            label: _getModuleIconLabel(setup.key, localizations),
            child: Image.asset(
              setup.assetPath,
              width: 28,
              height: 28,
            ),
          ),
          title: Text(_getTitleText(setup.titleKey, localizations)),
          onTap: () => _checkModuleAndNavigate(
            context,
            setup.key,
            knownStations.stations
                .expand((s) => s.config?.modules ?? [])
                .where((m) => m.key == setup.key)
                .firstOrNull,
          ),
        );
      }).toList(),
    );
  }

  String _getTitleText(String key, AppLocalizations localizations) {
    final titles = {
      'phModuleSetup': localizations.phModuleSetup,
      'waterTempModuleSetup': localizations.waterTempModuleSetup,
      'conductivityModuleSetup': localizations.conductivityModuleSetup,
      'doModuleSetup': localizations.doModuleSetup,
    };
    return titles[key] ?? key;
  }

  String _getModuleIconLabel(String moduleKey, AppLocalizations localizations) {
    final labels = {
      'modules.water.ph': localizations.waterModuleIcon,
      'modules.water.temp': localizations.waterModuleIcon,
      'modules.water.ec': localizations.waterModuleIcon,
      'modules.water.dox': localizations.waterModuleIcon,
    };
    return labels[moduleKey] ?? localizations.waterModuleIcon;
  }

  void _checkModuleAndNavigate(
    BuildContext context,
    String moduleKey,
    ModuleConfig? module,
  ) {
    final knownStations = context.read<KnownStationsModel>();
    final hasAnyStations = knownStations.stations.isNotEmpty;

    // 1. Show setup instructions
    final setup = HelpTab._moduleSetups.firstWhere((s) => s.key == moduleKey);
    _navigateToFlow(
      context,
      setup.setupScreens,
      onForward: () {
        // Only check module and connection if they're trying to proceed
        if (module == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hasAnyStations
                    ? AppLocalizations.of(context)!.noModuleDescription
                    : AppLocalizations.of(context)!.noStationsDescription2,
              ),
            ),
          );
          Navigator.pop(context);
          return;
        }

        final station = _findStationWithModule(knownStations, moduleKey);

        if (!station.connected) {
          _showDisconnectedError(context);
          Navigator.pop(context); // Pop on error
          return;
        }

        // Everything is good, proceed to calibration
        Navigator.pop(context);
        _navigateToCalibration(context, module, station);
      },
      onSkip: () => Navigator.pop(context), // Simple pop on skip
    );
  }

  StationModel _findStationWithModule(
      KnownStationsModel stations, String moduleKey) {
    return stations.stations.firstWhere(
        (s) => s.config?.modules.any((m) => m.key == moduleKey) ?? false);
  }

  void _showDisconnectedError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.stationDisconnectedMessage,
        ),
      ),
    );
  }

  void _navigateToCalibration(
    BuildContext context,
    ModuleConfig module,
    StationModel station,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalibrationPage(
          config: CalibrationConfig.fromModule(
            module,
            AppLocalizations.of(context)!,
            context.read<ContentFlows>(),
          ),
          stationName: station.config?.name ?? "",
        ),
      ),
    );
  }

  void _openWifiSettings(BuildContext context) {
    switch (OpenSettingsPlus.shared) {
      case OpenSettingsPlusAndroid settings:
        settings.wifi();
      case OpenSettingsPlusIOS settings:
        settings.wifi();
      case _:
        throw Exception('Platform not supported');
    }
  }
}
