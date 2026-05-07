import 'package:flutter/material.dart';

final class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFFD5015B);
  static const Color primarySoft = Color(0xFFFF5A8D);
  static const Color background = Color(0xFF0F0F14);
  static const Color surface = Color(0xFF171720);
  static const Color elevatedSurface = Color(0xFF1D1D28);
  static const Color surfaceHigh = Color(0xFF20202B);
  static const Color border = Color(0xFF2A2A36);
  static const Color borderStrong = Color(0xFF38384A);
  static const Color mutedText = Color(0xFFAEAEBF);
  static const Color subduedText = Color(0xFF8D8DA3);
  static const Color statusComplete = Color(0xFF5DE2A5);
  static const Color statusActive = Color(0xFF5AA8FF);
  static const Color statusPaused = Color(0xFFFFCA6B);
  static const Color statusFailed = Color(0xFFFF6B7D);
  static const Color statusMuted = Color(0xFF9A9AAA);
  static const double cardRadiusMedium = 16;
  static const double cardRadiusLarge = 22;

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(primary: primary, surface: surface, secondary: primarySoft);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadiusMedium),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF12121A),
        indicatorColor: primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevatedSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevatedSurface,
        selectedColor: primary.withValues(alpha: 0.18),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: const TextStyle(color: Colors.white),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: mutedText),
        bodyMedium: TextStyle(color: mutedText),
        labelSmall: TextStyle(color: subduedText),
      ),
    );
  }
}
