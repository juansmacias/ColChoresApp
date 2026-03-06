import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'text_styles.dart';

abstract class AppTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ColorTokens.primaryBlue,
          brightness: Brightness.light,
          surface: ColorTokens.backgroundWarm,
        ),
        textTheme: AppTextStyles.textTheme,
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ColorTokens.primaryBlue,
          brightness: Brightness.dark,
        ),
        textTheme: AppTextStyles.textTheme,
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
        ),
      );
}
