import 'package:flutter/material.dart';

/// SHIK ROLL design tokens — Courier App (Internal Use Only).
abstract final class ShikColors {
  /// Terracotta brand accent.
  static const Color terracotta = Color(0xFFFF5722);
  static const Color terracottaDark = Color(0xFFD84315);
  static const Color terracottaLight = Color(0xFFFFAB91);

  /// Halal badge.
  static const Color halalGreen = Color(0xFF1B8A4C);
  static const Color halalGreenDark = Color(0xFF0F5E32);

  /// Success (delivered / completed).
  static const Color success = Color(0xFF2E9E5B);

  /// Warning (cash payment).
  static const Color warning = Color(0xFFF9A825);

  /// Light theme surfaces.
  static const Color lightBackground = Color(0xFFFAF6F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF2B2320);
  static const Color lightTextSecondary = Color(0xFF7A6C66);

  /// Dark theme surfaces.
  static const Color darkBackground = Color(0xFF191210);
  static const Color darkSurface = Color(0xFF251B17);
  static const Color darkTextPrimary = Color(0xFFF5EEEA);
  static const Color darkTextSecondary = Color(0xFFB9A89F);
}
