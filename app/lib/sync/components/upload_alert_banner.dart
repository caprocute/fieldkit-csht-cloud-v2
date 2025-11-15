import 'package:fk/app_state.dart';
import 'package:fk/settings/edit_account_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fk/l10n/app_localizations.dart';

class UploadAlertBanner extends StatelessWidget {
  final bool login;
  final bool isConnected;
  final UploadTask? uploadTask;

  const UploadAlertBanner({
    super.key,
    required this.login,
    required this.isConnected,
    this.uploadTask,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    Widget alertMessage = const SizedBox.shrink();

    if (uploadTask != null) {
      bool isNotConnected = !isConnected;
      bool isNotLoggedIn = !login;

      if (isNotConnected && isNotLoggedIn) {
        // Both upload/auth problems and connection/login issues exist
        alertMessage =
            buildRichText(context, localizations.loginAndConnectStationAlert);
      } else if (isNotConnected) {
        // Only upload or connection issue exists
        alertMessage =
            buildRichText(context, localizations.connectStationAlert);
      } else if (isNotLoggedIn) {
        // Only auth or login issue exists
        alertMessage = buildRichText(context, localizations.loginStationAlert);
      }
    } else {
      // widget.uploadTask is null
      bool isNotConnected = !isConnected;
      bool isNotLoggedIn = !login;

      if (isNotLoggedIn && isNotConnected) {
        // Both login and connection issues
        alertMessage =
            buildRichText(context, localizations.loginAndConnectStationAlert);
      } else if (isNotConnected) {
        // Only connection issue
        alertMessage =
            buildRichText(context, localizations.connectStationAlert);
      } else if (isNotLoggedIn) {
        // Only login issue
        alertMessage = buildRichText(context, localizations.loginStationAlert);
      } else {
        // No issues
        alertMessage = const SizedBox.shrink();
      }
    }

    return Container(
      padding:
          alertMessage is SizedBox ? EdgeInsets.zero : const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFFFE1B9),
      ),
      child: Row(
        children: [
          if (alertMessage is! SizedBox)
            SvgPicture.asset(
              'resources/images/notice_dark_icon.svg',
              height: 16.0,
              width: 16.0,
              semanticsLabel: AppLocalizations.of(context)!.noticeIcon,
            ),
          const SizedBox(width: 8.0),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 50,
                maxWidth: 350,
              ),
              child: alertMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRichText(BuildContext context, String message) {
    return RichText(
      text: TextSpan(
        text: '$message ',
        style: const TextStyle(
          fontSize: 14.0,
          color: Colors.black,
        ),
        children: [
          TextSpan(
            text: (!login) ? AppLocalizations.of(context)!.loginLink : '',
            style: const TextStyle(
              color: Colors.black,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditAccountPage(
                      original: PortalAccount(
                        email: "",
                        name: "",
                        tokens: null,
                        active: false,
                        validity: Validity.unchecked,
                      ),
                    ),
                  ),
                );
              },
          ),
          if (!login)
            const TextSpan(
              text: '.',
              style: TextStyle(
                color: Colors.black,
              ),
            ),
        ],
      ),
    );
  }
}
