import 'package:fk/constants.dart';
import 'package:fk/gen/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class LastConnected extends StatelessWidget {
  final UtcDateTime? lastConnected;
  final bool connected;
  final double size;

  final colorFilter =
      const ColorFilter.mode(Color(0xFFcccdcf), BlendMode.srcIn);

  const LastConnected(
      {super.key,
      this.lastConnected,
      required this.connected,
      required this.size});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final boxConstraints = BoxConstraints(
      minHeight: 5 * size,
      minWidth: 5 * size,
      maxHeight: 150 * size,
      maxWidth: 200 * size,
    );

    if (connected) {
      return ConstrainedBox(
        constraints: boxConstraints,
        child: ListTile(
          visualDensity: const VisualDensity(vertical: -4),
          leading: SizedBox(
            width: 36 * size,
            height: 36 * size,
            child: SvgPicture.asset(AppIcons.stationConnected),
          ),
          title: Text(
            localizations.stationConnected,
            style: TextStyle(fontSize: 12.0 * size),
          ),
        ),
      );
    }
    final titleText = lastConnected != null
        ? localizations.lastConnected
        : localizations.notConnected;
    final subtitleText = lastConnected != null
        ? DateFormat.yMd().add_jm().format(DateTime.fromMicrosecondsSinceEpoch(
            (lastConnected!.field0.toInt()) * 1000))
        : null;

    return ConstrainedBox(
      constraints: boxConstraints,
      child: ListTile(
        visualDensity: const VisualDensity(vertical: -4),
        leading: SizedBox(
          width: 36 * size,
          height: 36 * size,
          child: SvgPicture.asset(
            AppIcons.stationDisconnected,
            semanticsLabel: localizations.stationDisconnectedIcon,
            colorFilter: colorFilter,
          ),
        ),
        title: Text(titleText, style: TextStyle(fontSize: 11 * size)),
        subtitle: subtitleText != null
            ? Text(subtitleText,
                style: TextStyle(fontSize: 10 * size, color: Colors.grey))
            : null,
      ),
    );
  }
}
