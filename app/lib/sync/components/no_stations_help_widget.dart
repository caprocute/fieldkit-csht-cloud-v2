import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';

class NoStationsHelpWidget extends StatelessWidget {
  final bool showImage;

  const NoStationsHelpWidget({super.key, required this.showImage});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showImage)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image.asset('assets/no_stations.png'),
            ),
          Text(
            AppLocalizations.of(context)!.noStationsAvailable,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context)!.connectToStation,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
