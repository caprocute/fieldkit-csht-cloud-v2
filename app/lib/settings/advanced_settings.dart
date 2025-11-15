import 'package:fk/preferences.dart';
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context)!;

    return Scaffold(
        appBar: AppBar(
          title: Text(localizations.settingsAdvanced),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: localizations.backButton,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: ListView(padding: const EdgeInsets.all(16.0), children: [
          const TailStationLogsWidget(),
          const SyncProtocolWidget(),
          Text(localizations.httpSyncWarning),
        ]));
  }
}

class SyncProtocolWidget extends StatefulWidget {
  const SyncProtocolWidget({super.key});

  @override
  State<StatefulWidget> createState() => _SyncProtocolState();
}

class _SyncProtocolState extends State<SyncProtocolWidget> {
  bool? _modified;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    final prefs = AppPreferences();

    return FutureBuilder(
        future: prefs.getHttpSync(),
        builder: (context, AsyncSnapshot<bool> snapshot) {
          return CheckboxListTile(
              title: Text(localizations.httpSync),
              value: _modified ?? snapshot.data ?? false,
              onChanged: (bool? value) async {
                setState(() {
                  _modified = value ?? false;
                });
                await prefs.setHttpSync(_modified!);
              });
        });
  }
}

class TailStationLogsWidget extends StatefulWidget {
  const TailStationLogsWidget({super.key});

  @override
  State<StatefulWidget> createState() => _TailStationLogsState();
}

class _TailStationLogsState extends State<TailStationLogsWidget> {
  bool? _modified;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    final prefs = AppPreferences();

    return FutureBuilder(
        future: prefs.getTailStationLogs(),
        builder: (context, AsyncSnapshot<bool> snapshot) {
          return CheckboxListTile(
              title: Text(localizations.tailStationLogs),
              value: _modified ?? snapshot.data ?? false,
              onChanged: (bool? value) async {
                setState(() {
                  _modified = value ?? false;
                });
                await prefs.setTailStationLogs(_modified!);
              });
        });
  }
}
