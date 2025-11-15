import 'dart:collection';
import 'dart:io';

import 'package:fk/l10n/app_localizations.dart';
import 'package:fk/common_widgets.dart';
import 'package:fk/constants.dart';
import 'package:fk/data/export.dart';
import 'package:fk/diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_circular_progress_bar/simple_circular_progress_bar.dart';

class ExportModel with ChangeNotifier {
  final HashMap<String, ExportEvent> _active = HashMap();

  ExportEvent? get(String deviceId) => _active[deviceId];

  void start(String deviceId) async {
    final exporter = Exporter(deviceId: deviceId);
    await for (final event in exporter.exportAll()) {
      _active[deviceId] = event;
      notifyListeners();
    }
    Loggers.state.i("done");
  }

  void clear(String deviceId) {
    notifyListeners();
    _active.remove(deviceId);
  }
}

class ExportPanel extends StatelessWidget {
  final String deviceId;

  const ExportPanel({super.key, required this.deviceId});

  Widget _buildExportRow(
    BuildContext context,
    AppLocalizations localizations, {
    required bool hasData,
    required VoidCallback? onPressed,
    required double buttonWidth,
    required EdgeInsets padding,
  }) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            localizations.settingsExport,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(
            width: buttonWidth,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor:
                    hasData ? AppColors.primaryColor : Colors.grey[300],
                foregroundColor: hasData ? Colors.white : Colors.grey[600],
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onPressed: onPressed,
              child: Text(
                hasData
                    ? localizations.exportStart
                    : localizations.exportNoData,
                style: TextStyle(
                  color: hasData ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer<ExportModel>(
      builder: (BuildContext context, ExportModel exports, Widget? child) {
        final event = exports.get(deviceId);

        if (event == null) {
          final exporter = Exporter(deviceId: deviceId);

          return FutureBuilder(
              future: exporter.calculate(),
              builder: (context, snapshot) {
                final possible = snapshot.data;
                if (possible == null) {
                  return _buildExportRow(
                    context,
                    localizations,
                    hasData: false,
                    onPressed: null,
                    buttonWidth: 100,
                    padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
                  );
                }

                final hasData = possible.readings > 0;
                return _buildExportRow(
                  context,
                  localizations,
                  hasData: hasData,
                  onPressed: hasData ? () => exports.start(deviceId) : null,
                  buttonWidth: hasData ? 120 : 100,
                  padding: hasData
                      ? const EdgeInsets.symmetric(horizontal: 20)
                      : const EdgeInsets.fromLTRB(16, 0, 20, 0),
                );
              });
        }

        if (event.done && event.file != null) {
          if (Platform.isAndroid || Platform.isIOS) {
            return Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(localizations.exportCompleted),
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: ElevatedTextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 16),
                        ),
                        text: localizations.exportShare,
                        onPressed: () async {
                          // For some reason, passing text on iOS ends up sharing
                          // an additional text file with the contents of that
                          // string. I also just left subject out because it's not
                          // used either. It's very strange. Furthmore, neither of
                          // the text values appears under Android, so we're not
                          // sending either.
                          await SharePlus.instance.share(ShareParams(
                            files: [XFile(event.file!)],
                          ));
                        },
                      ),
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: ElevatedTextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 16),
                        ),
                        text: localizations.exportStartOver,
                        onPressed: () {
                          exports.start(deviceId);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(localizations.exportShareUnsupported),
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        child: ElevatedTextButton(
                            text: localizations.ok,
                            onPressed: () {
                              exports.clear(deviceId);
                            }))
                  ],
                ),
              ),
            );
          }
        }

        if (event.empty) {
          return Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(localizations.exportNoData),
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      child: ElevatedTextButton(
                          text: localizations.ok,
                          onPressed: () {
                            exports.clear(deviceId);
                          }))
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: SimpleCircularProgressBar(
                    key: ValueKey(event.progress),
                    progressStrokeWidth: 6,
                    backStrokeWidth: 6,
                    backColor: const Color(0xfff4f5f7),
                    animationDuration: 0,
                    progressColors: const [Color(0xFF1b80c9)],
                    valueNotifier: ValueNotifier<double>(event.progress * 100),
                    onGetText: (double value) {
                      return Text(
                        '${value.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
