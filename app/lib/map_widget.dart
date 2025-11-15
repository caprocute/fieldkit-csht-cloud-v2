import 'dart:io';

import 'package:fk/fullscreen_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:fk/l10n/app_localizations.dart';

// Define default coordinates
double conservifyLat = 34.0312492;
double conservifyLong = -118.269107;
double accuracyDefault =
    20.0; // If the accuracy is null, we'll default to 20.0 meters.

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapState();
}

class _MapState extends State<MapWidget> {
  LatLng? _userLocation;
  MapController mapController = MapController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final localizations = AppLocalizations.of(context)!;
    _getUserLocation(scaffoldMessenger, localizations);
  }

  void _navigateToFullscreen() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => FullscreenMap(
          initialLocation:
              _userLocation ?? LatLng(conservifyLat, conservifyLong)),
    ));
  }

  Future<PermissionStatus> _getPermission(Location location) async {
    final permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      return await location.requestPermission();
    } else {
      return permission;
    }
  }

  Future<void> _getUserLocation(ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations localizations) async {
    // lyokone/location doesn't support Linux, silences noisy exception at startup.
    if (Platform.isLinux) {
      return;
    }

    final location = Location();

    // If location services aren't enabled, don't bother the user.
    if (!await location.serviceEnabled()) {
      return;
    }

    // Asks for permission if we're allowed to.
    final permission = await _getPermission(location);
    if (permission == PermissionStatus.granted) {
      final currentLocation = await location.getLocation();
      if (!mounted) return;
      setState(() {
        _userLocation =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);
      });

      mapController.move(_userLocation!, 12);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(localizations.locationDenied)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter:
                _userLocation ?? const LatLng(34.0312492, -118.269107),
            initialZoom: 12,
            // maxZoom: 19,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              maxZoom: 19,
              userAgentPackageName: 'org.fieldkit.app',
            ),
            CurrentLocationLayer(
              alignPositionOnUpdate: AlignOnUpdate.always,
            ),
          ],
        ),
        Positioned(
          top: 12.0,
          right: 12.0,
          child: IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.fullscreen,
                color: Colors.grey,
              ),
            ),
            tooltip: AppLocalizations.of(context)!.mapExpandTooltip,
            onPressed: _navigateToFullscreen,
          ),
        )
      ],
    );
  }
}
