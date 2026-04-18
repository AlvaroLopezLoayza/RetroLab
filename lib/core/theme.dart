/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — App Theme
/// Premium dark retro theme with orange accents and analog feel.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

class RetroTheme {
  RetroTheme._();

  // ── Dark Theme (Classic Black) ───────────────────────────────────────────

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: RetroColors.background,
      primaryColor: RetroColors.accent,
      colorScheme: const ColorScheme.dark(
        primary: RetroColors.accent,
        secondary: RetroColors.accentLight,
        surface: RetroColors.surface,
        error: RetroColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: RetroColors.textPrimary,
        onError: Colors.white,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.spaceMono(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: RetroColors.accent,
          letterSpacing: 2,
        ),
        iconTheme: const IconThemeData(color: RetroColors.accent),
      ),

      // Text
      textTheme: _buildTextTheme(Brightness.dark),

      // Icons
      iconTheme: const IconThemeData(
        color: RetroColors.textSecondary,
        size: 24,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RetroColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
          ),
          textStyle: GoogleFonts.spaceMono(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RetroColors.accent,
          side: const BorderSide(color: RetroColors.accent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
          ),
          textStyle: GoogleFonts.spaceMono(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: RetroColors.accent,
        inactiveTrackColor: RetroColors.surfaceLight,
        thumbColor: RetroColors.accent,
        overlayColor: RetroColors.accent.withValues(alpha: 0.2),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),

      // Bottom navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: RetroColors.surface,
        selectedItemColor: RetroColors.accent,
        unselectedItemColor: RetroColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: RetroColors.surface,
        contentTextStyle: GoogleFonts.spaceMono(
          color: RetroColors.textPrimary,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RetroDimens.radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: RetroColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        ),
        titleTextStyle: GoogleFonts.spaceMono(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: RetroColors.textPrimary,
        ),
      ),

      // Card
      cardTheme: CardTheme(
        color: RetroColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: RetroColors.surfaceLight,
        thickness: 1,
      ),
    );
  }

  // ── Light Theme (Daylight Yellow) ────────────────────────────────────────

  static ThemeData get light {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: RetroColors.lightBackground,
      primaryColor: RetroColors.accent,
      colorScheme: const ColorScheme.light(
        primary: RetroColors.accent,
        secondary: RetroColors.accentLight,
        surface: RetroColors.lightSurface,
        error: RetroColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: RetroColors.lightTextPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.spaceMono(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: RetroColors.accent,
          letterSpacing: 2,
        ),
        iconTheme: const IconThemeData(color: RetroColors.accent),
      ),
      textTheme: _buildTextTheme(Brightness.light),
      sliderTheme: SliderThemeData(
        activeTrackColor: RetroColors.accent,
        inactiveTrackColor: RetroColors.lightSurface,
        thumbColor: RetroColors.accent,
        overlayColor: RetroColors.accent.withValues(alpha: 0.2),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
    );
  }

  // ── Text Theme ───────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(Brightness brightness) {
    final color = brightness == Brightness.dark
        ? RetroColors.textPrimary
        : RetroColors.lightTextPrimary;

    return TextTheme(
      displayLarge: GoogleFonts.spaceMono(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 2,
      ),
      displayMedium: GoogleFonts.spaceMono(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.5,
      ),
      headlineLarge: GoogleFonts.spaceMono(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1,
      ),
      headlineMedium: GoogleFonts.spaceMono(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 1,
      ),
      titleLarge: GoogleFonts.spaceMono(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: GoogleFonts.spaceMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color.withValues(alpha: 0.8),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color.withValues(alpha: 0.6),
      ),
      labelLarge: GoogleFonts.spaceMono(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: RetroColors.accent,
        letterSpacing: 1.5,
      ),
      labelMedium: GoogleFonts.spaceMono(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color.withValues(alpha: 0.7),
        letterSpacing: 1,
      ),
      labelSmall: GoogleFonts.spaceMono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: color.withValues(alpha: 0.5),
        letterSpacing: 1,
      ),
    );
  }
}
