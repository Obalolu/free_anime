import 'package:flutter_dotenv/flutter_dotenv.dart';

enum EnvFlavor { development, staging, production }

final class EnvConfig {
  EnvConfig._();

  static late EnvFlavor flavor;

  static Future<void> init({required EnvFlavor flavor}) async {
    EnvConfig.flavor = flavor;
    await dotenv.load(fileName: '.env');
  }

  static String get baseUrl {
    final value = dotenv.env['BASE_URL']?.trim() ?? '';
    if (value.isNotEmpty) return value;
    return 'http://localhost:8080';
  }
}
