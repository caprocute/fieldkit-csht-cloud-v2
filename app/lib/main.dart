import 'package:flutter/material.dart';
import 'package:fk/loading_widget.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

import 'gen/frb_generated.dart';

void main() async {
  await RustLib.init();

  // Necessary so we can call path_provider from startup, otherwise this is done
  // inside runApp. 'The "instance" getter on the ServicesBinding binding mixin
  // is only available once that binding has been initialized.'
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // For iOS devices, explicitly show the status bar
  if (Platform.isIOS) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light, // For iOS
    statusBarIconBrightness: Brightness.dark, // For iOS icons
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Set preferred orientations to portraitUp and portraitDown
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const LoadingWidget());
  });
}
