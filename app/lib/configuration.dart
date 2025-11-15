import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

class Configuration {
  static Configuration? singleton;

  final String? commitRefName;
  final String? commitSha;
  final String storagePath;
  final String portalBaseUrl;

  Configuration({
    required this.commitRefName,
    required this.commitSha,
    required this.storagePath,
    required this.portalBaseUrl,
  });

  static Configuration get instance => singleton!;

  static Future<Configuration> load() async {
    if (singleton != null) {
      return singleton!;
    }

    await dotenv.load(fileName: ".env");

    final storagePath = await Configuration._getStoragePath();

    final commitRefName = dotenv.env['CI_COMMIT_REF_NAME'];
    final commitSha = dotenv.env['CI_COMMIT_SHA'];
    final portal = dotenv.env['FK_PORTAL_URL'] ?? "https://api.fieldkit.org";

    return singleton = Configuration(
        commitRefName: commitRefName,
        commitSha: commitSha,
        storagePath: storagePath,
        portalBaseUrl: portal);
  }

  static Future<String> _getStoragePath() async {
    final fromEnv = dotenv.env['FK_APP_SUPPORT_PATH'];
    if (fromEnv != null) {
      return fromEnv;
    }

    final location = await getApplicationSupportDirectory();
    return location.path;
  }

  bool get production => commitRefName?.contains("main") ?? false;

  @override
  String toString() {
    return "Config(commitRefName=$commitRefName, commitSha=$commitSha, storagePath=$storagePath, portalBaseUrl=$portalBaseUrl)";
  }
}
