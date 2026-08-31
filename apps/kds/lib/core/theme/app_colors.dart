import 'package:flutter/material.dart';

/// UI-802 Design System — color tokens.
///
/// Shared with the POS app; semantic tokens (success / warning / error /
/// halal) must be used instead of hardcoded colors in widgets.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFFD32F2F);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFFDAD6);
  static const Color onPrimaryContainer = Color(0xFF410002);

  static const Color secondary = Color(0xFF455A64);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFCFD8DC);
  static const Color onSecondaryContainer = Color(0xFF102027);

  // Functional
  static const Color success = Color(0xFF2E7D32);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFC8E6C9);
  static const Color onSuccessContainer = Color(0xFF1B5E20);

  static const Color warning = Color(0xFFED6C02);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color warningContainer = Color(0xFFFFE0B2);
  static const Color onWarningContainer = Color(0xFF4E2600);

  static const Color error = Color(0xFFB00020);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFCD8DF);
  static const Color onErrorContainer = Color(0xFF5F1120);

  static const Color info = Color(0xFF0288D1);
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color infoContainer = Color(0xFFB3E5FC);
  static const Color onInfoContainer = Color(0xFF01579B);

  // Neutral gray scale (UI-802)
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray200 = Color(0xFFEEEEEE);
  static const Color gray300 = Color(0xFFE0E0E0);
  static const Color gray400 = Color(0xFFBDBDBD);
  static const Color gray500 = Color(0xFF9E9E9E);
  static const Color gray600 = Color(0xFF757575);
  static const Color gray700 = Color(0xFF616161);
  static const Color gray800 = Color(0xFF424242);
  static const Color gray900 = Color(0xFF212121);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = gray50;

  // Halal semantic token (UI-802)
  static const Color statusHalal = Color(0xFF1B7F4C);
  static const Color statusHalalContainer = Color(0xFFD6F0E2);

  // KDS delay timer tokens (order age thresholds, UI-804).
  static const Color timerOnTime = success;
  static const Color timerOnTimeContainer = successContainer;
  static const Color timerWarning = warning;
  static const Color timerWarningContainer = warningContainer;
  static const Color timerLate = error;
  static const Color timerLateContainer = errorContainer;
}
