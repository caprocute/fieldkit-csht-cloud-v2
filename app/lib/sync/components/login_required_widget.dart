import 'package:fk/app_state.dart';
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';
import '../../../settings/edit_account_page.dart';
import '../../components/login_required_widget.dart';

class LoginRequiredWidget extends StatelessWidget {
  const LoginRequiredWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: MessageAndButton(
            title: localizations.alertTitle,
            button: localizations.login,
            message: localizations.dataLoginMessage,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditAccountPage(
                    original: PortalAccount(
                        email: "",
                        name: "",
                        tokens: null,
                        active: false,
                        validity: Validity.unchecked),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
