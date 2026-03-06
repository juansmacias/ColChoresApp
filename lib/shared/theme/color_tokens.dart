import 'package:flutter/material.dart';

abstract class ColorTokens {
  // Pastel primary palette
  static const Color primaryBlue = Color(0xFF90CAF9);
  static const Color primaryGreen = Color(0xFFA5D6A7);
  static const Color primaryPink = Color(0xFFF48FB1);
  static const Color primaryYellow = Color(0xFFFFF59D);
  static const Color primaryLavender = Color(0xFFCE93D8);
  static const Color primaryPeach = Color(0xFFFFCC80);

  // Neutral backgrounds
  static const Color backgroundWarm = Color(0xFFFAF8F5);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF5F5F5);

  // Text
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);

  // Status
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);

  // Offline banner
  static const Color offlineBanner = Color(0xFFFFF176);
}
