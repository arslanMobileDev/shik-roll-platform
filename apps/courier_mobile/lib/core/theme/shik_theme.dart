import 'package:flutter/material.dart';

import 'shik_colors.dart';

/// SHIK ROLL theme factory — compact mobile layout, terracotta accent.
abstract final class ShikTheme {
  static ThemeData light() => _base(
        brightness: Brightness.light,
        scaffold: ShikColors.lightBackground,
        surface: ShikColors.lightSurface,
        textPrimary: ShikColors.lightTextPrimary,
        textSecondary: ShikColors.lightTextSecondary,
      );

  static ThemeData dark() => _base(
        brightness: Brightness.dark,
        scaffold: ShikColors.darkBackground,
        surface: ShikColors.darkSurface,
        textPrimary: ShikColors.darkTextPrimary,
        textSecondary: ShikColors.darkTextSecondary,
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: ShikColors.terracotta,
      brightness: brightness,
    ).copyWith(
      primary: ShikColors.terracotta,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1.5,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ShikColors.terracotta,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
