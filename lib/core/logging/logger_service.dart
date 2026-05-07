import 'package:flutter/foundation.dart';
import 'package:free_anime/core/config/env_config.dart';
import 'package:talker_flutter/talker_flutter.dart';

final class LoggerService {
  LoggerService._();

  static late Talker _talker;

  static Talker get talker => _talker;
  static Talker get instance => _talker;

  static Future<void> init({required EnvFlavor flavor}) async {
    _talker = TalkerFlutter.init(
      settings: TalkerSettings(
        enabled: true,
        useHistory: true,
        maxHistoryItems: flavor == EnvFlavor.production ? 500 : 2000,
      ),
    );
  }

  static void handleFlutterError(FlutterErrorDetails details) {
    _talker.handle(details.exception, details.stack);
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  }
}
