// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get fieldKit => 'FieldKit';

  @override
  String get welcomeTitle => 'Welcome!';

  @override
  String get welcomeMessage =>
      'Our mobile app makes it easy to set up and deploy your FieldKit station.';

  @override
  String get welcomeButton => 'Get Started';

  @override
  String get skipInstructions => 'Skip Instructions';

  @override
  String get stationsTab => 'Stations';

  @override
  String get dataSyncTab => 'Data Sync';

  @override
  String get settingsTab => 'Settings';

  @override
  String get helpTab => 'Help';

  @override
  String get dataSyncTitle => 'Data Sync';

  @override
  String get alertTitle => 'Important';

  @override
  String get login => 'Login';

  @override
  String get dataLoginMessage => 'To upload data you need to login:';

  @override
  String get modulesTitle => 'Modules';

  @override
  String get addModulesButton => 'Add Modules';

  @override
  String get noModulesMessage =>
      'Your station needs modules in order to complete setup, deploy, and capture data.';

  @override
  String get noModulesTitle => 'No Modules Attached';

  @override
  String get connectStation => 'Add a Station';

  @override
  String get noStationsDescription =>
      'You have no stations. Add a station to start collecting data.';

  @override
  String get noStationsDescription2 =>
      'You have no stations. Add a station in order to calibrate modules.';

  @override
  String get noStationsWhatIsStation => 'What is a FieldKit Station?';

  @override
  String get locationDenied => 'Location permission denied';

  @override
  String get lastReadingLabel => ' (Last Reading)';

  @override
  String get daysHoursMinutes => 'days  hrs  mins';

  @override
  String get download => 'Download';

  @override
  String get upload => 'Upload';

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
  String get myStationsTitle => 'My Stations';

  @override
  String get deployedAt => 'Deployed';

  @override
  String get readyToDeploy => 'Ready to Deploy';

  @override
  String get readyToCalibrate => 'Ready to Calibrate';

  @override
  String get calibratingBusy => 'Calibrating...';

  @override
  String get busyWorking => 'Busy...';

  @override
  String get busyUploading => 'Uploading...';

  @override
  String get busyDownloading => 'Downloading...';

  @override
  String get busyUpgrading => 'Upgrading...';

  @override
  String get contacting => 'Contacting...';

  @override
  String get unknownStationTitle => 'Unknown Station';

  @override
  String get backButtonTitle => 'Back';

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
  String get deployButton => 'Deploy';

  @override
  String get deployTitle => 'Deploy Station';

  @override
  String get deployLocation => 'Name your location';

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
  String get calibrationStartTimer => 'Start Timer';

  @override
  String get calibrationTitle => 'Calibration';

  @override
  String get calibrateButton => 'Calibrate';

  @override
  String get calibrationDelete => 'Delete';

  @override
  String get calibrationBack => 'Back';

  @override
  String get calibrationKeepButton => 'Keep';

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
  String get factory => 'Factory';

  @override
  String get uncalibrated => 'Uncalibrated';

  @override
  String get calibrated => 'Calibrated';

  @override
  String get voltage => 'Voltage';

  @override
  String get standardTitle => 'Standard';

  @override
  String get waitingOnTimer => 'Waiting on Timer';

  @override
  String get waitingOnReading => 'Waiting for Fresh Reading';

  @override
  String get waitingOnForm => 'Values Required';

  @override
  String standardValue(Object uom, Object value) {
    return '$value Standard Value ($uom)';
  }

  @override
  String standardValue2(Object uom) {
    return ' Standard Value ($uom)';
  }

  @override
  String get sensorValue => 'Sensor Value:';

  @override
  String get oopsBugTitle => 'Oops, bug?';

  @override
  String get standard => 'Standard';

  @override
  String get countdownInstructions =>
      'As you wait for the sensor value to stabilize, enter the standard value.';

  @override
  String get calibrationMessage =>
      'Recording these values together allows us to later calibrate the sensor.';

  @override
  String get standardFieldLabel => 'Standard';

  @override
  String get backAreYouSure => 'Are you sure?';

  @override
  String get backWarning =>
      'Navigating away will require starting this calibration over.';

  @override
  String get settingsTitle => 'Settings';

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
  String get settingsModules => 'Modules';

  @override
  String get settingsWifi => 'WiFi';

  @override
  String get settingsLora => 'LoRa';

  @override
  String get settingsAutomaticUpload => 'Automatic Upload Settings';

  @override
  String get forgetStation => 'Forget Station';

  @override
  String get settingsEvents => 'Events';

  @override
  String get settingsLoraEdit => 'Edit';

  @override
  String get settingsLoraVerify => 'Verify';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get endDeployment => 'End Deployment';

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
  String get eventUnknown => 'Unknown Event';

  @override
  String get eventRestart => 'Restart Event';

  @override
  String get eventLora => 'LoRa Event';

  @override
  String get eventTime => 'Time';

  @override
  String get eventCode => 'Code';

  @override
  String get eventReason => 'Reason';

  @override
  String get noEvents => 'No Events';

  @override
  String get networksTitle => 'WiFi Networks';

  @override
  String get networkAddButton => 'Add Network';

  @override
  String get networkEditTitle => 'WiFi Network';

  @override
  String get networkSaveButton => 'Save';

  @override
  String get networkAutomaticUploadEnable => 'Enable';

  @override
  String get networkAutomaticUploadDisable => 'Disable';

  @override
  String get networkRemoveButton => 'Remove';

  @override
  String get networkNoMoreSlots =>
      'Unfortunately, there are only two WiFi network slots available.';

  @override
  String get wifiSsid => 'SSID';

  @override
  String get wifiPassword => 'Password';

  @override
  String get confirmRemoveNetwork => 'Remove Network';

  @override
  String get loraBand => 'Band';

  @override
  String get loraAppKey => 'App Key';

  @override
  String get loraJoinEui => 'Join EUI';

  @override
  String get loraDeviceEui => 'Device EUI';

  @override
  String get loraDeviceAddress => 'Device Address';

  @override
  String get loraNetworkKey => 'Network Key';

  @override
  String get loraSessionKey => 'Session Key';

  @override
  String get loraNoModule => 'No LoRa module detected.';

  @override
  String get loraConfigurationTitle => 'LoRa Configuration';

  @override
  String get hexStringValidationFailed => 'Expected a valid hex string.';

  @override
  String get firmwareTitle => 'Firmware';

  @override
  String get firmwareUpgrade => 'Upgrade';

  @override
  String get firmwareSwitch => 'Switch';

  @override
  String get firmwareStarting => 'Starting...';

  @override
  String get firmwareUploading => 'Uploading...';

  @override
  String get firmwareRestarting => 'Restarting...';

  @override
  String get firmwareCompleted => 'Completed';

  @override
  String get firmwareFailed =>
      'An unexpected error occurred. Please contact support.';

  @override
  String get firmwareConnected => 'Connected';

  @override
  String get firmwareNotConnected => 'Not Connected';

  @override
  String firmwareVersion(Object firmwareVersion) {
    return 'Version: $firmwareVersion';
  }

  @override
  String get firmwareUpdated => 'Firmware is Up to Date';

  @override
  String get firmwareNotUpdated => 'Firmware is Not Up to Date';

  @override
  String get firmwareUpdate => 'Update Firmware';

  @override
  String firmwareReleased(String firmwareReleaseDate) {
    return 'Released: $firmwareReleaseDate';
  }

  @override
  String get firmwareTip =>
      'During the upgrade your station may disconnect while restarting. If so, be sure to reconnect to your station.';

  @override
  String get settingsAccounts => 'Accounts';

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get accountsAddButton => 'Add an Account';

  @override
  String get accountsNoneCreatedTitle =>
      'Looks like there are no accounts created yet';

  @override
  String get accountsNoneCreatedMessage =>
      'Accounts are useful for updating your station information on the online portal and occasionally accessing user-specific firmware. Are you connected to the internet? Once you are, let\'s set up an account!';

  @override
  String get confirmRemoveAccountTitle => 'Remove Account';

  @override
  String get accountAddTitle => 'Add Account';

  @override
  String get noInternetConnection => 'No Internet Connection';

  @override
  String get accountName => 'Name';

  @override
  String get accountEmail => 'Email';

  @override
  String get accountPassword => 'Password';

  @override
  String get accountConfirmPassword => 'Confirm Password';

  @override
  String get accountConfirmPasswordMatch => 'Passwords must match.';

  @override
  String get accountSaveButton => 'Login';

  @override
  String get accountRegisterButton => 'Register';

  @override
  String get accountRemoveButton => 'Remove';

  @override
  String get accountRepairButton => 'Login';

  @override
  String get accountRegisterLabel => 'Create an account';

  @override
  String get accountDefault => 'This is your default account.';

  @override
  String get accountInvalid => 'Something is wrong with this account.';

  @override
  String get accountConnectivity =>
      'There was an issue connecting with this account. If the issue was network related this will correct itself.';

  @override
  String get accountCreated =>
      'Registration successful! Please check your email for verification instructions prior to logging in.';

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
    return 'Bay #$bay';
  }

  @override
  String get batteryLife => 'Battery Life';

  @override
  String get memoryUsage => 'Memory Used';

  @override
  String get confirmClearCalibrationTitle => 'Clear Calibration';

  @override
  String get confirmDelete => 'Are you sure?';

  @override
  String get confirmYes => 'Yes';

  @override
  String get confirmCancel => 'Cancel';

  @override
  String get helpTitle => 'Help';

  @override
  String get helpCheckList => 'Pre-deployment Checklist';

  @override
  String get offlineProductGuide => 'Offline Product Guide';

  @override
  String get search => 'Search';

  @override
  String get enterSearchTerm => 'Enter Search Term';

  @override
  String get cancel => 'Cancel';

  @override
  String get appVersion => 'App Version';

  @override
  String get errorLoadingVersion => 'Error Loading App Version';

  @override
  String get helpUploadLogs => 'Send Diagnostics';

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
  String get developerBuild => 'Developer Build';

  @override
  String get logsUploaded => 'Logs Uploaded';

  @override
  String get legalTitle => 'Legal';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get licenses => 'Licenses';

  @override
  String get modulesWaterTemp => 'Water Temperature Module';

  @override
  String get modulesWaterPh => 'pH Module';

  @override
  String get modulesWaterOrp => 'ORP Module';

  @override
  String get modulesWaterDo => 'Dissolved Oxygen Module';

  @override
  String get modulesWaterEc => 'Conductivity Module';

  @override
  String get modulesWaterDepth => 'Water Depth Module';

  @override
  String get modulesWeather => 'Weather Module';

  @override
  String get modulesDiagnostics => 'Diagnostics Module';

  @override
  String get modulesRandom => 'Random Module';

  @override
  String get modulesDistance => 'Distance Module';

  @override
  String get modulesUnknown => 'Unknown Module';

  @override
  String get sensorWaterTemperature => 'Water Temperature';

  @override
  String get sensorWaterPh => 'pH';

  @override
  String get sensorWaterEc => 'Conductivity';

  @override
  String get sensorWaterDo => 'Dissolved Oxygen';

  @override
  String get sensorWaterDoPressure => 'DO Pressure';

  @override
  String get sensorWaterDoTemperature => 'Air Temperature';

  @override
  String get sensorWaterOrp => 'ORP';

  @override
  String get sensorWaterDepthPressure => 'Water Depth (Pressure)';

  @override
  String get sensorWaterDepthTemperature => 'Water Temperature';

  @override
  String get sensorDiagnosticsTemperature => 'Internal Temperature';

  @override
  String get sensorDiagnosticsUptime => 'Uptime';

  @override
  String get sensorDiagnosticsMemory => 'Memory';

  @override
  String get sensorDiagnosticsFreeMemory => 'Free Memory';

  @override
  String get sensorDiagnosticsBatteryCharge => 'Battery';

  @override
  String get sensorDiagnosticsBatteryVoltage => 'Battery';

  @override
  String get sensorDiagnosticsBatteryVBus => 'Battery (VBus)';

  @override
  String get sensorDiagnosticsBatteryVs => 'Battery (Vs)';

  @override
  String get sensorDiagnosticsBatteryMa => 'Battery (mA)';

  @override
  String get sensorDiagnosticsBatteryPower => 'Battery (Power)';

  @override
  String get sensorDiagnosticsSolarVBus => 'Solar (VBus)';

  @override
  String get sensorDiagnosticsSolarVs => 'Solar (Vs)';

  @override
  String get sensorDiagnosticsSolarMa => 'Solar (mA)';

  @override
  String get sensorDiagnosticsSolarPower => 'Solar (Power)';

  @override
  String get sensorWeatherRain => 'Rain';

  @override
  String get sensorWeatherWindSpeed => 'Wind Speed';

  @override
  String get sensorWeatherWindDirection => 'Wind Direction';

  @override
  String get sensorWeatherHumidity => 'Humidity';

  @override
  String get sensorWeatherTemperature1 => 'Temperature 1';

  @override
  String get sensorWeatherTemperature2 => 'Temperature 2';

  @override
  String get sensorWeatherPressure => 'Pressure';

  @override
  String get sensorWeatherWindDir => 'Wind Direction';

  @override
  String get sensorWeatherWindDirMv => 'Wind Direction Raw ADC';

  @override
  String get sensorWeatherWindHrMaxSpeed => 'Wind Max Speed (1 hour)';

  @override
  String get sensorWeatherWindHrMaxDir => 'Wind Max Direction (1 hour)';

  @override
  String get sensorWeatherWind10mMaxSpeed => 'Wind Max Speed (10 min)';

  @override
  String get sensorWeatherWind10mMaxDir => 'Wind Max Direction (10 min)';

  @override
  String get sensorWeatherWind2mAvgSpeed => 'Wind Average Speed (2 min)';

  @override
  String get sensorWeatherWind2mAvgDir => 'Wind Average Direction (2 min)';

  @override
  String get sensorWeatherRainThisHour => 'Rain This Hour';

  @override
  String get sensorWeatherRainPrevHour => 'Rain Previous Hour';

  @override
  String get sensorDistanceDistance0 => 'Distance 0';

  @override
  String get sensorDistanceDistance1 => 'Distance 1';

  @override
  String get sensorDistanceDistance2 => 'Distance 2';

  @override
  String get sensorDistanceCalibration => 'Distance Cal';

  @override
  String get sensorRandomRandom0 => 'Random 0';

  @override
  String get sensorRandomRandom1 => 'Random 1';

  @override
  String get sensorRandomRandom2 => 'Random 2';

  @override
  String get sensorRandomRandom3 => 'Random 3';

  @override
  String get sensorRandomRandom4 => 'Random 4';

  @override
  String get sensorRandomRandom5 => 'Random 5';

  @override
  String get sensorRandomRandom6 => 'Random 6';

  @override
  String get sensorRandomRandom7 => 'Random 7';

  @override
  String get sensorRandomRandom8 => 'Random 8';

  @override
  String get sensorRandomRandom9 => 'Random 9';

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
  String get firmwareCheck => 'Check';

  @override
  String get accountEditTitle => 'Edit Account';

  @override
  String get accountRegistrationFailed => 'Registration failed';

  @override
  String get accountFormFail => 'Form validation failed';

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
