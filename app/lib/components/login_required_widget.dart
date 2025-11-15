import 'package:fk/app_state.dart';
import 'package:fk/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';
import '../settings/edit_account_page.dart';

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

class MessageAndButton extends StatelessWidget {
  final String title;
  final String message;
  final String button;
  final VoidCallback? onPressed;

  const MessageAndButton({
    super.key,
    required this.title,
    required this.message,
    required this.button,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        WH.align(
          Text(title, style: const TextStyle(fontSize: 16.0)),
        ),
        WH.align(
          Text(message, style: const TextStyle(fontSize: 14.0)),
        ),
        WH.align(
          WH.vertical(
            ElevatedTextButton(
              onPressed: onPressed,
              text: button,
            ),
          ),
        ),
      ],
    );
  }
}
