import 'package:flutter/material.dart';
import 'atayr_colors.dart';
import 'atayr_typography.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AtayrColors.background,
      colorScheme: const ColorScheme.light(
        primary: AtayrColors.ink,
        secondary: AtayrColors.accent,
        surface: AtayrColors.surface,
        onPrimary: AtayrColors.background,
        onSecondary: AtayrColors.ink,
        onSurface: AtayrColors.ink,
        error: AtayrColors.error,
        onError: AtayrColors.background,
      ),
      textTheme: AtayrTypography.textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AtayrColors.background,
        foregroundColor: AtayrColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AtayrTypography.textTheme.titleLarge,
        iconTheme: const IconThemeData(color: AtayrColors.ink),
      ),
    );
  }

  // Neo-Brutalism doesn't strictly have a traditional dark theme in this design,
  // but if needed, we'll map it to lightTheme for now or invert carefully.
  static ThemeData get darkTheme => lightTheme;
}
