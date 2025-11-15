import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @fieldKit.
  ///
  /// In en, this message translates to:
  /// **'FieldKit'**
  String get fieldKit;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcomeTitle;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Our mobile app makes it easy to set up and deploy your FieldKit station.'**
  String get welcomeMessage;

  /// No description provided for @welcomeButton.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get welcomeButton;

  /// No description provided for @skipInstructions.
  ///
  /// In en, this message translates to:
  /// **'Skip Instructions'**
  String get skipInstructions;

  /// No description provided for @stationsTab.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get stationsTab;

  /// No description provided for @dataSyncTab.
  ///
  /// In en, this message translates to:
  /// **'Data Sync'**
  String get dataSyncTab;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @helpTab.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpTab;

  /// No description provided for @dataSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Sync'**
  String get dataSyncTitle;

  /// No description provided for @alertTitle.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get alertTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @dataLoginMessage.
  ///
  /// In en, this message translates to:
  /// **'To upload data you need to login:'**
  String get dataLoginMessage;

  /// No description provided for @modulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get modulesTitle;

  /// No description provided for @addModulesButton.
  ///
  /// In en, this message translates to:
  /// **'Add Modules'**
  String get addModulesButton;

  /// No description provided for @noModulesMessage.
  ///
  /// In en, this message translates to:
  /// **'Your station needs modules in order to complete setup, deploy, and capture data.'**
  String get noModulesMessage;

  /// No description provided for @noModulesTitle.
  ///
  /// In en, this message translates to:
  /// **'No Modules Attached'**
  String get noModulesTitle;

  /// No description provided for @connectStation.
  ///
  /// In en, this message translates to:
  /// **'Add a Station'**
  String get connectStation;

  /// No description provided for @noStationsDescription.
  ///
  /// In en, this message translates to:
  /// **'You have no stations. Add a station to start collecting data.'**
  String get noStationsDescription;

  /// No description provided for @noStationsDescription2.
  ///
  /// In en, this message translates to:
  /// **'You have no stations. Add a station in order to calibrate modules.'**
  String get noStationsDescription2;

  /// No description provided for @noStationsWhatIsStation.
  ///
  /// In en, this message translates to:
  /// **'What is a FieldKit Station?'**
  String get noStationsWhatIsStation;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get locationDenied;

  /// No description provided for @lastReadingLabel.
  ///
  /// In en, this message translates to:
  /// **' (Last Reading)'**
  String get lastReadingLabel;

  /// No description provided for @daysHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'days  hrs  mins'**
  String get daysHoursMinutes;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @readingsUploadable.
  ///
  /// In en, this message translates to:
  /// **'{readings, plural, zero{0 Uploads}  one{1 Upload} other{{readings} Uploads}}'**
  String readingsUploadable(num readings);

  /// No description provided for @readingsDownloadable.
  ///
  /// In en, this message translates to:
  /// **'{readings, plural, zero{0 Downloads}  one{1 Downloads} other{{readings} Downloads}}'**
  String readingsDownloadable(num readings);

  /// No description provided for @downloadIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Only {readings} of {total} downloaded.'**
  String downloadIncomplete(num readings, num total);

  /// No description provided for @downloadProgress.
  ///
  /// In en, this message translates to:
  /// **'{readings} Downloaded...'**
  String downloadProgress(num readings, num total);

  /// No description provided for @uploadProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploadProgress;

  /// No description provided for @readingsUploaded.
  ///
  /// In en, this message translates to:
  /// **'{readings, plural, zero{0 Readings Uploaded}  one{1 Reading Uploaded} other{{readings} Readings Uploaded}}'**
  String readingsUploaded(num readings);

  /// No description provided for @readingsDownloaded.
  ///
  /// In en, this message translates to:
  /// **'{readings, plural, zero{0 Readings Downloaded}  one{1 Reading Downloaded} other{{readings} Readings Downloaded}}'**
  String readingsDownloaded(num readings);

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get uploading;

  /// No description provided for @readytoDownload.
  ///
  /// In en, this message translates to:
  /// **'Ready to download'**
  String get readytoDownload;

  /// No description provided for @readytoUpload.
  ///
  /// In en, this message translates to:
  /// **'Ready to upload'**
  String get readytoUpload;

  /// No description provided for @syncDismissOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get syncDismissOk;

  /// No description provided for @syncDownloadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Download successful!'**
  String get syncDownloadSuccess;

  /// No description provided for @syncUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Upload successful!'**
  String get syncUploadSuccess;

  /// No description provided for @syncDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Error: Download Failed. \nWait a few seconds and try again.'**
  String get syncDownloadFailed;

  /// No description provided for @syncUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Error: Upload Failed. \nConnect to the internet and try again.'**
  String get syncUploadFailed;

  /// No description provided for @syncNoAuthentication.
  ///
  /// In en, this message translates to:
  /// **'You aren\'t logged in.'**
  String get syncNoAuthentication;

  /// No description provided for @syncNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get syncNoInternet;

  /// No description provided for @quickTip.
  ///
  /// In en, this message translates to:
  /// **'Quick Tip'**
  String get quickTip;

  /// No description provided for @stationConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get stationConnected;

  /// No description provided for @lastConnected.
  ///
  /// In en, this message translates to:
  /// **'Last Connected'**
  String get lastConnected;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get notConnected;

  /// No description provided for @lastConnectedSince.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String lastConnectedSince(Object date);

  /// No description provided for @stationDeployed.
  ///
  /// In en, this message translates to:
  /// **'Station Deployed'**
  String get stationDeployed;

  /// No description provided for @noStationsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No stations available'**
  String get noStationsAvailable;

  /// No description provided for @connectToStation.
  ///
  /// In en, this message translates to:
  /// **'Please connect to a station to continue'**
  String get connectToStation;

  /// No description provided for @myStationsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Stations'**
  String get myStationsTitle;

  /// No description provided for @deployedAt.
  ///
  /// In en, this message translates to:
  /// **'Deployed'**
  String get deployedAt;

  /// No description provided for @readyToDeploy.
  ///
  /// In en, this message translates to:
  /// **'Ready to Deploy'**
  String get readyToDeploy;

  /// No description provided for @readyToCalibrate.
  ///
  /// In en, this message translates to:
  /// **'Ready to Calibrate'**
  String get readyToCalibrate;

  /// No description provided for @calibratingBusy.
  ///
  /// In en, this message translates to:
  /// **'Calibrating...'**
  String get calibratingBusy;

  /// No description provided for @busyWorking.
  ///
  /// In en, this message translates to:
  /// **'Busy...'**
  String get busyWorking;

  /// No description provided for @busyUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get busyUploading;

  /// No description provided for @busyDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get busyDownloading;

  /// No description provided for @busyUpgrading.
  ///
  /// In en, this message translates to:
  /// **'Upgrading...'**
  String get busyUpgrading;

  /// No description provided for @contacting.
  ///
  /// In en, this message translates to:
  /// **'Contacting...'**
  String get contacting;

  /// No description provided for @unknownStationTitle.
  ///
  /// In en, this message translates to:
  /// **'Unknown Station'**
  String get unknownStationTitle;

  /// No description provided for @backButtonTitle.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backButtonTitle;

  /// No description provided for @importantNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Important Note: '**
  String get importantNoteTitle;

  /// No description provided for @updateRequiredDataPage.
  ///
  /// In en, this message translates to:
  /// **'An update is required to sync data from this station.'**
  String get updateRequiredDataPage;

  /// No description provided for @connectStationAlert.
  ///
  /// In en, this message translates to:
  /// **'To upload data, connect to the internet.'**
  String get connectStationAlert;

  /// No description provided for @loginStationAlert.
  ///
  /// In en, this message translates to:
  /// **'To upload data,'**
  String get loginStationAlert;

  /// No description provided for @loginAndConnectStationAlert.
  ///
  /// In en, this message translates to:
  /// **'To upload data, connect to the internet and'**
  String get loginAndConnectStationAlert;

  /// No description provided for @loginLink.
  ///
  /// In en, this message translates to:
  /// **'login'**
  String get loginLink;

  /// No description provided for @deployButton.
  ///
  /// In en, this message translates to:
  /// **'Deploy'**
  String get deployButton;

  /// No description provided for @deployTitle.
  ///
  /// In en, this message translates to:
  /// **'Deploy Station'**
  String get deployTitle;

  /// No description provided for @deployLocation.
  ///
  /// In en, this message translates to:
  /// **'Name your location'**
  String get deployLocation;

  /// No description provided for @manageFirmwareButton.
  ///
  /// In en, this message translates to:
  /// **'Manage Firmware'**
  String get manageFirmwareButton;

  /// No description provided for @firmwareContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get firmwareContinue;

  /// No description provided for @firmwareCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get firmwareCancel;

  /// No description provided for @firmwareReconnectTimeout.
  ///
  /// In en, this message translates to:
  /// **'Reconnect Timeout'**
  String get firmwareReconnectTimeout;

  /// No description provided for @firmwareSdCardError.
  ///
  /// In en, this message translates to:
  /// **'SD Card Error'**
  String get firmwareSdCardError;

  /// No description provided for @firmwareDismiss.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get firmwareDismiss;

  /// No description provided for @firmwarePrepareTitle.
  ///
  /// In en, this message translates to:
  /// **'Prepare For Update'**
  String get firmwarePrepareTitle;

  /// No description provided for @firmwarePrepareTime.
  ///
  /// In en, this message translates to:
  /// **'This update may take several minutes.'**
  String get firmwarePrepareTime;

  /// No description provided for @firmwarePrepareSd.
  ///
  /// In en, this message translates to:
  /// **'You will need an SD card in your station to complete the update.'**
  String get firmwarePrepareSd;

  /// No description provided for @firmwarePreparePower.
  ///
  /// In en, this message translates to:
  /// **'Keep your station plugged in and close to your device or smart phone.'**
  String get firmwarePreparePower;

  /// No description provided for @firmwarePrepareConnection.
  ///
  /// In en, this message translates to:
  /// **'Your station will restart and you might have to reconnect to the station.'**
  String get firmwarePrepareConnection;

  /// No description provided for @calibrationStartTimer.
  ///
  /// In en, this message translates to:
  /// **'Start Timer'**
  String get calibrationStartTimer;

  /// No description provided for @calibrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Calibration'**
  String get calibrationTitle;

  /// No description provided for @calibrateButton.
  ///
  /// In en, this message translates to:
  /// **'Calibrate'**
  String get calibrateButton;

  /// No description provided for @calibrationDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get calibrationDelete;

  /// No description provided for @calibrationBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get calibrationBack;

  /// No description provided for @calibrationKeepButton.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get calibrationKeepButton;

  /// No description provided for @calibrationSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Calibrations'**
  String get calibrationSaveButton;

  /// No description provided for @calibrationPoint.
  ///
  /// In en, this message translates to:
  /// **'Calibration Point {step}'**
  String calibrationPoint(int step);

  /// No description provided for @countdownInstructions2.
  ///
  /// In en, this message translates to:
  /// **'Tap the Calibrate button to record the sensor value and the standard value.'**
  String get countdownInstructions2;

  /// No description provided for @factory.
  ///
  /// In en, this message translates to:
  /// **'Factory'**
  String get factory;

  /// No description provided for @uncalibrated.
  ///
  /// In en, this message translates to:
  /// **'Uncalibrated'**
  String get uncalibrated;

  /// No description provided for @calibrated.
  ///
  /// In en, this message translates to:
  /// **'Calibrated'**
  String get calibrated;

  /// No description provided for @voltage.
  ///
  /// In en, this message translates to:
  /// **'Voltage'**
  String get voltage;

  /// No description provided for @standardTitle.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standardTitle;

  /// No description provided for @waitingOnTimer.
  ///
  /// In en, this message translates to:
  /// **'Waiting on Timer'**
  String get waitingOnTimer;

  /// No description provided for @waitingOnReading.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Fresh Reading'**
  String get waitingOnReading;

  /// No description provided for @waitingOnForm.
  ///
  /// In en, this message translates to:
  /// **'Values Required'**
  String get waitingOnForm;

  /// No description provided for @standardValue.
  ///
  /// In en, this message translates to:
  /// **'{value} Standard Value ({uom})'**
  String standardValue(Object uom, Object value);

  /// No description provided for @standardValue2.
  ///
  /// In en, this message translates to:
  /// **' Standard Value ({uom})'**
  String standardValue2(Object uom);

  /// No description provided for @sensorValue.
  ///
  /// In en, this message translates to:
  /// **'Sensor Value:'**
  String get sensorValue;

  /// No description provided for @oopsBugTitle.
  ///
  /// In en, this message translates to:
  /// **'Oops, bug?'**
  String get oopsBugTitle;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @countdownInstructions.
  ///
  /// In en, this message translates to:
  /// **'As you wait for the sensor value to stabilize, enter the standard value.'**
  String get countdownInstructions;

  /// No description provided for @calibrationMessage.
  ///
  /// In en, this message translates to:
  /// **'Recording these values together allows us to later calibrate the sensor.'**
  String get calibrationMessage;

  /// No description provided for @standardFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standardFieldLabel;

  /// No description provided for @backAreYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get backAreYouSure;

  /// No description provided for @backWarning.
  ///
  /// In en, this message translates to:
  /// **'Navigating away will require starting this calibration over.'**
  String get backWarning;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @readingsSchedule.
  ///
  /// In en, this message translates to:
  /// **'Readings Schedule'**
  String get readingsSchedule;

  /// No description provided for @scheduleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Schedule Updated'**
  String get scheduleUpdated;

  /// No description provided for @settingsAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get settingsAdvanced;

  /// No description provided for @httpSync.
  ///
  /// In en, this message translates to:
  /// **'HTTP Sync'**
  String get httpSync;

  /// No description provided for @httpSyncWarning.
  ///
  /// In en, this message translates to:
  /// **'HTTP Sync Warning'**
  String get httpSyncWarning;

  /// No description provided for @tailStationLogs.
  ///
  /// In en, this message translates to:
  /// **'Tail Station Logs'**
  String get tailStationLogs;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Station Name'**
  String get settingsNameHint;

  /// No description provided for @nameConfigSuccess.
  ///
  /// In en, this message translates to:
  /// **'Station Name Updated.'**
  String get nameConfigSuccess;

  /// No description provided for @errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorMessage(String message);

  /// No description provided for @settingsFirmware.
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get settingsFirmware;

  /// No description provided for @settingsModules.
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get settingsModules;

  /// No description provided for @settingsWifi.
  ///
  /// In en, this message translates to:
  /// **'WiFi'**
  String get settingsWifi;

  /// No description provided for @settingsLora.
  ///
  /// In en, this message translates to:
  /// **'LoRa'**
  String get settingsLora;

  /// No description provided for @settingsAutomaticUpload.
  ///
  /// In en, this message translates to:
  /// **'Automatic Upload Settings'**
  String get settingsAutomaticUpload;

  /// No description provided for @forgetStation.
  ///
  /// In en, this message translates to:
  /// **'Forget Station'**
  String get forgetStation;

  /// No description provided for @settingsEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get settingsEvents;

  /// No description provided for @settingsLoraEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get settingsLoraEdit;

  /// No description provided for @settingsLoraVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get settingsLoraVerify;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @endDeployment.
  ///
  /// In en, this message translates to:
  /// **'End Deployment'**
  String get endDeployment;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @nameErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'Name can only contain letters, numbers, underscores, and spaces.'**
  String get nameErrorDescription;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get settingsExport;

  /// No description provided for @exportStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get exportStart;

  /// No description provided for @exportStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start Over'**
  String get exportStartOver;

  /// No description provided for @exportShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get exportShare;

  /// No description provided for @exportCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get exportCompleted;

  /// No description provided for @exportShareUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Sharing not supported on this platform.'**
  String get exportShareUnsupported;

  /// No description provided for @exportNoData.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get exportNoData;

  /// No description provided for @exportPossible.
  ///
  /// In en, this message translates to:
  /// **'{readings} available to export.'**
  String exportPossible(num readings);

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @eventUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown Event'**
  String get eventUnknown;

  /// No description provided for @eventRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart Event'**
  String get eventRestart;

  /// No description provided for @eventLora.
  ///
  /// In en, this message translates to:
  /// **'LoRa Event'**
  String get eventLora;

  /// No description provided for @eventTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get eventTime;

  /// No description provided for @eventCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get eventCode;

  /// No description provided for @eventReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get eventReason;

  /// No description provided for @noEvents.
  ///
  /// In en, this message translates to:
  /// **'No Events'**
  String get noEvents;

  /// No description provided for @networksTitle.
  ///
  /// In en, this message translates to:
  /// **'WiFi Networks'**
  String get networksTitle;

  /// No description provided for @networkAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Network'**
  String get networkAddButton;

  /// No description provided for @networkEditTitle.
  ///
  /// In en, this message translates to:
  /// **'WiFi Network'**
  String get networkEditTitle;

  /// No description provided for @networkSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get networkSaveButton;

  /// No description provided for @networkAutomaticUploadEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get networkAutomaticUploadEnable;

  /// No description provided for @networkAutomaticUploadDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get networkAutomaticUploadDisable;

  /// No description provided for @networkRemoveButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get networkRemoveButton;

  /// No description provided for @networkNoMoreSlots.
  ///
  /// In en, this message translates to:
  /// **'Unfortunately, there are only two WiFi network slots available.'**
  String get networkNoMoreSlots;

  /// No description provided for @wifiSsid.
  ///
  /// In en, this message translates to:
  /// **'SSID'**
  String get wifiSsid;

  /// No description provided for @wifiPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get wifiPassword;

  /// No description provided for @confirmRemoveNetwork.
  ///
  /// In en, this message translates to:
  /// **'Remove Network'**
  String get confirmRemoveNetwork;

  /// No description provided for @loraBand.
  ///
  /// In en, this message translates to:
  /// **'Band'**
  String get loraBand;

  /// No description provided for @loraAppKey.
  ///
  /// In en, this message translates to:
  /// **'App Key'**
  String get loraAppKey;

  /// No description provided for @loraJoinEui.
  ///
  /// In en, this message translates to:
  /// **'Join EUI'**
  String get loraJoinEui;

  /// No description provided for @loraDeviceEui.
  ///
  /// In en, this message translates to:
  /// **'Device EUI'**
  String get loraDeviceEui;

  /// No description provided for @loraDeviceAddress.
  ///
  /// In en, this message translates to:
  /// **'Device Address'**
  String get loraDeviceAddress;

  /// No description provided for @loraNetworkKey.
  ///
  /// In en, this message translates to:
  /// **'Network Key'**
  String get loraNetworkKey;

  /// No description provided for @loraSessionKey.
  ///
  /// In en, this message translates to:
  /// **'Session Key'**
  String get loraSessionKey;

  /// No description provided for @loraNoModule.
  ///
  /// In en, this message translates to:
  /// **'No LoRa module detected.'**
  String get loraNoModule;

  /// No description provided for @loraConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'LoRa Configuration'**
  String get loraConfigurationTitle;

  /// No description provided for @hexStringValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Expected a valid hex string.'**
  String get hexStringValidationFailed;

  /// No description provided for @firmwareTitle.
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get firmwareTitle;

  /// No description provided for @firmwareUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get firmwareUpgrade;

  /// No description provided for @firmwareSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get firmwareSwitch;

  /// No description provided for @firmwareStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get firmwareStarting;

  /// No description provided for @firmwareUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get firmwareUploading;

  /// No description provided for @firmwareRestarting.
  ///
  /// In en, this message translates to:
  /// **'Restarting...'**
  String get firmwareRestarting;

  /// No description provided for @firmwareCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get firmwareCompleted;

  /// No description provided for @firmwareFailed.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please contact support.'**
  String get firmwareFailed;

  /// No description provided for @firmwareConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get firmwareConnected;

  /// No description provided for @firmwareNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get firmwareNotConnected;

  /// No description provided for @firmwareVersion.
  ///
  /// In en, this message translates to:
  /// **'Version: {firmwareVersion}'**
  String firmwareVersion(Object firmwareVersion);

  /// No description provided for @firmwareUpdated.
  ///
  /// In en, this message translates to:
  /// **'Firmware is Up to Date'**
  String get firmwareUpdated;

  /// No description provided for @firmwareNotUpdated.
  ///
  /// In en, this message translates to:
  /// **'Firmware is Not Up to Date'**
  String get firmwareNotUpdated;

  /// No description provided for @firmwareUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update Firmware'**
  String get firmwareUpdate;

  /// No description provided for @firmwareReleased.
  ///
  /// In en, this message translates to:
  /// **'Released: {firmwareReleaseDate}'**
  String firmwareReleased(String firmwareReleaseDate);

  /// No description provided for @firmwareTip.
  ///
  /// In en, this message translates to:
  /// **'During the upgrade your station may disconnect while restarting. If so, be sure to reconnect to your station.'**
  String get firmwareTip;

  /// No description provided for @settingsAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get settingsAccounts;

  /// No description provided for @accountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsTitle;

  /// No description provided for @accountsAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add an Account'**
  String get accountsAddButton;

  /// No description provided for @accountsNoneCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Looks like there are no accounts created yet'**
  String get accountsNoneCreatedTitle;

  /// No description provided for @accountsNoneCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Accounts are useful for updating your station information on the online portal and occasionally accessing user-specific firmware. Are you connected to the internet? Once you are, let\'s set up an account!'**
  String get accountsNoneCreatedMessage;

  /// No description provided for @confirmRemoveAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Account'**
  String get confirmRemoveAccountTitle;

  /// No description provided for @accountAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get accountAddTitle;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get noInternetConnection;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountName;

  /// No description provided for @accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountEmail;

  /// No description provided for @accountPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get accountPassword;

  /// No description provided for @accountConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get accountConfirmPassword;

  /// No description provided for @accountConfirmPasswordMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords must match.'**
  String get accountConfirmPasswordMatch;

  /// No description provided for @accountSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get accountSaveButton;

  /// No description provided for @accountRegisterButton.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get accountRegisterButton;

  /// No description provided for @accountRemoveButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get accountRemoveButton;

  /// No description provided for @accountRepairButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get accountRepairButton;

  /// No description provided for @accountRegisterLabel.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get accountRegisterLabel;

  /// No description provided for @accountDefault.
  ///
  /// In en, this message translates to:
  /// **'This is your default account.'**
  String get accountDefault;

  /// No description provided for @accountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Something is wrong with this account.'**
  String get accountInvalid;

  /// No description provided for @accountConnectivity.
  ///
  /// In en, this message translates to:
  /// **'There was an issue connecting with this account. If the issue was network related this will correct itself.'**
  String get accountConnectivity;

  /// No description provided for @accountCreated.
  ///
  /// In en, this message translates to:
  /// **'Registration successful! Please check your email for verification instructions prior to logging in.'**
  String get accountCreated;

  /// No description provided for @accountUpdated.
  ///
  /// In en, this message translates to:
  /// **'Your account has been successfully updated.'**
  String get accountUpdated;

  /// No description provided for @invalidCredentialsError.
  ///
  /// In en, this message translates to:
  /// **'The credentials you entered are incorrect. Please try again.'**
  String get invalidCredentialsError;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'There was a problem connecting to the server. Please check your connection and try again.'**
  String get serverError;

  /// No description provided for @bayNumber.
  ///
  /// In en, this message translates to:
  /// **'Bay #{bay}'**
  String bayNumber(Object bay);

  /// No description provided for @batteryLife.
  ///
  /// In en, this message translates to:
  /// **'Battery Life'**
  String get batteryLife;

  /// No description provided for @memoryUsage.
  ///
  /// In en, this message translates to:
  /// **'Memory Used'**
  String get memoryUsage;

  /// No description provided for @confirmClearCalibrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Calibration'**
  String get confirmClearCalibrationTitle;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get confirmDelete;

  /// No description provided for @confirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get confirmYes;

  /// No description provided for @confirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get confirmCancel;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpTitle;

  /// No description provided for @helpCheckList.
  ///
  /// In en, this message translates to:
  /// **'Pre-deployment Checklist'**
  String get helpCheckList;

  /// No description provided for @offlineProductGuide.
  ///
  /// In en, this message translates to:
  /// **'Offline Product Guide'**
  String get offlineProductGuide;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @enterSearchTerm.
  ///
  /// In en, this message translates to:
  /// **'Enter Search Term'**
  String get enterSearchTerm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @errorLoadingVersion.
  ///
  /// In en, this message translates to:
  /// **'Error Loading App Version'**
  String get errorLoadingVersion;

  /// No description provided for @helpUploadLogs.
  ///
  /// In en, this message translates to:
  /// **'Send Diagnostics'**
  String get helpUploadLogs;

  /// No description provided for @helpCreateBackup.
  ///
  /// In en, this message translates to:
  /// **'Create Phone Backup'**
  String get helpCreateBackup;

  /// No description provided for @reportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report Issue'**
  String get reportIssue;

  /// No description provided for @reportIssueDescription.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue you are experiencing'**
  String get reportIssueDescription;

  /// No description provided for @reportIssueEmail.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get reportIssueEmail;

  /// No description provided for @reportIssueSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get reportIssueSubmit;

  /// No description provided for @reportIssueSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Issue Submitted'**
  String get reportIssueSubmitted;

  /// No description provided for @reportIssueThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback. We\'ll review your report and get back to you soon.'**
  String get reportIssueThankYou;

  /// No description provided for @reportIssueEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please include an email'**
  String get reportIssueEmailRequired;

  /// No description provided for @reportIssueEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get reportIssueEmailInvalid;

  /// No description provided for @reportIssueSubmissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report'**
  String get reportIssueSubmissionFailed;

  /// No description provided for @reportIssueNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error occurred. Please check your connection and try again.'**
  String get reportIssueNetworkError;

  /// No description provided for @reportIssueServerError.
  ///
  /// In en, this message translates to:
  /// **'Server error occurred. Please try again later.'**
  String get reportIssueServerError;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @attachPhotos.
  ///
  /// In en, this message translates to:
  /// **'Attach Photos'**
  String get attachPhotos;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @helpBackupCreated.
  ///
  /// In en, this message translates to:
  /// **'Phone Backup Created'**
  String get helpBackupCreated;

  /// No description provided for @helpBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Phone Backup Failed'**
  String get helpBackupFailed;

  /// No description provided for @backupShareSubject.
  ///
  /// In en, this message translates to:
  /// **'FieldKit Backup'**
  String get backupShareSubject;

  /// No description provided for @backupShareMessage.
  ///
  /// In en, this message translates to:
  /// **'FieldKit application backup.'**
  String get backupShareMessage;

  /// No description provided for @developerBuild.
  ///
  /// In en, this message translates to:
  /// **'Developer Build'**
  String get developerBuild;

  /// No description provided for @logsUploaded.
  ///
  /// In en, this message translates to:
  /// **'Logs Uploaded'**
  String get logsUploaded;

  /// No description provided for @legalTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legalTitle;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// No description provided for @modulesWaterTemp.
  ///
  /// In en, this message translates to:
  /// **'Water Temperature Module'**
  String get modulesWaterTemp;

  /// No description provided for @modulesWaterPh.
  ///
  /// In en, this message translates to:
  /// **'pH Module'**
  String get modulesWaterPh;

  /// No description provided for @modulesWaterOrp.
  ///
  /// In en, this message translates to:
  /// **'ORP Module'**
  String get modulesWaterOrp;

  /// No description provided for @modulesWaterDo.
  ///
  /// In en, this message translates to:
  /// **'Dissolved Oxygen Module'**
  String get modulesWaterDo;

  /// No description provided for @modulesWaterEc.
  ///
  /// In en, this message translates to:
  /// **'Conductivity Module'**
  String get modulesWaterEc;

  /// No description provided for @modulesWaterDepth.
  ///
  /// In en, this message translates to:
  /// **'Water Depth Module'**
  String get modulesWaterDepth;

  /// No description provided for @modulesWeather.
  ///
  /// In en, this message translates to:
  /// **'Weather Module'**
  String get modulesWeather;

  /// No description provided for @modulesDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics Module'**
  String get modulesDiagnostics;

  /// No description provided for @modulesRandom.
  ///
  /// In en, this message translates to:
  /// **'Random Module'**
  String get modulesRandom;

  /// No description provided for @modulesDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance Module'**
  String get modulesDistance;

  /// No description provided for @modulesUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown Module'**
  String get modulesUnknown;

  /// No description provided for @sensorWaterTemperature.
  ///
  /// In en, this message translates to:
  /// **'Water Temperature'**
  String get sensorWaterTemperature;

  /// No description provided for @sensorWaterPh.
  ///
  /// In en, this message translates to:
  /// **'pH'**
  String get sensorWaterPh;

  /// No description provided for @sensorWaterEc.
  ///
  /// In en, this message translates to:
  /// **'Conductivity'**
  String get sensorWaterEc;

  /// No description provided for @sensorWaterDo.
  ///
  /// In en, this message translates to:
  /// **'Dissolved Oxygen'**
  String get sensorWaterDo;

  /// No description provided for @sensorWaterDoPressure.
  ///
  /// In en, this message translates to:
  /// **'DO Pressure'**
  String get sensorWaterDoPressure;

  /// No description provided for @sensorWaterDoTemperature.
  ///
  /// In en, this message translates to:
  /// **'Air Temperature'**
  String get sensorWaterDoTemperature;

  /// No description provided for @sensorWaterOrp.
  ///
  /// In en, this message translates to:
  /// **'ORP'**
  String get sensorWaterOrp;

  /// No description provided for @sensorWaterDepthPressure.
  ///
  /// In en, this message translates to:
  /// **'Water Depth (Pressure)'**
  String get sensorWaterDepthPressure;

  /// No description provided for @sensorWaterDepthTemperature.
  ///
  /// In en, this message translates to:
  /// **'Water Temperature'**
  String get sensorWaterDepthTemperature;

  /// No description provided for @sensorDiagnosticsTemperature.
  ///
  /// In en, this message translates to:
  /// **'Internal Temperature'**
  String get sensorDiagnosticsTemperature;

  /// No description provided for @sensorDiagnosticsUptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get sensorDiagnosticsUptime;

  /// No description provided for @sensorDiagnosticsMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get sensorDiagnosticsMemory;

  /// No description provided for @sensorDiagnosticsFreeMemory.
  ///
  /// In en, this message translates to:
  /// **'Free Memory'**
  String get sensorDiagnosticsFreeMemory;

  /// No description provided for @sensorDiagnosticsBatteryCharge.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get sensorDiagnosticsBatteryCharge;

  /// No description provided for @sensorDiagnosticsBatteryVoltage.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get sensorDiagnosticsBatteryVoltage;

  /// No description provided for @sensorDiagnosticsBatteryVBus.
  ///
  /// In en, this message translates to:
  /// **'Battery (VBus)'**
  String get sensorDiagnosticsBatteryVBus;

  /// No description provided for @sensorDiagnosticsBatteryVs.
  ///
  /// In en, this message translates to:
  /// **'Battery (Vs)'**
  String get sensorDiagnosticsBatteryVs;

  /// No description provided for @sensorDiagnosticsBatteryMa.
  ///
  /// In en, this message translates to:
  /// **'Battery (mA)'**
  String get sensorDiagnosticsBatteryMa;

  /// No description provided for @sensorDiagnosticsBatteryPower.
  ///
  /// In en, this message translates to:
  /// **'Battery (Power)'**
  String get sensorDiagnosticsBatteryPower;

  /// No description provided for @sensorDiagnosticsSolarVBus.
  ///
  /// In en, this message translates to:
  /// **'Solar (VBus)'**
  String get sensorDiagnosticsSolarVBus;

  /// No description provided for @sensorDiagnosticsSolarVs.
  ///
  /// In en, this message translates to:
  /// **'Solar (Vs)'**
  String get sensorDiagnosticsSolarVs;

  /// No description provided for @sensorDiagnosticsSolarMa.
  ///
  /// In en, this message translates to:
  /// **'Solar (mA)'**
  String get sensorDiagnosticsSolarMa;

  /// No description provided for @sensorDiagnosticsSolarPower.
  ///
  /// In en, this message translates to:
  /// **'Solar (Power)'**
  String get sensorDiagnosticsSolarPower;

  /// No description provided for @sensorWeatherRain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get sensorWeatherRain;

  /// No description provided for @sensorWeatherWindSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wind Speed'**
  String get sensorWeatherWindSpeed;

  /// No description provided for @sensorWeatherWindDirection.
  ///
  /// In en, this message translates to:
  /// **'Wind Direction'**
  String get sensorWeatherWindDirection;

  /// No description provided for @sensorWeatherHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get sensorWeatherHumidity;

  /// No description provided for @sensorWeatherTemperature1.
  ///
  /// In en, this message translates to:
  /// **'Temperature 1'**
  String get sensorWeatherTemperature1;

  /// No description provided for @sensorWeatherTemperature2.
  ///
  /// In en, this message translates to:
  /// **'Temperature 2'**
  String get sensorWeatherTemperature2;

  /// No description provided for @sensorWeatherPressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get sensorWeatherPressure;

  /// No description provided for @sensorWeatherWindDir.
  ///
  /// In en, this message translates to:
  /// **'Wind Direction'**
  String get sensorWeatherWindDir;

  /// No description provided for @sensorWeatherWindDirMv.
  ///
  /// In en, this message translates to:
  /// **'Wind Direction Raw ADC'**
  String get sensorWeatherWindDirMv;

  /// No description provided for @sensorWeatherWindHrMaxSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wind Max Speed (1 hour)'**
  String get sensorWeatherWindHrMaxSpeed;

  /// No description provided for @sensorWeatherWindHrMaxDir.
  ///
  /// In en, this message translates to:
  /// **'Wind Max Direction (1 hour)'**
  String get sensorWeatherWindHrMaxDir;

  /// No description provided for @sensorWeatherWind10mMaxSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wind Max Speed (10 min)'**
  String get sensorWeatherWind10mMaxSpeed;

  /// No description provided for @sensorWeatherWind10mMaxDir.
  ///
  /// In en, this message translates to:
  /// **'Wind Max Direction (10 min)'**
  String get sensorWeatherWind10mMaxDir;

  /// No description provided for @sensorWeatherWind2mAvgSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wind Average Speed (2 min)'**
  String get sensorWeatherWind2mAvgSpeed;

  /// No description provided for @sensorWeatherWind2mAvgDir.
  ///
  /// In en, this message translates to:
  /// **'Wind Average Direction (2 min)'**
  String get sensorWeatherWind2mAvgDir;

  /// No description provided for @sensorWeatherRainThisHour.
  ///
  /// In en, this message translates to:
  /// **'Rain This Hour'**
  String get sensorWeatherRainThisHour;

  /// No description provided for @sensorWeatherRainPrevHour.
  ///
  /// In en, this message translates to:
  /// **'Rain Previous Hour'**
  String get sensorWeatherRainPrevHour;

  /// No description provided for @sensorDistanceDistance0.
  ///
  /// In en, this message translates to:
  /// **'Distance 0'**
  String get sensorDistanceDistance0;

  /// No description provided for @sensorDistanceDistance1.
  ///
  /// In en, this message translates to:
  /// **'Distance 1'**
  String get sensorDistanceDistance1;

  /// No description provided for @sensorDistanceDistance2.
  ///
  /// In en, this message translates to:
  /// **'Distance 2'**
  String get sensorDistanceDistance2;

  /// No description provided for @sensorDistanceCalibration.
  ///
  /// In en, this message translates to:
  /// **'Distance Cal'**
  String get sensorDistanceCalibration;

  /// No description provided for @sensorRandomRandom0.
  ///
  /// In en, this message translates to:
  /// **'Random 0'**
  String get sensorRandomRandom0;

  /// No description provided for @sensorRandomRandom1.
  ///
  /// In en, this message translates to:
  /// **'Random 1'**
  String get sensorRandomRandom1;

  /// No description provided for @sensorRandomRandom2.
  ///
  /// In en, this message translates to:
  /// **'Random 2'**
  String get sensorRandomRandom2;

  /// No description provided for @sensorRandomRandom3.
  ///
  /// In en, this message translates to:
  /// **'Random 3'**
  String get sensorRandomRandom3;

  /// No description provided for @sensorRandomRandom4.
  ///
  /// In en, this message translates to:
  /// **'Random 4'**
  String get sensorRandomRandom4;

  /// No description provided for @sensorRandomRandom5.
  ///
  /// In en, this message translates to:
  /// **'Random 5'**
  String get sensorRandomRandom5;

  /// No description provided for @sensorRandomRandom6.
  ///
  /// In en, this message translates to:
  /// **'Random 6'**
  String get sensorRandomRandom6;

  /// No description provided for @sensorRandomRandom7.
  ///
  /// In en, this message translates to:
  /// **'Random 7'**
  String get sensorRandomRandom7;

  /// No description provided for @sensorRandomRandom8.
  ///
  /// In en, this message translates to:
  /// **'Random 8'**
  String get sensorRandomRandom8;

  /// No description provided for @sensorRandomRandom9.
  ///
  /// In en, this message translates to:
  /// **'Random 9'**
  String get sensorRandomRandom9;

  /// No description provided for @helpSettingsIconActive.
  ///
  /// In en, this message translates to:
  /// **'Help Settings Icon - active'**
  String get helpSettingsIconActive;

  /// No description provided for @helpSettingsIconInactive.
  ///
  /// In en, this message translates to:
  /// **'Help Settings Icon - inactive'**
  String get helpSettingsIconInactive;

  /// No description provided for @helpSettingsIcon.
  ///
  /// In en, this message translates to:
  /// **'Help Settings Icon'**
  String get helpSettingsIcon;

  /// No description provided for @accountSettingsIcon.
  ///
  /// In en, this message translates to:
  /// **'Account Settings Icon'**
  String get accountSettingsIcon;

  /// No description provided for @languageSettingsIcon.
  ///
  /// In en, this message translates to:
  /// **'Language Settings Icon'**
  String get languageSettingsIcon;

  /// No description provided for @legalSettingsIcon.
  ///
  /// In en, this message translates to:
  /// **'Legal Settings Icon'**
  String get legalSettingsIcon;

  /// No description provided for @advancedSettingsIcon.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings icon'**
  String get advancedSettingsIcon;

  /// No description provided for @stationDisconnectedIcon.
  ///
  /// In en, this message translates to:
  /// **'Station Disconnected Icon'**
  String get stationDisconnectedIcon;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @stationDisconnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Station Disconnected'**
  String get stationDisconnectedTitle;

  /// No description provided for @getHelpButton.
  ///
  /// In en, this message translates to:
  /// **'Get Help'**
  String get getHelpButton;

  /// No description provided for @stationConnectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Station Connected'**
  String get stationConnectedMessage;

  /// No description provided for @stationDisconnectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Station Disconnected'**
  String get stationDisconnectedMessage;

  /// No description provided for @pressWifiButtonAgain.
  ///
  /// In en, this message translates to:
  /// **'1. Press the WiFi button again'**
  String get pressWifiButtonAgain;

  /// No description provided for @turnOnStationWifi.
  ///
  /// In en, this message translates to:
  /// **'2. Turn on the station\'s WiFi access point directly from the station settings menu'**
  String get turnOnStationWifi;

  /// No description provided for @visitSupportWebsite.
  ///
  /// In en, this message translates to:
  /// **'3. If you\'re still having issues, visit '**
  String get visitSupportWebsite;

  /// No description provided for @unDeployStation.
  ///
  /// In en, this message translates to:
  /// **'Undeploy Station'**
  String get unDeployStation;

  /// No description provided for @unDeployConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to undeploy this station? This will clear its deployment configuration.'**
  String get unDeployConfirmation;

  /// No description provided for @unDeploySuccess.
  ///
  /// In en, this message translates to:
  /// **'Station has been undeployed successfully'**
  String get unDeploySuccess;

  /// Title for station assembly help section
  ///
  /// In en, this message translates to:
  /// **'Assemble Station'**
  String get assembleStation;

  /// No description provided for @stationSetupInstructions.
  ///
  /// In en, this message translates to:
  /// **'Station Setup Instructions'**
  String get stationSetupInstructions;

  /// No description provided for @phModuleSetup.
  ///
  /// In en, this message translates to:
  /// **'pH Module Setup'**
  String get phModuleSetup;

  /// No description provided for @waterTempModuleSetup.
  ///
  /// In en, this message translates to:
  /// **'Water Temperature Module Setup'**
  String get waterTempModuleSetup;

  /// No description provided for @conductivityModuleSetup.
  ///
  /// In en, this message translates to:
  /// **'Conductivity Module Setup'**
  String get conductivityModuleSetup;

  /// No description provided for @doModuleSetup.
  ///
  /// In en, this message translates to:
  /// **'Dissolved Oxygen Module Setup'**
  String get doModuleSetup;

  /// No description provided for @distanceModuleSetup.
  ///
  /// In en, this message translates to:
  /// **'Distance Module Setup'**
  String get distanceModuleSetup;

  /// No description provided for @weatherModuleSetup.
  ///
  /// In en, this message translates to:
  /// **'Weather Module Setup'**
  String get weatherModuleSetup;

  /// No description provided for @noModuleDescription.
  ///
  /// In en, this message translates to:
  /// **'No station has this type of module installed. Install this module on a station to calibrate it.'**
  String get noModuleDescription;

  /// No description provided for @mapContainer.
  ///
  /// In en, this message translates to:
  /// **'Interactive map showing station locations and user position'**
  String get mapContainer;

  /// No description provided for @mapZoomInButton.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get mapZoomInButton;

  /// No description provided for @mapZoomOutButton.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get mapZoomOutButton;

  /// No description provided for @mapCenterLocationButton.
  ///
  /// In en, this message translates to:
  /// **'Center on my location'**
  String get mapCenterLocationButton;

  /// No description provided for @mapLocationMarker.
  ///
  /// In en, this message translates to:
  /// **'Your current location'**
  String get mapLocationMarker;

  /// No description provided for @mapStationMarker.
  ///
  /// In en, this message translates to:
  /// **'FieldKit station'**
  String get mapStationMarker;

  /// No description provided for @mapGestureHint.
  ///
  /// In en, this message translates to:
  /// **'Use two fingers to zoom, drag to pan around the map'**
  String get mapGestureHint;

  /// No description provided for @mapLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading map'**
  String get mapLoading;

  /// No description provided for @mapLoaded.
  ///
  /// In en, this message translates to:
  /// **'Map loaded successfully'**
  String get mapLoaded;

  /// No description provided for @locationNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Location not available. Please check your location permissions and try again.'**
  String get locationNotAvailable;

  /// No description provided for @bytesUsed.
  ///
  /// In en, this message translates to:
  /// **'{bytesUsed}MB of 512MB'**
  String bytesUsed(Object bytesUsed);

  /// No description provided for @buttonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get buttonNext;

  /// No description provided for @buttonSkipThisStep.
  ///
  /// In en, this message translates to:
  /// **'Skip this step'**
  String get buttonSkipThisStep;

  /// No description provided for @buttonSkipAssemblyInstructions.
  ///
  /// In en, this message translates to:
  /// **'Skip Assembly Instructions'**
  String get buttonSkipAssemblyInstructions;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @backButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backButton;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @every.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get every;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get to;

  /// No description provided for @noValue.
  ///
  /// In en, this message translates to:
  /// **'--'**
  String get noValue;

  /// No description provided for @moreItems.
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String moreItems(Object count);

  /// No description provided for @space.
  ///
  /// In en, this message translates to:
  /// **' '**
  String get space;

  /// No description provided for @lastCalibrated.
  ///
  /// In en, this message translates to:
  /// **'Last Calibrated'**
  String get lastCalibrated;

  /// No description provided for @unitMilliseconds.
  ///
  /// In en, this message translates to:
  /// **'ms'**
  String get unitMilliseconds;

  /// No description provided for @unitSeconds.
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get unitSeconds;

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get unitMinutes;

  /// No description provided for @unitHours.
  ///
  /// In en, this message translates to:
  /// **'hr'**
  String get unitHours;

  /// No description provided for @unitDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get unitDays;

  /// No description provided for @unitMicrosiemensPerCm.
  ///
  /// In en, this message translates to:
  /// **'μS/cm'**
  String get unitMicrosiemensPerCm;

  /// No description provided for @unitMillisiemensPerCm.
  ///
  /// In en, this message translates to:
  /// **'mS/cm'**
  String get unitMillisiemensPerCm;

  /// No description provided for @unitSiemensPerCm.
  ///
  /// In en, this message translates to:
  /// **'S/cm'**
  String get unitSiemensPerCm;

  /// No description provided for @unitPh.
  ///
  /// In en, this message translates to:
  /// **'pH'**
  String get unitPh;

  /// No description provided for @unitMillivolts.
  ///
  /// In en, this message translates to:
  /// **'mV'**
  String get unitMillivolts;

  /// No description provided for @unitVolts.
  ///
  /// In en, this message translates to:
  /// **'V'**
  String get unitVolts;

  /// No description provided for @unitCelsius.
  ///
  /// In en, this message translates to:
  /// **'°C'**
  String get unitCelsius;

  /// No description provided for @unitFahrenheit.
  ///
  /// In en, this message translates to:
  /// **'°F'**
  String get unitFahrenheit;

  /// No description provided for @unitKelvin.
  ///
  /// In en, this message translates to:
  /// **'K'**
  String get unitKelvin;

  /// No description provided for @unitPercent.
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get unitPercent;

  /// No description provided for @unitPpm.
  ///
  /// In en, this message translates to:
  /// **'ppm'**
  String get unitPpm;

  /// No description provided for @unitPpb.
  ///
  /// In en, this message translates to:
  /// **'ppb'**
  String get unitPpb;

  /// No description provided for @unitMeters.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get unitMeters;

  /// No description provided for @unitCentimeters.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get unitCentimeters;

  /// No description provided for @unitMillimeters.
  ///
  /// In en, this message translates to:
  /// **'mm'**
  String get unitMillimeters;

  /// No description provided for @unitKilometers.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get unitKilometers;

  /// No description provided for @unitInches.
  ///
  /// In en, this message translates to:
  /// **'in'**
  String get unitInches;

  /// No description provided for @unitFeet.
  ///
  /// In en, this message translates to:
  /// **'ft'**
  String get unitFeet;

  /// No description provided for @unitYards.
  ///
  /// In en, this message translates to:
  /// **'yd'**
  String get unitYards;

  /// No description provided for @unitMiles.
  ///
  /// In en, this message translates to:
  /// **'mi'**
  String get unitMiles;

  /// No description provided for @unitPascals.
  ///
  /// In en, this message translates to:
  /// **'Pa'**
  String get unitPascals;

  /// No description provided for @unitHectopascals.
  ///
  /// In en, this message translates to:
  /// **'hPa'**
  String get unitHectopascals;

  /// No description provided for @unitMillibars.
  ///
  /// In en, this message translates to:
  /// **'mbar'**
  String get unitMillibars;

  /// No description provided for @unitAtmospheres.
  ///
  /// In en, this message translates to:
  /// **'atm'**
  String get unitAtmospheres;

  /// No description provided for @unitMetersPerSecond.
  ///
  /// In en, this message translates to:
  /// **'m/s'**
  String get unitMetersPerSecond;

  /// No description provided for @unitKilometersPerHour.
  ///
  /// In en, this message translates to:
  /// **'km/h'**
  String get unitKilometersPerHour;

  /// No description provided for @unitMilesPerHour.
  ///
  /// In en, this message translates to:
  /// **'mph'**
  String get unitMilesPerHour;

  /// No description provided for @unitDegrees.
  ///
  /// In en, this message translates to:
  /// **'°'**
  String get unitDegrees;

  /// No description provided for @unitRadians.
  ///
  /// In en, this message translates to:
  /// **'rad'**
  String get unitRadians;

  /// No description provided for @unitLux.
  ///
  /// In en, this message translates to:
  /// **'lux'**
  String get unitLux;

  /// No description provided for @unitLumens.
  ///
  /// In en, this message translates to:
  /// **'lm'**
  String get unitLumens;

  /// No description provided for @unitCandela.
  ///
  /// In en, this message translates to:
  /// **'cd'**
  String get unitCandela;

  /// No description provided for @unitWatts.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get unitWatts;

  /// No description provided for @unitMilliwatts.
  ///
  /// In en, this message translates to:
  /// **'mW'**
  String get unitMilliwatts;

  /// No description provided for @unitKilowatts.
  ///
  /// In en, this message translates to:
  /// **'kW'**
  String get unitKilowatts;

  /// No description provided for @unitJoules.
  ///
  /// In en, this message translates to:
  /// **'J'**
  String get unitJoules;

  /// No description provided for @unitCalories.
  ///
  /// In en, this message translates to:
  /// **'cal'**
  String get unitCalories;

  /// No description provided for @unitKilocalories.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get unitKilocalories;

  /// No description provided for @unitAmperes.
  ///
  /// In en, this message translates to:
  /// **'A'**
  String get unitAmperes;

  /// No description provided for @unitMilliamperes.
  ///
  /// In en, this message translates to:
  /// **'mA'**
  String get unitMilliamperes;

  /// No description provided for @unitMicroamperes.
  ///
  /// In en, this message translates to:
  /// **'μA'**
  String get unitMicroamperes;

  /// No description provided for @unitOhms.
  ///
  /// In en, this message translates to:
  /// **'Ω'**
  String get unitOhms;

  /// No description provided for @unitKiloohms.
  ///
  /// In en, this message translates to:
  /// **'kΩ'**
  String get unitKiloohms;

  /// No description provided for @unitMegaohms.
  ///
  /// In en, this message translates to:
  /// **'MΩ'**
  String get unitMegaohms;

  /// No description provided for @unitSiemens.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get unitSiemens;

  /// No description provided for @unitMicrosiemens.
  ///
  /// In en, this message translates to:
  /// **'μS'**
  String get unitMicrosiemens;

  /// No description provided for @unitMillisiemens.
  ///
  /// In en, this message translates to:
  /// **'mS'**
  String get unitMillisiemens;

  /// No description provided for @unitHertz.
  ///
  /// In en, this message translates to:
  /// **'Hz'**
  String get unitHertz;

  /// No description provided for @unitKilohertz.
  ///
  /// In en, this message translates to:
  /// **'kHz'**
  String get unitKilohertz;

  /// No description provided for @unitMegahertz.
  ///
  /// In en, this message translates to:
  /// **'MHz'**
  String get unitMegahertz;

  /// No description provided for @unitGigahertz.
  ///
  /// In en, this message translates to:
  /// **'GHz'**
  String get unitGigahertz;

  /// No description provided for @passwordShowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get passwordShowTooltip;

  /// No description provided for @passwordHideTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get passwordHideTooltip;

  /// No description provided for @mapExpandTooltip.
  ///
  /// In en, this message translates to:
  /// **'Expand map to full screen'**
  String get mapExpandTooltip;

  /// No description provided for @valueRising.
  ///
  /// In en, this message translates to:
  /// **'Value is rising'**
  String get valueRising;

  /// No description provided for @valueFalling.
  ///
  /// In en, this message translates to:
  /// **'Value is falling'**
  String get valueFalling;

  /// No description provided for @fieldKitLogo.
  ///
  /// In en, this message translates to:
  /// **'FieldKit Logo'**
  String get fieldKitLogo;

  /// No description provided for @welcomeImage.
  ///
  /// In en, this message translates to:
  /// **'Welcome illustration'**
  String get welcomeImage;

  /// No description provided for @accountsImage.
  ///
  /// In en, this message translates to:
  /// **'FieldKit station setup illustration'**
  String get accountsImage;

  /// No description provided for @distanceModuleIcon.
  ///
  /// In en, this message translates to:
  /// **'Distance module icon'**
  String get distanceModuleIcon;

  /// No description provided for @weatherModuleIcon.
  ///
  /// In en, this message translates to:
  /// **'Weather module icon'**
  String get weatherModuleIcon;

  /// No description provided for @waterModuleIcon.
  ///
  /// In en, this message translates to:
  /// **'Water module icon'**
  String get waterModuleIcon;

  /// No description provided for @dataSyncIllustration.
  ///
  /// In en, this message translates to:
  /// **'Data sync illustration'**
  String get dataSyncIllustration;

  /// No description provided for @noStationsImage.
  ///
  /// In en, this message translates to:
  /// **'No stations illustration'**
  String get noStationsImage;

  /// No description provided for @batteryIcon.
  ///
  /// In en, this message translates to:
  /// **'Battery icon'**
  String get batteryIcon;

  /// No description provided for @memoryIcon.
  ///
  /// In en, this message translates to:
  /// **'Memory icon'**
  String get memoryIcon;

  /// No description provided for @stationConnectedIcon.
  ///
  /// In en, this message translates to:
  /// **'Station connected icon'**
  String get stationConnectedIcon;

  /// No description provided for @configureIcon.
  ///
  /// In en, this message translates to:
  /// **'Configure icon'**
  String get configureIcon;

  /// No description provided for @globeIcon.
  ///
  /// In en, this message translates to:
  /// **'Globe icon'**
  String get globeIcon;

  /// No description provided for @eyeIcon.
  ///
  /// In en, this message translates to:
  /// **'Eye icon'**
  String get eyeIcon;

  /// No description provided for @eyeSlashIcon.
  ///
  /// In en, this message translates to:
  /// **'Eye slash icon'**
  String get eyeSlashIcon;

  /// No description provided for @checkmarkIcon.
  ///
  /// In en, this message translates to:
  /// **'Checkmark icon'**
  String get checkmarkIcon;

  /// No description provided for @alertIcon.
  ///
  /// In en, this message translates to:
  /// **'Alert icon'**
  String get alertIcon;

  /// No description provided for @uploadIcon.
  ///
  /// In en, this message translates to:
  /// **'Upload Icon'**
  String get uploadIcon;

  /// No description provided for @downloadIcon.
  ///
  /// In en, this message translates to:
  /// **'Download Icon'**
  String get downloadIcon;

  /// No description provided for @uploadingIcon.
  ///
  /// In en, this message translates to:
  /// **'Uploading icon'**
  String get uploadingIcon;

  /// No description provided for @downloadingIcon.
  ///
  /// In en, this message translates to:
  /// **'Downloading icon'**
  String get downloadingIcon;

  /// No description provided for @syncIcon.
  ///
  /// In en, this message translates to:
  /// **'Sync icon'**
  String get syncIcon;

  /// No description provided for @warningIcon.
  ///
  /// In en, this message translates to:
  /// **'Warning icon'**
  String get warningIcon;

  /// No description provided for @infoIcon.
  ///
  /// In en, this message translates to:
  /// **'Information icon'**
  String get infoIcon;

  /// No description provided for @warningErrorIcon.
  ///
  /// In en, this message translates to:
  /// **'Warning error icon'**
  String get warningErrorIcon;

  /// No description provided for @greenCheckmarkIcon.
  ///
  /// In en, this message translates to:
  /// **'Green checkmark icon'**
  String get greenCheckmarkIcon;

  /// No description provided for @noticeIcon.
  ///
  /// In en, this message translates to:
  /// **'Notice icon'**
  String get noticeIcon;

  /// No description provided for @confirmIcon.
  ///
  /// In en, this message translates to:
  /// **'Confirm icon'**
  String get confirmIcon;

  /// No description provided for @questionMarkIcon.
  ///
  /// In en, this message translates to:
  /// **'Question mark icon'**
  String get questionMarkIcon;

  /// No description provided for @errorNavigatingToPage.
  ///
  /// In en, this message translates to:
  /// **'Error navigating to page: {message}'**
  String errorNavigatingToPage(String message);

  /// No description provided for @errorSearching.
  ///
  /// In en, this message translates to:
  /// **'Error searching: {message}'**
  String errorSearching(String message);

  /// No description provided for @errorStartingApp.
  ///
  /// In en, this message translates to:
  /// **'Error initializing app.'**
  String get errorStartingApp;

  /// No description provided for @loadingConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get loadingConfiguration;

  /// No description provided for @loadingEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get loadingEnvironment;

  /// No description provided for @loadingLocale.
  ///
  /// In en, this message translates to:
  /// **'Locale'**
  String get loadingLocale;

  /// No description provided for @syncUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get syncUploading;

  /// No description provided for @syncDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get syncDownloading;

  /// No description provided for @syncDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get syncDisconnected;

  /// No description provided for @syncNoUpload.
  ///
  /// In en, this message translates to:
  /// **'No Upload Available'**
  String get syncNoUpload;

  /// No description provided for @syncNoDownload.
  ///
  /// In en, this message translates to:
  /// **'No Download Available'**
  String get syncNoDownload;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown Error'**
  String get unknownError;

  /// No description provided for @firmwareCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get firmwareCheck;

  /// No description provided for @accountEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Account'**
  String get accountEditTitle;

  /// No description provided for @accountRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get accountRegistrationFailed;

  /// No description provided for @accountFormFail.
  ///
  /// In en, this message translates to:
  /// **'Form validation failed'**
  String get accountFormFail;

  /// No description provided for @errorInitializingApp.
  ///
  /// In en, this message translates to:
  /// **'Error initializing app.'**
  String get errorInitializingApp;

  /// No description provided for @stationsTabIcon.
  ///
  /// In en, this message translates to:
  /// **'Stations tab icon'**
  String get stationsTabIcon;

  /// No description provided for @dataSyncTabIcon.
  ///
  /// In en, this message translates to:
  /// **'Data sync tab icon'**
  String get dataSyncTabIcon;

  /// No description provided for @settingsTabIcon.
  ///
  /// In en, this message translates to:
  /// **'Settings tab icon'**
  String get settingsTabIcon;

  /// No description provided for @dataSyncImage.
  ///
  /// In en, this message translates to:
  /// **'Data sync illustration'**
  String get dataSyncImage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
