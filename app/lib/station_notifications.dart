import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:fk/globals.dart';
import 'package:fk/app_widget.dart';
import 'package:fk/station_disconnected_help.dart';

class StationNotifications {
  static final StationNotifications _instance =
      StationNotifications._internal();
  factory StationNotifications() => _instance;
  StationNotifications._internal();

  final Map<String, bool> _connectionStatus = {};
  final Map<String, DateTime> _lastNotificationTime = {};
  bool _isInitialized = false;
  bool _appFullyLoaded = false;
  bool _isSyncing = false;

  // Rate limiting: minimum 5 seconds between notifications for the same station
  static const Duration _notificationCooldown = Duration(seconds: 5);

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  void setAppFullyLoaded() {
    _appFullyLoaded = true;
  }

  void startSync() {
    _isSyncing = true;
  }

  void endSync() {
    _isSyncing = false;
  }

  void updateStationConnection(String deviceId, bool isConnected,
      {String? stationName}) {
    if (!_isInitialized) return;

    // Suppress notifications during syncing
    if (_isSyncing) return;

    // For not showing notifications until app is fully loaded
    if (!_appFullyLoaded) {
      _connectionStatus[deviceId] = isConnected;
      return;
    }

    // Check rate limiting
    final lastNotification = _lastNotificationTime[deviceId];
    if (lastNotification != null) {
      final timeSinceLastNotification =
          DateTime.now().difference(lastNotification);
      if (timeSinceLastNotification < _notificationCooldown) {
        return;
      }
    }

    final wasConnected = _connectionStatus[deviceId] ?? false;

    if (isConnected && !wasConnected) {
      // Station just connected
      _connectionStatus[deviceId] = true;
      _lastNotificationTime[deviceId] = DateTime.now();
      _showConnectionNotification(true, deviceId, stationName);
    } else if (!isConnected && wasConnected) {
      // Station just disconnected
      _connectionStatus[deviceId] = false;
      _lastNotificationTime[deviceId] = DateTime.now();
      _showConnectionNotification(false, deviceId, stationName);
    }
  }

  void _showConnectionNotification(
      bool isConnected, String deviceId, String? stationName) {
    final scaffoldMessenger = snackbarKey.currentState;
    if (scaffoldMessenger == null || !scaffoldMessenger.mounted) return;

    final context = scaffoldMessenger.context;
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return;

    String message = isConnected
        ? localizations.stationConnectedMessage
        : localizations.stationDisconnectedMessage;

    if (stationName != null && stationName.isNotEmpty) {
      message = message.replaceAll('{station}', stationName);
    }

    if (isConnected) {
      _showSnackbarConnect(context, message);
    } else {
      _showSnackbarDisconnect(message, onHelpTap: _onHelpTap);
    }
  }

  void _showSnackbarConnect(BuildContext context, String message) {
    final scaffoldMessenger = snackbarKey.currentState;
    if (scaffoldMessenger == null || !scaffoldMessenger.mounted) return;

    _dismissCurrentSnackbar();

    // Vibration feedback
    HapticFeedback.lightImpact();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10, bottom: 4),
              child: SvgPicture.asset(
                'resources/images/confirm_dark_icon.svg',
                width: 15,
                height: 15,
                semanticsLabel: AppLocalizations.of(context)!.confirmIcon,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF2D3D4F),
                  BlendMode.srcIn,
                ),
              ),
            ),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Avenir',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D3D4F),
                  fontSize: 18,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 15),
        showCloseIcon: true,
        closeIconColor: const Color(0xFF2D3D4F),
        backgroundColor: const Color(0xFFE2F5DE),
        clipBehavior: Clip.hardEdge,
      ),
    );
  }

  void _showSnackbarDisconnect(String message,
      {required void Function(BuildContext) onHelpTap}) {
    final scaffoldMessenger = snackbarKey.currentState;
    if (scaffoldMessenger == null || !scaffoldMessenger.mounted) return;

    _dismissCurrentSnackbar();

    // Add vibration feedback for disconnect (slightly stronger)
    HapticFeedback.mediumImpact();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 4),
                  child: SvgPicture.asset(
                    'resources/images/notice_dark_icon.svg',
                    width: 15,
                    height: 15,
                    semanticsLabel:
                        AppLocalizations.of(scaffoldMessenger.context)!
                            .noticeIcon,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF2D3D4F),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontFamily: 'Avenir',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3D4F),
                      fontSize: 18,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                _dismissCurrentSnackbar();
                _onHelpTap(scaffoldMessenger.context);
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: SvgPicture.asset(
                  'resources/images/icon_question_mark.svg',
                  width: 15,
                  height: 15,
                  semanticsLabel:
                      AppLocalizations.of(scaffoldMessenger.context)!
                          .questionMarkIcon,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 30),
        closeIconColor: const Color(0xFF2D3D4F),
        backgroundColor: const Color(0xFFFFE1B9),
        clipBehavior: Clip.hardEdge,
      ),
    );
  }

  void _dismissCurrentSnackbar() {
    final scaffoldMessenger = snackbarKey.currentState;
    if (scaffoldMessenger == null || !scaffoldMessenger.mounted) return;
    scaffoldMessenger.clearSnackBars();
  }

  void _onHelpTap(BuildContext context) {
    rootNavigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) => const StationDisconnectedHelpPage(),
      ),
    );
  }
}
