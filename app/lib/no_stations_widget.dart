import 'package:fk/constants.dart';
import 'package:fk/reader/screens.dart';
import 'package:flows/flows.dart' as flows;
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:url_launcher/link.dart';
import 'package:open_settings_plus/open_settings_plus.dart';

import 'common_widgets.dart';

class MaybeBracketed {
  final String text;
  final bool bracketed;

  MaybeBracketed(this.text, this.bracketed);
}

List<MaybeBracketed> extractBracketedText(String text) {
  final List<MaybeBracketed> parsed = List.empty(growable: true);
  int i = 0;
  while (i < text.length) {
    int start = text.indexOf("[", i);
    if (start == -1) {
      parsed.add(MaybeBracketed(text.substring(i, text.length), false));
      break;
    } else {
      int end = text.indexOf("]", start);
      if (end == -1) {
        parsed.add(MaybeBracketed("Malformed bracketed text", false));
        break;
      } else {
        parsed.add(MaybeBracketed(text.substring(i, start), false));
        parsed.add(MaybeBracketed(text.substring(start + 1, end), true));
        i = end + 1;
      }
    }
  }
  return parsed;
}

class NoStationsHelpWidget extends StatelessWidget {
  final bool showImage;

  const NoStationsHelpWidget({super.key, this.showImage = true});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return WH.padPage(
      Column(children: [
        if (showImage)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: SizedBox(
                width: 200.0,
                height: 200.0,
                child: Semantics(
                  label: AppLocalizations.of(context)!.dataSyncIllustration,
                  child: Image.asset('resources/images/data_sync.png',
                      fit: BoxFit.contain),
                ),
              )),
        Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Text(
            localizations.connectStation,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 30.0),
          child: Text(
            localizations.noStationsDescription,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18.0,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Link(
          uri: Uri.parse(
              'https://www.fieldkit.org/product-guide/what-is-a-fieldkit-station'),
          target: LinkTarget.blank,
          builder: (BuildContext ctx, FollowLink? openLink) {
            return Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  bool isPressed = false;

                  return TextButton(
                    onPressed: () {
                      setState(() {
                        isPressed = !isPressed;
                      });
                      openLink!();
                    },
                    style: ButtonStyle(
                      overlayColor: WidgetStateProperty.resolveWith(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.pressed) == true) {
                            return Colors.black.withValues(alpha: 0.5);
                          }
                          return Colors.white;
                        },
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          return const Color(0xFF2C3E50);
                        },
                      ),
                      textStyle: WidgetStateProperty.resolveWith<TextStyle>(
                        (Set<WidgetState> states) {
                          return const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Avenir',
                          );
                        },
                      ),
                    ),
                    child: Text(localizations.noStationsWhatIsStation),
                  );
                },
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(50, 0, 50, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedTextButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ProvideContentFlowsWidget(
                            eager: false,
                            child: QuickFlow(
                                start: const flows.StartFlow(prefix: "wifi"),
                                onSkip: () {
                                  Navigator.pop(context);
                                },
                                onComplete: () {
                                  switch (OpenSettingsPlus.shared) {
                                    case OpenSettingsPlusAndroid settings:
                                      settings.wifi();
                                    case OpenSettingsPlusIOS settings:
                                      settings.wifi();
                                    case _:
                                      throw Exception('Platform not supported');
                                  }
                                },
                                showProgress: true))));
              },
              text: AppLocalizations.of(context)!.connectStation,
            ),
          ),
        ),
      ]),
    );
  }
}
