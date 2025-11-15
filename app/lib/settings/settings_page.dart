import 'package:fk/settings/advanced_settings.dart';
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'language_page.dart';
import 'accounts_page.dart';
import 'legal_page.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    const colorFilter = ColorFilter.mode(Color(0xFF2c3e50), BlendMode.srcIn);
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.settingsTitle),
        ),
        body: ListView(children: [
          ListTile(
            leading: SvgPicture.asset(
                "resources/images/icon_account_settings.svg",
                semanticsLabel: AppLocalizations.of(context)!.configureIcon),
            title: Text(AppLocalizations.of(context)!.settingsAccounts),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountsPage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: SvgPicture.asset("resources/images/icon_globe.svg",
                semanticsLabel: AppLocalizations.of(context)!.globeIcon,
                colorFilter: colorFilter),
            title: Text(AppLocalizations.of(context)!.settingsLanguage),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LanguagePage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: SvgPicture.asset(
                "resources/images/icon_legal_settings.svg",
                semanticsLabel: AppLocalizations.of(context)!.infoIcon),
            title: Text(AppLocalizations.of(context)!.legalTitle),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LegalPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Semantics(
              label: AppLocalizations.of(context)!.advancedSettingsIcon,
              child: Image.asset("resources/images/icon_data_sync_active.png",
                  width: 20, height: 20),
            ),
            title: Text(AppLocalizations.of(context)!.settingsAdvanced),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AdvancedSettingsPage()),
              );
            },
          ),
        ]));
  }
}
