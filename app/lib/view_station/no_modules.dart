import 'package:fk/models/known_stations_model.dart';
import 'package:fk/diagnostics.dart';
import 'package:fk/view_station/view_station_page.dart';
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:fk/reader/screens.dart';

class NoModulesWidget extends StatelessWidget {
  final StationModel station;

  const NoModulesWidget({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  label: AppLocalizations.of(context)!.warningErrorIcon,
                  child: Image.asset(
                    'resources/images/icon_warning_error.png',
                    width: 60,
                    height: 60,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  localizations.noModulesTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  localizations.noModulesMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MultiScreenFlow(
                            screenNames: const [
                              'no_modules.01',
                              'no_modules.02',
                              'no_modules.03',
                              'no_modules.04',
                            ],
                            onComplete: () {
                              Loggers.ui.i("NoModules: onComplete");
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ViewStationRoute(
                                      deviceId: station.deviceId),
                                ),
                              );
                            },
                            onSkip: () => Navigator.pop(context),
                            showProgress: true,
                          ),
                        ),
                      );
                    },
                    child: Text(localizations.addModulesButton,
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
