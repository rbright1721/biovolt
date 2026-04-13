import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BioVoltColors {
  BioVoltColors._();

  static const Color background = Color(0xFF0A0E17);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceLight = Color(0xFF1A2332);
  static const Color teal = Color(0xFF00F0B5);
  static const Color amber = Color(0xFFF59E0B);
  static const Color coral = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color gridLine = Color(0xFF1E293B);
  static const Color cardBorder = Color(0xFF1F2937);
}

class BioVoltTheme {
  BioVoltTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: BioVoltColors.background,
      colorScheme: const ColorScheme.dark(
        surface: BioVoltColors.surface,
        primary: BioVoltColors.teal,
        secondary: BioVoltColors.amber,
        error: BioVoltColors.coral,
        onSurface: BioVoltColors.textPrimary,
        onPrimary: BioVoltColors.background,
      ),
      textTheme: _textTheme,
      cardTheme: CardThemeData(
        color: BioVoltColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BioVoltColors.cardBorder, width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BioVoltColors.teal,
        foregroundColor: BioVoltColors.background,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: BioVoltColors.background,
        elevation: 0,
        titleTextStyle: _monoTextStyle(20, FontWeight.w700),
      ),
    );
  }

  static TextStyle _monoTextStyle(double size, FontWeight weight) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: BioVoltColors.textPrimary,
    );
  }

  static TextTheme get _textTheme {
    return TextTheme(
      headlineLarge: _monoTextStyle(32, FontWeight.w700),
      headlineMedium: _monoTextStyle(24, FontWeight.w700),
      headlineSmall: _monoTextStyle(20, FontWeight.w600),
      titleLarge: _monoTextStyle(18, FontWeight.w600),
      titleMedium: _monoTextStyle(16, FontWeight.w500),
      titleSmall: _monoTextStyle(14, FontWeight.w500),
      bodyLarge: GoogleFonts.jetBrainsMono(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: BioVoltColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: BioVoltColors.textSecondary,
      ),
      bodySmall: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: BioVoltColors.textSecondary,
      ),
      labelLarge: GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: BioVoltColors.textSecondary,
      ),
      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        color: BioVoltColors.textSecondary,
      ),
    );
  }

  /// Value text style for large numeric displays on signal cards.
  static TextStyle valueStyle(double size, {Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color ?? BioVoltColors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Glass morphism card decoration.
  static BoxDecoration glassCard({Color glowColor = BioVoltColors.teal}) {
    return BoxDecoration(
      color: BioVoltColors.surface.withAlpha(200),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: glowColor.withAlpha(40),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: glowColor.withAlpha(15),
          blurRadius: 20,
          spreadRadius: 0,
        ),
      ],
    );
  }
}
