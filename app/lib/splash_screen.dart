import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';

class FullScreenLogo extends StatelessWidget {
  const FullScreenLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(color: Colors.white),
        child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LargeLogo(),
              Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator()))
            ]));
  }
}

class LargeLogo extends StatelessWidget {
  final bool white;

  const LargeLogo({super.key, this.white = false});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final label = localizations?.fieldKitLogo ?? "FieldKit Logo";
    if (white) {
      return Semantics(
        label: label,
        child: Image.asset("resources/images/logo_fk_white.png"),
      );
    } else {
      return Semantics(
        label: label,
        child: Image.asset("resources/images/logo_fk_blue.png"),
      );
    }
  }
}
