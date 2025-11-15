import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fk/utils/deep_link_handler.dart';

class StationDisconnectedHelpPage extends StatelessWidget {
  const StationDisconnectedHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return
        // Part of a feature that's not implemented yet to reset the snackbar tapped state

        // PopScope(
        //   onPopInvoked: (bool value) {
        //     StationNotifications().instance.resetSnackbarTapped();
        //   },
        // child:
        Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'resources/images/icon_station_connection_problem.svg',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 30),
                  Text(
                    AppLocalizations.of(context)!.stationDisconnectedTitle,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    AppLocalizations.of(context)!.pressWifiButtonAgain,
                    style: const TextStyle(fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.turnOnStationWifi,
                    style: const TextStyle(fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.visitSupportWebsite,
                    style: const TextStyle(fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        text: 'Fieldkit.org/support',
                        style:
                            const TextStyle(fontSize: 15, color: Colors.blue),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            navigateToPdfSection(
                                context, 'https://www.fieldkit.org/support/');
                          },
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        navigateToPdfSection(context,
                            'https://fieldkit.zohodesk.com/portal/en/kb/articles/i-m-having-issues-connecting-to-my-fieldkit-station-what-should-i-do');
                      },
                      child: Text(AppLocalizations.of(context)!.getHelpButton,
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // )
    );
  }
}
