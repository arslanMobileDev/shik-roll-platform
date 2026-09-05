import 'package:flutter/material.dart';

/// Design tokens for the SHIK ROLL Back Office (UI-805).
abstract final class AppColors {
  /// SHIK ROLL terracotta — primary brand accent.
  static const Color terracotta = Color(0xFFFF5722);

  static const Color terracottaDark = Color(0xFFD84315);
  static const Color sidebar = Color(0xFF211A16);
  static const Color sidebarActive = Color(0x14FF5722);
  static const Color scaffold = Color(0xFFFAF7F5);
  static const Color surface = Colors.white;
  static const Color ink = Color(0xFF2B2320);
  static const Color inkMuted = Color(0xFF8A7D76);
  static const Color outline = Color(0xFFE8E0DA);
  static const Color halalGreen = Color(0xFF1E8E4D);
  static const Color danger = Color(0xFFC62828);
  static const Color stopListBg = Color(0xFFFFF1EC);
}

abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.terracotta,
      primary: AppColors.terracotta,
      surface: AppColors.surface,
      error: AppColors.danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.scaffold,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.ink),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.inkMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.scaffold,
        selectedColor: AppColors.sidebarActive,
        labelStyle: const TextStyle(color: AppColors.ink),
        side: const BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.terracotta, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.terracotta,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.terracotta
              : AppColors.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.terracotta.withValues(alpha: 0.35)
              : AppColors.outline,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
