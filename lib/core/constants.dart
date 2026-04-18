/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Core Constants
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';

// ── Brand Colors ─────────────────────────────────────────────────────────────

class RetroColors {
  RetroColors._();

  // Primary palette
  static const Color background = Color(0xFF111111);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceLight = Color(0xFF242424);
  static const Color accent = Color(0xFFFF6200);
  static const Color accentLight = Color(0xFFFF8A3D);
  static const Color accentDark = Color(0xFFCC4E00);

  // Date stamp yellow (classic disposable cam)
  static const Color dateYellow = Color(0xFFFFD600);
  static const Color dateOrange = Color(0xFFFF9100);

  // Text
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textMuted = Color(0xFF666666);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFB300);

  // Film stock badge colors
  static const Color kodakYellow = Color(0xFFFFD600);
  static const Color fujiGreen = Color(0xFF66BB6A);
  static const Color ilfordWhite = Color(0xFFE0E0E0);
  static const Color polaroidWhite = Color(0xFFF5F5F5);
  static const Color lomoBlue = Color(0xFF42A5F5);
  static const Color expiredPink = Color(0xFFE91E63);

  // Daylight theme
  static const Color lightBackground = Color(0xFFFFF8E1);
  static const Color lightSurface = Color(0xFFFFECB3);
  static const Color lightTextPrimary = Color(0xFF212121);
}

// ── Dimensions ───────────────────────────────────────────────────────────────

class RetroDimens {
  RetroDimens._();

  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 28.0;

  static const double paddingSm = 8.0;
  static const double paddingMd = 16.0;
  static const double paddingLg = 24.0;
  static const double paddingXl = 32.0;

  static const double shutterButtonSize = 80.0;
  static const double shutterButtonInner = 64.0;

  static const double iconSizeSm = 20.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
}

// ── Strings ──────────────────────────────────────────────────────────────────

class RetroStrings {
  RetroStrings._();

  static const String appName = 'RetroLab';
  static const String tagline = 'Analog Magic. Digital Soul.';
  static const String watermark = 'Shot on RetroLab • 2026';
  static const String developing = 'DEVELOPING...';
  static const String filmFinished = 'FILM FINISHED';
  static const String loadNewRoll = 'Load New Roll';
  static const String exposuresRemaining = 'EXP';

  // Onboarding
  static const String onboardTitle1 = 'Welcome to the Lab';
  static const String onboardBody1 =
      'Every photo is a one-of-a-kind analog masterpiece. '
      'No two shots are ever the same.';
  static const String onboardTitle2 = 'Choose Your Film';
  static const String onboardBody2 =
      '6 legendary film stocks — from Kodak Gold warmth '
      'to Ilford B&W drama. Each roll tells a different story.';
  static const String onboardTitle3 = 'More Than a Filter';
  static const String onboardBody3 =
      'Real grain, real light leaks, real scratches. '
      'Import any photo and make it timeless.';
}

// ── Asset Paths ──────────────────────────────────────────────────────────────

class RetroAssets {
  RetroAssets._();

  static const String lightLeakPrefix = 'assets/light_leaks/leak_';
  static const String lottieDeveloping = 'assets/lottie/developing.json';
  static const String lottieFilmReel = 'assets/lottie/film_reel.json';
  static const String soundShutter = 'assets/sounds/shutter.mp3';
  static const String textureGrain = 'assets/textures/grain.png';
  static const String textureScratch = 'assets/textures/scratch.png';
  static const String textureDust = 'assets/textures/dust.png';

  static String lightLeak(int index) => '$lightLeakPrefix$index.png';
}

// ── Hive Box Names ───────────────────────────────────────────────────────────

class HiveBoxes {
  HiveBoxes._();

  static const String photos = 'retro_photos';
  static const String rolls = 'film_rolls';
  static const String settings = 'app_settings';
  static const String stats = 'user_stats';
}

// ── Date Stamp Styles ────────────────────────────────────────────────────────

enum DateStampStyle {
  classic90s('Classic 90s'),
  handwritten('Handwritten'),
  polaroid('Polaroid');

  final String label;
  const DateStampStyle(this.label);
}

enum DateStampPosition {
  bottomRight('Bottom Right'),
  bottomLeft('Bottom Left'),
  bottomCenter('Bottom Center');

  final String label;
  const DateStampPosition(this.label);
}

// ── Timer Durations ──────────────────────────────────────────────────────────

enum ShutterTimer {
  off(0, 'OFF'),
  threeSeconds(3, '3s'),
  tenSeconds(10, '10s');

  final int seconds;
  final String label;
  const ShutterTimer(this.seconds, this.label);
}
