import 'package:flutter/material.dart';

/// UI-802 Design System — color tokens.
///
/// Mirrors the POS design tokens (apps/pos/lib/core/theme/app_colors.dart);
/// cross-app imports are not possible, so the customer app carries its own
/// copy of the palette.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFFD32F2F);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFFDAD6);
  static const Color onPrimaryContainer = Color(0xFF410002);

  /// Фирменный терракотово-оранжевый акцент логотипа SHIK ROLL.
  static const Color brandAccent = Color(0xFFFF5722);

  static const Color secondary = Color(0xFF455A64);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFCFD8DC);
  static const Color onSecondaryContainer = Color(0xFF102027);

  // Functional
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color warningContainer = Color(0xFFFFE0B2);
  static const Color error = Color(0xFFB00020);
  static const Color onSurface = Color(0xFF212121);
  static const Color info = Color(0xFF0288D1);

  // Neutral gray scale (UI-802)
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray200 = Color(0xFFEEEEEE);
  static const Color gray300 = Color(0xFFE0E0E0);
  static const Color gray400 = Color(0xFFBDBDBD);
  static const Color gray500 = Color(0xFF9E9E9E);
  static const Color gray600 = Color(0xFF757575);
  static const Color gray700 = Color(0xFF616161);
  static const Color gray900 = Color(0xFF212121);

  static const Color surface = Color(0xFFFFFFFF);

  // Catalog semantic tokens
  static const Color statusHalal = Color(0xFF1B7F4C);
  static const Color statusHalalContainer = Color(0xFFD6F0E2);
}
