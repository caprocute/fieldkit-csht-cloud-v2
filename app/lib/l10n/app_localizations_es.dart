// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get fieldKit => 'FieldKit';

  @override
  String get welcomeTitle => '¡Bienvenido!';

  @override
  String get welcomeMessage =>
      'Nuestra aplicación móvil facilita la configuración e instalación de tu estación FieldKit.';

  @override
  String get welcomeButton => 'Empezar';

  @override
  String get skipInstructions => 'Saltar instrucciones';

  @override
  String get stationsTab => 'Estaciones';

  @override
  String get dataSyncTab => 'Datos';

  @override
  String get settingsTab => 'Configuración';

  @override
  String get helpTab => 'Help';

  @override
  String get dataSyncTitle => 'Datos';

  @override
  String get alertTitle => '¡Aviso!';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get dataLoginMessage => 'Para subir datos necesitas iniciar sesión:';

  @override
  String get modulesTitle => 'Módulos';

  @override
  String get addModulesButton => 'Add Modules';

  @override
  String get noModulesMessage =>
      'Your station needs modules in order to complete setup, deploy, and capture data.';

  @override
  String get noModulesTitle => 'No Modules Attached';

  @override
  String get connectStation => 'Conectar una estación';

  @override
  String get noStationsDescription =>
      'No tienes estaciones. Agrega una estación para empezar a recoger datos.';

  @override
  String get noStationsDescription2 =>
      'You have no stations. Add a station in order to calibrate modules.';

  @override
  String get noStationsWhatIsStation => 'What is a FieldKit Station?';

  @override
  String get locationDenied => '¡Permiso de ubicación denegado!';

  @override
  String get lastReadingLabel => ' (Última lectura)';

  @override
  String get daysHoursMinutes => 'days  hrs  mins';

  @override
  String get download => 'Descargar';

  @override
  String get upload => 'Subir';

  @override
  String readingsUploadable(num readings) {
    final intl.NumberFormat readingsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String readingsString = readingsNumberFormat.format(readings);

    String _temp0 = intl.Intl.pluralLogic(
      readings,
      locale: localeName,
      other: '$readingsString Uploads',
      one: '1 Upload',
      zero: '0 Uploads',
    );
    return '$_temp0';
  }

  @override
  String readingsDownloadable(num readings) {
    final intl.NumberFormat readingsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String readingsString = readingsNumberFormat.format(readings);

    String _temp0 = intl.Intl.pluralLogic(
      readings,
      locale: localeName,
      other: '$readingsString Downloads',
      one: '1 Downloads',
      zero: '0 Downloads',
    );
    return '$_temp0';
  }

  @override
  String downloadIncomplete(num readings, num total) {
    final intl.NumberFormat readingsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String readingsString = readingsNumberFormat.format(readings);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Only $readingsString of $totalString downloaded.';
  }

  @override
  String downloadProgress(num readings, num total) {
    final intl.NumberFormat readingsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String readingsString = readingsNumberFormat.format(readings);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$readingsString Downloaded...';
  }

  @override
  String get uploadProgress => 'Uploading...';

  @override
  String readingsUploaded(num readings) {
    final intl.NumberFormat readingsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String readingsString = readingsNumberFormat.format(readings);

    String _temp0 = intl.Intl.pluralLogic(
      readings,
      locale: localeName,
      other: '$readingsString Readings Uploaded',
      one: '1 Reading Uploaded',
      zero: '0 Readings Uploaded',
    );
    return '$_temp0';
  }

  @override
  String readingsDownloaded(num readings) {
    final intl.NumberFormat readingsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String readingsString = readingsNumberFormat.format(readings);

    String _temp0 = intl.Intl.pluralLogic(
      readings,
      locale: localeName,
      other: '$readingsString Readings Downloaded',
      one: '1 Reading Downloaded',
      zero: '0 Readings Downloaded',
    );
    return '$_temp0';
  }

  @override
  String get uploading => 'Uploading';

  @override
  String get readytoDownload => 'Ready to download';

  @override
  String get readytoUpload => 'Ready to upload';

  @override
  String get syncDismissOk => 'OK';

  @override
  String get syncDownloadSuccess => 'Download successful!';

  @override
  String get syncUploadSuccess => 'Upload successful!';

  @override
  String get syncDownloadFailed =>
      'Error: Download Failed. \nWait a few seconds and try again.';

  @override
  String get syncUploadFailed =>
      'Error: Upload Failed. \nConnect to the internet and try again.';

  @override
  String get syncNoAuthentication => 'You aren\'t logged in.';

  @override
  String get syncNoInternet => 'No internet connection.';

  @override
  String get quickTip => 'Quick Tip';

  @override
  String get stationConnected => 'Connected';

  @override
  String get lastConnected => 'Last Connected';

  @override
  String get notConnected => 'Not Connected';

  @override
  String lastConnectedSince(Object date) {
    return 'Since $date';
  }

  @override
  String get stationDeployed => 'Station Deployed';

  @override
  String get noStationsAvailable => 'No stations available';

  @override
  String get connectToStation => 'Please connect to a station to continue';

  @override
  String get myStationsTitle => 'Mis estaciones';

  @override
  String get deployedAt => 'Deployed';

  @override
  String get readyToDeploy => 'Listo para desplegar';

  @override
  String get readyToCalibrate => 'Ready to Calibrate';

  @override
  String get calibratingBusy => 'Calibrating...';

  @override
  String get busyWorking => 'Ocupado...';

  @override
  String get busyUploading => 'Subiendo...';

  @override
  String get busyDownloading => 'Descargando...';

  @override
  String get busyUpgrading => 'Actualizando...';

  @override
  String get contacting => 'Contactando...';

  @override
  String get unknownStationTitle => 'Estación desconocida';

  @override
  String get backButtonTitle => 'Atrás';

  @override
  String get importantNoteTitle => 'Important Note: ';

  @override
  String get updateRequiredDataPage =>
      'An update is required to sync data from this station.';

  @override
  String get connectStationAlert => 'To upload data, connect to the internet.';

  @override
  String get loginStationAlert => 'To upload data,';

  @override
  String get loginAndConnectStationAlert =>
      'To upload data, connect to the internet and';

  @override
  String get loginLink => 'login';

  @override
  String get deployButton => 'Desplegar';

  @override
  String get deployTitle => 'Desplegar estación';

  @override
  String get deployLocation => 'Nombrar tu ubicación';

  @override
  String get manageFirmwareButton => 'Manage Firmware';

  @override
  String get firmwareContinue => 'Continue';

  @override
  String get firmwareCancel => 'Cancel';

  @override
  String get firmwareReconnectTimeout => 'Reconnect Timeout';

  @override
  String get firmwareSdCardError => 'SD Card Error';

  @override
  String get firmwareDismiss => 'OK';

  @override
  String get firmwarePrepareTitle => 'Prepare For Update';

  @override
  String get firmwarePrepareTime => 'This update may take several minutes.';

  @override
  String get firmwarePrepareSd =>
      'You will need an SD card in your station to complete the update.';

  @override
  String get firmwarePreparePower =>
      'Keep your station plugged in and close to your device or smart phone.';

  @override
  String get firmwarePrepareConnection =>
      'Your station will restart and you might have to reconnect to the station.';

  @override
  String get calibrationStartTimer => 'Iniciar temporizador';

  @override
  String get calibrationTitle => 'Calibración';

  @override
  String get calibrateButton => 'Calibrar';

  @override
  String get calibrationDelete => 'Eliminar';

  @override
  String get calibrationBack => 'Atrás';

  @override
  String get calibrationKeepButton => 'Mantener';

  @override
  String get calibrationSaveButton => 'Save Calibrations';

  @override
  String calibrationPoint(int step) {
    return 'Calibration Point $step';
  }

  @override
  String get countdownInstructions2 =>
      'Tap the Calibrate button to record the sensor value and the standard value.';

  @override
  String get factory => 'Fábrica';

  @override
  String get uncalibrated => 'No calibrado';

  @override
  String get calibrated => 'Calibrado';

  @override
  String get voltage => 'Voltaje';

  @override
  String get standardTitle => 'Estándar';

  @override
  String get waitingOnTimer => 'Esperando en el temporizador';

  @override
  String get waitingOnReading => 'Esperando a una lectura nueva';

  @override
  String get waitingOnForm => 'Valores requeridos';

  @override
  String standardValue(Object uom, Object value) {
    return 'Valor estándar $value ($uom)';
  }

  @override
  String standardValue2(Object uom) {
    return 'Valor estándar ($uom)';
  }

  @override
  String get sensorValue => 'Valor del sensor:';

  @override
  String get oopsBugTitle => 'Vaya, ¿un error?';

  @override
  String get standard => 'Estándar';

  @override
  String get countdownInstructions =>
      'Pulsa el botón Calibrar para grabar el valor del sensor y el valor estándar.';

  @override
  String get calibrationMessage =>
      'La grabación de estos valores juntos nos permite calibrar el sensor más adelante.';

  @override
  String get standardFieldLabel => 'Estándar';

  @override
  String get backAreYouSure => '¿Estás seguro?';

  @override
  String get backWarning =>
      'Navegar hacia fuera requerirá iniciar esta calibración.';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get readingsSchedule => 'Readings Schedule';

  @override
  String get scheduleUpdated => 'Schedule Updated';

  @override
  String get settingsAdvanced => 'Advanced Settings';

  @override
  String get httpSync => 'HTTP Sync';

  @override
  String get httpSyncWarning => 'HTTP Sync Warning';

  @override
  String get tailStationLogs => 'Tail Station Logs';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsNameHint => 'Station Name';

  @override
  String get nameConfigSuccess => 'Station Name Updated.';

  @override
  String errorMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get settingsFirmware => 'Firmware';

  @override
  String get settingsModules => 'Módulos';

  @override
  String get settingsWifi => 'WiFi';

  @override
  String get settingsLora => 'LoRa';

  @override
  String get settingsAutomaticUpload => 'Configuración de subida automática';

  @override
  String get forgetStation => 'Olvidar estación';

  @override
  String get settingsEvents => 'Eventos';

  @override
  String get settingsLoraEdit => 'Modificar';

  @override
  String get settingsLoraVerify => 'Verificar';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get endDeployment => 'Finalizar despliegue';

  @override
  String get error => 'Error';

  @override
  String get ok => 'OK';

  @override
  String get save => 'Save';

  @override
  String get submit => 'Submit';

  @override
  String get nameErrorDescription =>
      'Name can only contain letters, numbers, underscores, and spaces.';

  @override
  String get settingsExport => 'Export CSV';

  @override
  String get exportStart => 'Start';

  @override
  String get exportStartOver => 'Start Over';

  @override
  String get exportShare => 'Share';

  @override
  String get exportCompleted => 'Completed';

  @override
  String get exportShareUnsupported =>
      'Sharing not supported on this platform.';

  @override
  String get exportNoData => 'No Data';

  @override
  String exportPossible(num readings) {
    final intl.NumberFormat readingsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String readingsString = readingsNumberFormat.format(readings);

    return '$readingsString available to export.';
  }

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get eventUnknown => 'Evento desconocido';

  @override
  String get eventRestart => 'Reiniciar evento';

  @override
  String get eventLora => 'Evento LoRa';

  @override
  String get eventTime => 'Tiempo';

  @override
  String get eventCode => 'Código';

  @override
  String get eventReason => 'Razón';

  @override
  String get noEvents => 'No Events';

  @override
  String get networksTitle => 'Redes WiFi';

  @override
  String get networkAddButton => 'Añadir red';

  @override
  String get networkEditTitle => 'Red WiFi';

  @override
  String get networkSaveButton => 'Guardar';

  @override
  String get networkAutomaticUploadEnable => 'Activar';

  @override
  String get networkAutomaticUploadDisable => 'Desactivar';

  @override
  String get networkRemoveButton => 'Eliminar';

  @override
  String get networkNoMoreSlots =>
      'Desafortunadamente, sólo hay dos posiciones de red WiFi disponibles.';

  @override
  String get wifiSsid => 'SSID';

  @override
  String get wifiPassword => 'Contraseña';

  @override
  String get confirmRemoveNetwork => 'Eliminar red';

  @override
  String get loraBand => 'Frecuencia';

  @override
  String get loraAppKey => 'Clave de App';

  @override
  String get loraJoinEui => 'Únete a EUI';

  @override
  String get loraDeviceEui => 'EUI de dispositivo';

  @override
  String get loraDeviceAddress => 'Dirección del dispositivo';

  @override
  String get loraNetworkKey => 'Clave de red';

  @override
  String get loraSessionKey => 'Clave de sesión';

  @override
  String get loraNoModule => 'No se ha detectado ningún módulo LoRa.';

  @override
  String get loraConfigurationTitle => 'Configuración de LoRa';

  @override
  String get hexStringValidationFailed =>
      'Se esperaba una cadena hexadecimal válida.';

  @override
  String get firmwareTitle => 'Firmware';

  @override
  String get firmwareUpgrade => 'Actualizar';

  @override
  String get firmwareSwitch => 'Cambiar';

  @override
  String get firmwareStarting => 'Iniciando...';

  @override
  String get firmwareUploading => 'Subiendo...';

  @override
  String get firmwareRestarting => 'Reiniciando...';

  @override
  String get firmwareCompleted => 'Completado';

  @override
  String get firmwareFailed => '¡Fallo!';

  @override
  String get firmwareConnected => 'Conectado';

  @override
  String get firmwareNotConnected => 'No conectado';

  @override
  String firmwareVersion(Object firmwareVersion) {
    return 'Versión del firmware: $firmwareVersion';
  }

  @override
  String get firmwareUpdated => 'El firmware está actualizado';

  @override
  String get firmwareNotUpdated => 'El firmware no está actualizado';

  @override
  String get firmwareUpdate => 'Actualizar firmware';

  @override
  String firmwareReleased(String firmwareReleaseDate) {
    return 'Versión publicada: $firmwareReleaseDate';
  }

  @override
  String get firmwareTip =>
      'Asegúrate de estar conectado a Internet antes de comprobar si hay nuevas versiones de firmware.';

  @override
  String get settingsAccounts => 'Cuentas';

  @override
  String get accountsTitle => 'Cuentas';

  @override
  String get accountsAddButton => 'Añadir una cuenta';

  @override
  String get accountsNoneCreatedTitle =>
      '¡Parece que todavía no hay cuentas creadas!';

  @override
  String get accountsNoneCreatedMessage =>
      'Tener una cuenta FieldKit es útil para actualizar la información de tu estación en el portal en línea y de vez en cuando acceder al firmware específico del usuario. ¿Estás conectado al internet? ¡Una vez que estés, configuremos una cuenta para ti!';

  @override
  String get confirmRemoveAccountTitle => 'Eliminar cuenta';

  @override
  String get accountAddTitle => 'Añadir cuenta';

  @override
  String get noInternetConnection => 'No Internet Connection';

  @override
  String get accountName => 'Nombre';

  @override
  String get accountEmail => 'Correo electrónico';

  @override
  String get accountPassword => 'Contraseña';

  @override
  String get accountConfirmPassword => 'Confirmar contraseña';

  @override
  String get accountConfirmPasswordMatch => 'Las contraseñas deben coincidir.';

  @override
  String get accountSaveButton => 'Guardar';

  @override
  String get accountRegisterButton => 'Registrarte';

  @override
  String get accountRemoveButton => 'Eliminar';

  @override
  String get accountRepairButton => 'Iniciar sesión';

  @override
  String get accountRegisterLabel => 'Crear una cuenta';

  @override
  String get accountDefault => 'Esta es tu cuenta predeterminada.';

  @override
  String get accountInvalid => 'Algo va mal con esta cuenta.';

  @override
  String get accountConnectivity =>
      'Hubo un problema al conectar con esta cuenta. Si el problema fue relacionado con la red, esto se corregirá a sí mismo.';

  @override
  String get accountCreated =>
      '¡Registro exitoso! Por favor revisa tu correo electrónico para obtener instrucciones de verificación antes de iniciar sesión.';

  @override
  String get accountUpdated => 'Your account has been successfully updated.';

  @override
  String get invalidCredentialsError =>
      'The credentials you entered are incorrect. Please try again.';

  @override
  String get serverError =>
      'There was a problem connecting to the server. Please check your connection and try again.';

  @override
  String bayNumber(Object bay) {
    return 'Bahía #$bay';
  }

  @override
  String get batteryLife => 'Carga de la batería';

  @override
  String get memoryUsage => 'Memoria';

  @override
  String get confirmClearCalibrationTitle => 'Borrar calibración';

  @override
  String get confirmDelete => '¿Estás seguro?';

  @override
  String get confirmYes => 'Sí';

  @override
  String get confirmCancel => 'Cancelar';

  @override
  String get helpTitle => 'Ayuda';

  @override
  String get helpCheckList => 'Lista de verificación previa a la instalación';

  @override
  String get offlineProductGuide => 'Offline Product Guide';

  @override
  String get search => 'Search';

  @override
  String get enterSearchTerm => 'Enter Search Term';

  @override
  String get cancel => 'Cancel';

  @override
  String get appVersion => 'Versión de App';

  @override
  String get errorLoadingVersion => 'Error Loading App Version';

  @override
  String get helpUploadLogs => 'Enviar registros';

  @override
  String get helpCreateBackup => 'Create Phone Backup';

  @override
  String get reportIssue => 'Report Issue';

  @override
  String get reportIssueDescription =>
      'Describe the issue you are experiencing';

  @override
  String get reportIssueEmail => 'Email Address';

  @override
  String get reportIssueSubmit => 'Submit';

  @override
  String get reportIssueSubmitted => 'Issue Submitted';

  @override
  String get reportIssueThankYou =>
      'Thank you for your feedback. We\'ll review your report and get back to you soon.';

  @override
  String get reportIssueEmailRequired => 'Please include an email';

  @override
  String get reportIssueEmailInvalid => 'Please enter a valid email address';

  @override
  String get reportIssueSubmissionFailed => 'Failed to submit report';

  @override
  String get reportIssueNetworkError =>
      'Network error occurred. Please check your connection and try again.';

  @override
  String get reportIssueServerError =>
      'Server error occurred. Please try again later.';

  @override
  String get photos => 'Photos';

  @override
  String get attachPhotos => 'Attach Photos';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get helpBackupCreated => 'Phone Backup Created';

  @override
  String get helpBackupFailed => 'Phone Backup Failed';

  @override
  String get backupShareSubject => 'FieldKit Backup';

  @override
  String get backupShareMessage => 'FieldKit application backup.';

  @override
  String get developerBuild => 'Versión de desarrollador';

  @override
  String get logsUploaded => 'Logs Uploaded';

  @override
  String get legalTitle => 'Legal';

  @override
  String get termsOfService => 'Términos de servicio';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get licenses => 'Licencias';

  @override
  String get modulesWaterTemp => 'Módulo de temperatura del agua';

  @override
  String get modulesWaterPh => 'Módulo de pH';

  @override
  String get modulesWaterOrp => 'Módulo de ORP';

  @override
  String get modulesWaterDo => 'Módulo de oxígeno disuelto';

  @override
  String get modulesWaterEc => 'Módulo de conductividad';

  @override
  String get modulesWaterDepth => 'Módulo de profundidad de agua';

  @override
  String get modulesWeather => 'Módulo meteorológico';

  @override
  String get modulesDiagnostics => 'Módulo de diagnóstico';

  @override
  String get modulesRandom => 'Módulo aleatorio';

  @override
  String get modulesDistance => 'Módulo de distancia';

  @override
  String get modulesUnknown => 'Módulo desconocido';

  @override
  String get sensorWaterTemperature => 'Temperatura del agua';

  @override
  String get sensorWaterPh => 'pH';

  @override
  String get sensorWaterEc => 'Conductividad';

  @override
  String get sensorWaterDo => 'Oxígeno disuelto';

  @override
  String get sensorWaterDoPressure => 'Oxígeno del aire';

  @override
  String get sensorWaterDoTemperature => 'Temperatura del aire';

  @override
  String get sensorWaterOrp => 'Potencial de reducción (ORP)';

  @override
  String get sensorWaterDepthPressure => 'Profundidad del agua (presión)';

  @override
  String get sensorWaterDepthTemperature => 'Temperatura del agua';

  @override
  String get sensorDiagnosticsTemperature => 'Temperatura interna';

  @override
  String get sensorDiagnosticsUptime => 'Periodo de uso';

  @override
  String get sensorDiagnosticsMemory => 'Memoria';

  @override
  String get sensorDiagnosticsFreeMemory => 'Memoria libre';

  @override
  String get sensorDiagnosticsBatteryCharge => 'Batería';

  @override
  String get sensorDiagnosticsBatteryVoltage => 'Batería';

  @override
  String get sensorDiagnosticsBatteryVBus => 'Batería (VBus)';

  @override
  String get sensorDiagnosticsBatteryVs => 'Batería (Vs)';

  @override
  String get sensorDiagnosticsBatteryMa => 'Battería (mA)';

  @override
  String get sensorDiagnosticsBatteryPower => 'Batería (Potencia)';

  @override
  String get sensorDiagnosticsSolarVBus => 'Solar (VBus)';

  @override
  String get sensorDiagnosticsSolarVs => 'Solar (Vs)';

  @override
  String get sensorDiagnosticsSolarMa => 'Solar (mA)';

  @override
  String get sensorDiagnosticsSolarPower => 'Solar (Potencia)';

  @override
  String get sensorWeatherRain => 'Lluvia';

  @override
  String get sensorWeatherWindSpeed => 'Velocidad del viento';

  @override
  String get sensorWeatherWindDirection => 'Dirección del viento';

  @override
  String get sensorWeatherHumidity => 'Humedad';

  @override
  String get sensorWeatherTemperature1 => 'Temperatura 1';

  @override
  String get sensorWeatherTemperature2 => 'Temperatura 2';

  @override
  String get sensorWeatherPressure => 'Presión';

  @override
  String get sensorWeatherWindDir => 'Dirección del viento';

  @override
  String get sensorWeatherWindDirMv => 'Dirección viento ADC crudo';

  @override
  String get sensorWeatherWindHrMaxSpeed =>
      'Velocidad máxima del viento (1 hora)';

  @override
  String get sensorWeatherWindHrMaxDir =>
      'Dirección máxima del viento (1 hora)';

  @override
  String get sensorWeatherWind10mMaxSpeed =>
      'Velocidad máxima del viento (10 min)';

  @override
  String get sensorWeatherWind10mMaxDir =>
      'Dirección máxima del viento (10 min)';

  @override
  String get sensorWeatherWind2mAvgSpeed =>
      'Velocidad media del viento (2 min)';

  @override
  String get sensorWeatherWind2mAvgDir => 'Dirección media del viento (2 min)';

  @override
  String get sensorWeatherRainThisHour => 'Lluvia esta hora';

  @override
  String get sensorWeatherRainPrevHour => 'Lluvia en la hora anterior';

  @override
  String get sensorDistanceDistance0 => 'Distancia 0';

  @override
  String get sensorDistanceDistance1 => 'Distancia 1';

  @override
  String get sensorDistanceDistance2 => 'Distancia 2';

  @override
  String get sensorDistanceCalibration => 'Distance Cal';

  @override
  String get sensorRandomRandom0 => 'Aleatorio 0';

  @override
  String get sensorRandomRandom1 => 'Aleatorio 1';

  @override
  String get sensorRandomRandom2 => 'Aleatorio 2';

  @override
  String get sensorRandomRandom3 => 'Aleatorio 3';

  @override
  String get sensorRandomRandom4 => 'Aleatorio 4';

  @override
  String get sensorRandomRandom5 => 'Aleatorio 5';

  @override
  String get sensorRandomRandom6 => 'Aleatorio 6';

  @override
  String get sensorRandomRandom7 => 'Aleatorio 7';

  @override
  String get sensorRandomRandom8 => 'Aleatorio 8';

  @override
  String get sensorRandomRandom9 => 'Aleatorio 9';

  @override
  String get helpSettingsIconActive => 'Help Settings Icon - active';

  @override
  String get helpSettingsIconInactive => 'Help Settings Icon - inactive';

  @override
  String get helpSettingsIcon => 'Help Settings Icon';

  @override
  String get accountSettingsIcon => 'Account Settings Icon';

  @override
  String get languageSettingsIcon => 'Language Settings Icon';

  @override
  String get legalSettingsIcon => 'Legal Settings Icon';

  @override
  String get advancedSettingsIcon => 'Advanced settings icon';

  @override
  String get stationDisconnectedIcon => 'Station Disconnected Icon';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get stationDisconnectedTitle => 'Station Disconnected';

  @override
  String get getHelpButton => 'Get Help';

  @override
  String get stationConnectedMessage => 'Station Connected';

  @override
  String get stationDisconnectedMessage => 'Station Disconnected';

  @override
  String get pressWifiButtonAgain => '1. Press the WiFi button again';

  @override
  String get turnOnStationWifi =>
      '2. Turn on the station\'s WiFi access point directly from the station settings menu';

  @override
  String get visitSupportWebsite => '3. If you\'re still having issues, visit ';

  @override
  String get unDeployStation => 'Undeploy Station';

  @override
  String get unDeployConfirmation =>
      'Are you sure you want to undeploy this station? This will clear its deployment configuration.';

  @override
  String get unDeploySuccess => 'Station has been undeployed successfully';

  @override
  String get assembleStation => 'Assemble Station';

  @override
  String get stationSetupInstructions => 'Station Setup Instructions';

  @override
  String get phModuleSetup => 'pH Module Setup';

  @override
  String get waterTempModuleSetup => 'Water Temperature Module Setup';

  @override
  String get conductivityModuleSetup => 'Conductivity Module Setup';

  @override
  String get doModuleSetup => 'Dissolved Oxygen Module Setup';

  @override
  String get distanceModuleSetup => 'Distance Module Setup';

  @override
  String get weatherModuleSetup => 'Weather Module Setup';

  @override
  String get noModuleDescription =>
      'No station has this type of module installed. Install this module on a station to calibrate it.';

  @override
  String get mapContainer =>
      'Interactive map showing station locations and user position';

  @override
  String get mapZoomInButton => 'Zoom in';

  @override
  String get mapZoomOutButton => 'Zoom out';

  @override
  String get mapCenterLocationButton => 'Center on my location';

  @override
  String get mapLocationMarker => 'Your current location';

  @override
  String get mapStationMarker => 'FieldKit station';

  @override
  String get mapGestureHint =>
      'Use two fingers to zoom, drag to pan around the map';

  @override
  String get mapLoading => 'Loading map';

  @override
  String get mapLoaded => 'Map loaded successfully';

  @override
  String get locationNotAvailable =>
      'Location not available. Please check your location permissions and try again.';

  @override
  String bytesUsed(Object bytesUsed) {
    return '${bytesUsed}MB of 512MB';
  }

  @override
  String get buttonNext => 'Next';

  @override
  String get buttonSkipThisStep => 'Skip this step';

  @override
  String get buttonSkipAssemblyInstructions => 'Skip Assembly Instructions';

  @override
  String get closeButton => 'Close';

  @override
  String get backButton => 'Back';

  @override
  String get minutes => 'Minutes';

  @override
  String get hours => 'Hours';

  @override
  String get every => 'Every';

  @override
  String get to => 'to';

  @override
  String get noValue => '--';

  @override
  String moreItems(Object count) {
    return '$count more';
  }

  @override
  String get space => ' ';

  @override
  String get lastCalibrated => 'Last Calibrated';

  @override
  String get unitMilliseconds => 'ms';

  @override
  String get unitSeconds => 'sec';

  @override
  String get unitMinutes => 'min';

  @override
  String get unitHours => 'hr';

  @override
  String get unitDays => 'days';

  @override
  String get unitMicrosiemensPerCm => 'μS/cm';

  @override
  String get unitMillisiemensPerCm => 'mS/cm';

  @override
  String get unitSiemensPerCm => 'S/cm';

  @override
  String get unitPh => 'pH';

  @override
  String get unitMillivolts => 'mV';

  @override
  String get unitVolts => 'V';

  @override
  String get unitCelsius => '°C';

  @override
  String get unitFahrenheit => '°F';

  @override
  String get unitKelvin => 'K';

  @override
  String get unitPercent => '%';

  @override
  String get unitPpm => 'ppm';

  @override
  String get unitPpb => 'ppb';

  @override
  String get unitMeters => 'm';

  @override
  String get unitCentimeters => 'cm';

  @override
  String get unitMillimeters => 'mm';

  @override
  String get unitKilometers => 'km';

  @override
  String get unitInches => 'in';

  @override
  String get unitFeet => 'ft';

  @override
  String get unitYards => 'yd';

  @override
  String get unitMiles => 'mi';

  @override
  String get unitPascals => 'Pa';

  @override
  String get unitHectopascals => 'hPa';

  @override
  String get unitMillibars => 'mbar';

  @override
  String get unitAtmospheres => 'atm';

  @override
  String get unitMetersPerSecond => 'm/s';

  @override
  String get unitKilometersPerHour => 'km/h';

  @override
  String get unitMilesPerHour => 'mph';

  @override
  String get unitDegrees => '°';

  @override
  String get unitRadians => 'rad';

  @override
  String get unitLux => 'lux';

  @override
  String get unitLumens => 'lm';

  @override
  String get unitCandela => 'cd';

  @override
  String get unitWatts => 'W';

  @override
  String get unitMilliwatts => 'mW';

  @override
  String get unitKilowatts => 'kW';

  @override
  String get unitJoules => 'J';

  @override
  String get unitCalories => 'cal';

  @override
  String get unitKilocalories => 'kcal';

  @override
  String get unitAmperes => 'A';

  @override
  String get unitMilliamperes => 'mA';

  @override
  String get unitMicroamperes => 'μA';

  @override
  String get unitOhms => 'Ω';

  @override
  String get unitKiloohms => 'kΩ';

  @override
  String get unitMegaohms => 'MΩ';

  @override
  String get unitSiemens => 'S';

  @override
  String get unitMicrosiemens => 'μS';

  @override
  String get unitMillisiemens => 'mS';

  @override
  String get unitHertz => 'Hz';

  @override
  String get unitKilohertz => 'kHz';

  @override
  String get unitMegahertz => 'MHz';

  @override
  String get unitGigahertz => 'GHz';

  @override
  String get passwordShowTooltip => 'Show password';

  @override
  String get passwordHideTooltip => 'Hide password';

  @override
  String get mapExpandTooltip => 'Expand map to full screen';

  @override
  String get valueRising => 'Value is rising';

  @override
  String get valueFalling => 'Value is falling';

  @override
  String get fieldKitLogo => 'FieldKit Logo';

  @override
  String get welcomeImage => 'Welcome illustration';

  @override
  String get accountsImage => 'FieldKit station setup illustration';

  @override
  String get distanceModuleIcon => 'Distance module icon';

  @override
  String get weatherModuleIcon => 'Weather module icon';

  @override
  String get waterModuleIcon => 'Water module icon';

  @override
  String get dataSyncIllustration => 'Data sync illustration';

  @override
  String get noStationsImage => 'No stations illustration';

  @override
  String get batteryIcon => 'Battery icon';

  @override
  String get memoryIcon => 'Memory icon';

  @override
  String get stationConnectedIcon => 'Station connected icon';

  @override
  String get configureIcon => 'Configure icon';

  @override
  String get globeIcon => 'Globe icon';

  @override
  String get eyeIcon => 'Eye icon';

  @override
  String get eyeSlashIcon => 'Eye slash icon';

  @override
  String get checkmarkIcon => 'Checkmark icon';

  @override
  String get alertIcon => 'Alert icon';

  @override
  String get uploadIcon => 'Upload Icon';

  @override
  String get downloadIcon => 'Download Icon';

  @override
  String get uploadingIcon => 'Uploading icon';

  @override
  String get downloadingIcon => 'Downloading icon';

  @override
  String get syncIcon => 'Sync icon';

  @override
  String get warningIcon => 'Warning icon';

  @override
  String get infoIcon => 'Information icon';

  @override
  String get warningErrorIcon => 'Warning error icon';

  @override
  String get greenCheckmarkIcon => 'Green checkmark icon';

  @override
  String get noticeIcon => 'Notice icon';

  @override
  String get confirmIcon => 'Confirm icon';

  @override
  String get questionMarkIcon => 'Question mark icon';

  @override
  String errorNavigatingToPage(String message) {
    return 'Error navigating to page: $message';
  }

  @override
  String errorSearching(String message) {
    return 'Error searching: $message';
  }

  @override
  String get errorStartingApp => 'Error initializing app.';

  @override
  String get loadingConfiguration => 'Configuration';

  @override
  String get loadingEnvironment => 'Environment';

  @override
  String get loadingLocale => 'Locale';

  @override
  String get syncUploading => 'Uploading...';

  @override
  String get syncDownloading => 'Downloading...';

  @override
  String get syncDisconnected => 'Disconnected';

  @override
  String get syncNoUpload => 'No Upload Available';

  @override
  String get syncNoDownload => 'No Download Available';

  @override
  String get unknownError => 'Unknown Error';

  @override
  String get firmwareCheck => 'Buscar nuevas versiones de firmware';

  @override
  String get accountEditTitle => 'Editar cuenta';

  @override
  String get accountRegistrationFailed =>
      'Se ha producido un error al registrar tu cuenta. Por favor, comprueba tu correo electrónico y contraseña.';

  @override
  String get accountFormFail => 'Email o contraseña inválidos.';

  @override
  String get errorInitializingApp => 'Error initializing app.';

  @override
  String get stationsTabIcon => 'Stations tab icon';

  @override
  String get dataSyncTabIcon => 'Data sync tab icon';

  @override
  String get settingsTabIcon => 'Settings tab icon';

  @override
  String get dataSyncImage => 'Data sync illustration';
}
