import 'package:fk/common_widgets.dart';
import 'package:fk/reader/screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fk/l10n/app_localizations.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onDone;

  const WelcomeScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    return PopScope(
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          if (didPop) {
            onDone();
          }
        },
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    label: AppLocalizations.of(context)!.fieldKitLogo,
                    child: Image.asset('resources/images/logo_fk_blue.png'),
                  ),
                  Semantics(
                    label: AppLocalizations.of(context)!.welcomeImage,
                    child: Image.asset('resources/images/art/welcome.jpg'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                    child: Text(
                      AppLocalizations.of(context)!.welcomeTitle,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.welcomeMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Divider(
                    color: Colors.grey[300],
                    thickness: 1.0,
                    indent: 50,
                    endIndent: 50,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 5),
                    child: ElevatedTextButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (BuildContext context) =>
                                    ProvideContentFlowsWidget(
                                      eager: false,
                                      child: MultiScreenFlow(
                                          screenNames: const [
                                            "onboarding.01",
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
                                          ],
                                          onComplete: () {
                                            Navigator.pop(context);
                                            onDone();
                                          },
                                          onSkip: () {
                                            Navigator.pop(context);
                                            onDone();
                                          },
                                          showProgress: true),
                                    )));
                      },
                      text: AppLocalizations.of(context)!.welcomeButton,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onDone();
                    },
                    child: Text(
                      AppLocalizations.of(context)!.skipInstructions,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
