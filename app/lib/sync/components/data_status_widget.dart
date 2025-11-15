import 'package:fk/models/known_stations_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fk/l10n/app_localizations.dart';
import '../../view_station/firmware_page.dart';

class FirmwareUpdateWidget extends StatelessWidget {
  final StationModel station;
  final String readings;

  const FirmwareUpdateWidget(
      {super.key, required this.readings, required this.station});

  @override
  Widget build(BuildContext context) {
    return _buildNoticeContainer(
      context,
      color: const Color(0xFFFFE1B9),
      content: _buildNoticeContent(
        context,
        readings,
        'resources/images/notice_dark_icon.svg',
        AppLocalizations.of(context)!.updateRequiredDataPage,
      ),
      buttonText: AppLocalizations.of(context)!.manageFirmwareButton,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StationFirmwarePage(station: station),
          ),
        );
      },
    );
  }
}

class DownloadedWidget extends StatelessWidget {
  final int total;
  final VoidCallback onDismissed;

  const DownloadedWidget(
      {super.key, required this.total, required this.onDismissed});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return _buildSyncStatusWidget(
      context,
      color: const Color(0xFFe2f5de),
      iconPath: 'resources/images/green_checkmark.svg',
      statusMessage: localizations.readingsDownloaded(total),
      message: localizations.syncDownloadSuccess,
      onDismissed: onDismissed,
    );
  }
}

class UploadedWidget extends StatelessWidget {
  final int total;
  final VoidCallback onDismissed;

  const UploadedWidget(
      {super.key, required this.total, required this.onDismissed});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return _buildSyncStatusWidget(
      context,
      color: const Color(0xFFe2f5de),
      iconPath: 'resources/images/green_checkmark.svg',
      statusMessage: localizations.readingsUploaded(total),
      message: localizations.syncUploadSuccess,
      onDismissed: onDismissed,
    );
  }
}

Widget _buildNoticeContainer(BuildContext context,
    {required Color color,
    required Widget content,
    required String buttonText,
    required VoidCallback onPressed}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: color),
        child: MediaQuery.of(context).size.width > 415
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: content),
                  _buildActionButton(context, color, buttonText, onPressed),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  content,
                  const SizedBox(height: 8.0),
                  _buildActionButton(context, color, buttonText, onPressed),
                ],
              ),
      );
    },
  );
}

String _getIconSemanticsLabel(String iconPath, AppLocalizations localizations) {
  switch (iconPath) {
    case 'resources/images/green_checkmark.svg':
      return localizations.greenCheckmarkIcon;
    case 'resources/images/notice_dark_icon.svg':
      return localizations.noticeIcon;
    default:
      return '';
  }
}

Widget _buildNoticeContent(
    BuildContext context, String readings, String iconPath, String text) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(readings),
      const SizedBox(height: 8.0),
      Row(
        children: [
          SvgPicture.asset(
            iconPath,
            height: 18.0,
            width: 18.0,
            semanticsLabel:
                _getIconSemanticsLabel(iconPath, AppLocalizations.of(context)!),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.0),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8.0),
    ],
  );
}

Widget _buildActionButton(
    BuildContext context, Color color, String text, VoidCallback onPressed) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.all(14),
      backgroundColor: color,
      foregroundColor: const Color(0xFF000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
        side: const BorderSide(color: Color(0xFF000000), width: 1.5),
      ),
      textStyle: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500),
    ),
    onPressed: onPressed,
    child: Text(text),
  );
}

Widget _buildSyncStatusWidget(BuildContext context,
    {required Color color,
    required String iconPath,
    required String statusMessage,
    required String message,
    required VoidCallback onDismissed}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final localizations = AppLocalizations.of(context)!;
      return Container(
          margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          decoration: BoxDecoration(color: color),
          child: MediaQuery.of(context).size.width > 415
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      _buildSyncStatusWidgetHelper(context,
                          color: color,
                          iconPath: iconPath,
                          statusMessage: statusMessage,
                          message: message,
                          onDismissed: onDismissed),
                      _buildActionButton(
                        context,
                        color,
                        localizations.syncDismissOk,
                        onDismissed,
                      ),
                    ])
              : Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      _buildSyncStatusWidgetHelper(context,
                          color: color,
                          iconPath: iconPath,
                          statusMessage: statusMessage,
                          message: message,
                          onDismissed: onDismissed),
                      _buildActionButton(
                        context,
                        color,
                        localizations.syncDismissOk,
                        onDismissed,
                      ),
                    ]));
    },
  );
}

Widget _buildSyncStatusWidgetHelper(BuildContext context,
    {required Color color,
    required String iconPath,
    required String statusMessage,
    required String message,
    required VoidCallback onDismissed}) {
  return Expanded(
      child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  statusMessage,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.5),
            child: Row(
              children: [
                SvgPicture.asset(
                  iconPath,
                  height: 14.0,
                  width: 14.0,
                  semanticsLabel: _getIconSemanticsLabel(
                      iconPath, AppLocalizations.of(context)!),
                ),
                const SizedBox(width: 4.0),
                Flexible(
                    child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(message,
                      maxLines: 3,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(fontSize: 12.0)),
                )),
              ],
            ),
          ),
        ],
      ),
    ],
  ));
}

class UploadFailedWidget extends StatelessWidget {
  final int total;
  final VoidCallback onDismissed;

  const UploadFailedWidget(
      {super.key, required this.total, required this.onDismissed});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return _buildSyncStatusWidget(
      context,
      color: const Color(0xFFffd4cc),
      iconPath: 'resources/images/notice_dark_icon.svg',
      statusMessage: localizations.readingsUploaded(total),
      message: localizations.syncUploadFailed,
      onDismissed: onDismissed,
    );
  }
}

class DownloadFailedWidget extends StatelessWidget {
  final int readings;
  final int total;
  final VoidCallback onDismissed;

  const DownloadFailedWidget(
      {super.key,
      required this.readings,
      required this.total,
      required this.onDismissed});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return _buildSyncStatusWidget(
      context,
      color: const Color(0xFFffd4cc),
      iconPath: 'resources/images/notice_dark_icon.svg',
      statusMessage: localizations.downloadIncomplete(readings, total),
      message: localizations.syncDownloadFailed,
      onDismissed: onDismissed,
    );
  }
}
