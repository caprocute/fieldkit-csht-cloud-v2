// constants.dart

import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryColor = Color(0xFFCE596B);
  static const Color logoBlue = Color.fromRGBO(27, 128, 201, 1);
  static const Color text = Color(0xFF2C3E50);
  static const LinearGradient blueGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: <Color>[
        Color.fromARGB(255, 0x23, 0x86, 0xcd),
        Color.fromARGB(255, 0x53, 0xb2, 0xe0)
      ]);
}

class AppIcons {
  static const String sourcePath = "resources/images/";

  static const String stationConnected =
      "${sourcePath}icon_station_connected.svg";
  static const String stationDisconnected =
      "${sourcePath}icon_station_disconnected.svg";
  static const String stationInactive =
      "${sourcePath}icon_station_inactive.png";

  static const String dataSync = "${sourcePath}data_sync.png";
  static const String dataSyncInactive =
      "${sourcePath}icon_data_sync_inactive.png";
  static const String accountSettings =
      "${sourcePath}icon_account_settings.svg";
  static const String helpSettings = "${sourcePath}icon_help_settings.svg";
  static const String legalSettings = "${sourcePath}icon_legal_settings.svg";

  static const String moduleDistance = "${sourcePath}icon_module_distance.png";
  static const String moduleDistanceGray =
      "${sourcePath}icon_module_distance_gray.png";
  static const String moduleGeneric = "${sourcePath}icon_module_generic.png";
  static const String moduleGenericGray =
      "${sourcePath}icon_module_generic_gray.png";
  static const String moduleWaterDo = "${sourcePath}icon_module_water_do.png";
  static const String moduleWaterDoGray =
      "${sourcePath}icon_module_water_do_gray.png";
  static const String moduleWaterEc = "${sourcePath}icon_module_water_ec.png";
  static const String moduleWaterEcGray =
      "${sourcePath}icon_module_water_ec_gray.png";
  static const String moduleWaterOrp = "${sourcePath}icon_module_water_orp.png";
  static const String moduleWaterOrpGray =
      "${sourcePath}icon_module_water_orp_gray.png";
  static const String moduleWaterPh = "${sourcePath}icon_module_water_ph.png";
  static const String moduleWaterPhGray =
      "${sourcePath}icon_module_water_ph_gray.png";
  static const String moduleWaterTemp =
      "${sourcePath}icon_module_water_temp.png";
  static const String moduleWaterTempGray =
      "${sourcePath}icon_module_water_temp_gray.png";
  static const String moduleWeather = "${sourcePath}icon_module_weather.png";
  static const String moduleWeatherGray =
      "${sourcePath}icon_module_weather_gray.png";
  static const String questionMark = "${sourcePath}icon_question_mark.svg";
  static const String settingsActive = "${sourcePath}icon_settings_active.png";
  static const String settingsInactive =
      "${sourcePath}icon_settings_inactive.png";
  static const String stationActive = "${sourcePath}icon_station_active.png";
  static const String logoFkBlue = "${sourcePath}logo_fk_blue.png";
  static const String logoFkWhite = "${sourcePath}logo_fk_white.png";
  static const String splash1125h = "${sourcePath}splash_1125h.png";
  static const String splash736h3x = "${sourcePath}splash_736h_3x.png";
}

class AppStyles {
  static const TextStyle title = TextStyle(
    fontFamily: "Avenir",
    color: Color.fromARGB(255, 0, 44, 44),
    fontWeight: FontWeight.w700,
    fontSize: 17,
  );
}
