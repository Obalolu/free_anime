import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:free_anime/core/config/env_config.dart';
import 'package:free_anime/core/di/service_locator.dart';
import 'package:free_anime/core/logging/logger_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart';

Future<void> bootstrap(
  Widget Function() builder, {
  required EnvFlavor flavor,
}) async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await LoggerService.init(flavor: flavor);

      FlutterError.onError = (details) {
        LoggerService.handleFlutterError(details);
      };

      await EnvConfig.init(flavor: flavor);
      await Hive.initFlutter();

      PlatformDispatcher.instance.onError = (error, stack) {
        LoggerService.instance.error('Uncaught async error', error, stack);
        return true;
      };

      Bloc.observer = TalkerBlocObserver(talker: LoggerService.talker);

      await configureDependencies();

      runApp(builder());
    },
    (error, stackTrace) {
      LoggerService.instance.error('Uncaught zone error', error, stackTrace);
    },
  );
}
