import 'package:geolocator/geolocator.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class LocationService {
  static Future<bool> handlePermission(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.locationDenied),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => _openLocationSettings(),
            ),
          ),
        );
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.locationDenied),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => _openLocationSettings(),
              ),
            ),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.locationDenied),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => _openLocationSettings(),
            ),
          ),
        );
      }
      return false;
    }

    // Permissions are granted
    return true;
  }

  static Future<Position?> getCurrentPosition(BuildContext context) async {
    if (await handlePermission(context)) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.locationDenied),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => _openLocationSettings(),
              ),
            ),
          );
        }
        return null;
      }
    }
    return null;
  }

  static Future<void> _openLocationSettings() async {
    if (Platform.isIOS) {
      await Geolocator.openAppSettings();
    } else if (Platform.isAndroid) {
      await Geolocator.openLocationSettings();
    }
  }
}
