import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fk/diagnostics.dart';
import 'package:fk/l10n/app_localizations.dart';

Widget padAll(Widget child) {
  return Padding(
    padding: const EdgeInsets.all(14),
    child: child,
  );
}

Widget buildButton(
    String label, String assetPath, bool enabled, VoidCallback? onPressed) {
  return ElevatedButton(
    onPressed: enabled ? onPressed : null,
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    ),
    child: SizedBox(
      width: 100,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            assetPath,
            colorFilter: ColorFilter.mode(
              enabled ? Colors.white : Colors.grey.shade500,
              BlendMode.srcIn,
            ),
            width: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class ActionButton extends StatelessWidget {
  final String label;
  final String iconPath;
  final Future<void> Function()? onPressed;

  const ActionButton({
    super.key,
    required this.label,
    required this.iconPath,
    required this.onPressed,
  });

  String _getIconSemanticsLabel(
      String iconPath, AppLocalizations localizations) {
    switch (iconPath) {
      case 'resources/images/icon_light_download.svg':
        return localizations.downloadIcon;
      case 'resources/images/icon_light_upload.svg':
        return localizations.uploadIcon;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(140, 0),
        padding: const EdgeInsets.all(12),
      ),
      onPressed: onPressed == null
          ? null
          : () async {
              try {
                await onPressed!();
              } catch (e) {
                Loggers.ui.e('Error while executing action: $e');
              } finally {}
            },
      child: Row(
        children: [
          Semantics(
            label:
                _getIconSemanticsLabel(iconPath, AppLocalizations.of(context)!),
            child: SvgPicture.asset(
              iconPath,
              height: 18.0,
              width: 18.0,
              colorFilter: ColorFilter.mode(
                onPressed != null ? Colors.white : Colors.grey.shade500,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          Text(label),
        ],
      ),
    );
  }
}
