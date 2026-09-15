import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'atayr_colors.dart';

class AtayrTypography {
  static TextTheme get textTheme {
    return GoogleFonts.spaceGroteskTextTheme().copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        fontSize: 32,
        height: 1.1,
        color: AtayrColors.ink,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        height: 1.2,
        color: AtayrColors.ink,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        fontSize: 24,
        height: 1.2,
        color: AtayrColors.ink,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: AtayrColors.ink,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: AtayrColors.ink,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: AtayrColors.ink,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: AtayrColors.ink,
      ),
      bodyLarge: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        color: AtayrColors.ink,
      ),
      bodyMedium: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: AtayrColors.ink,
      ),
      labelLarge: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w600, // For buttons
        fontSize: 14,
        color: AtayrColors.ink,
        letterSpacing: 1.2,
      ),
      labelMedium: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: AtayrColors.ink,
      ),
    );
  }
}
