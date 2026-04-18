/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Film Stock Presets
///
/// Each film stock defines unique color curves, grain characteristics,
/// and vignette profiles to emulate real analog film types.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'constants.dart';

/// Represents a photographic film stock with analog characteristics.
class FilmStock {
  final String id;
  final String name;
  final String shortName;
  final String description;
  final Color badgeColor;
  final IconData icon;

  // ── Color Adjustments ───────────────────────────────────────────────────
  /// Temperature shift (-1.0 cool … 1.0 warm)
  final double temperature;

  /// Saturation multiplier (0.0 = B&W, 1.0 = normal, 2.0 = vivid)
  final double saturation;

  /// Contrast multiplier
  final double contrast;

  /// Brightness offset (-1.0 … 1.0)
  final double brightness;

  /// Highlight tint color (overlay on bright areas)
  final Color highlightTint;

  /// Shadow tint color (overlay on dark areas)
  final Color shadowTint;

  /// Tint intensity (0.0 … 1.0)
  final double tintStrength;

  // ── Grain & Texture ─────────────────────────────────────────────────────
  /// Base grain intensity (0.0 … 1.0)
  final double baseGrain;

  /// Whether grain is colored or monochrome
  final bool coloredGrain;

  // ── Vignette ────────────────────────────────────────────────────────────
  /// Base vignette intensity (0.0 … 1.0)
  final double baseVignette;

  // ── Color Channel Curves (simplified) ───────────────────────────────────
  /// Red channel gamma (< 1.0 brightens reds, > 1.0 darkens)
  final double redGamma;

  /// Green channel gamma
  final double greenGamma;

  /// Blue channel gamma
  final double blueGamma;

  const FilmStock({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.badgeColor,
    this.icon = Icons.camera_roll,
    this.temperature = 0.0,
    this.saturation = 1.0,
    this.contrast = 1.0,
    this.brightness = 0.0,
    this.highlightTint = Colors.transparent,
    this.shadowTint = Colors.transparent,
    this.tintStrength = 0.0,
    this.baseGrain = 0.15,
    this.coloredGrain = false,
    this.baseVignette = 0.3,
    this.redGamma = 1.0,
    this.greenGamma = 1.0,
    this.blueGamma = 1.0,
  });
}

/// All available film stock presets.
class FilmStocks {
  FilmStocks._();

  static const List<FilmStock> all = [
    kodakGold200,
    fujiSuperia400,
    ilfordHP5,
    polaroid600,
    lomo400,
    expired1998,
  ];

  // ── Kodak Gold 200 ─────────────────────────────────────────────────────
  // Warm tones, golden highlights, classic consumer film look.
  static const kodakGold200 = FilmStock(
    id: 'kodak_gold_200',
    name: 'Kodak Gold 200',
    shortName: 'GOLD 200',
    description: 'Warm golden tones with rich skin colors. '
        'The definitive summer film.',
    badgeColor: RetroColors.kodakYellow,
    icon: Icons.wb_sunny,
    temperature: 0.35,
    saturation: 1.15,
    contrast: 1.05,
    brightness: 0.03,
    highlightTint: Color(0xFFFFE082),
    shadowTint: Color(0xFF4E342E),
    tintStrength: 0.15,
    baseGrain: 0.12,
    coloredGrain: true,
    baseVignette: 0.25,
    redGamma: 0.92,
    greenGamma: 0.98,
    blueGamma: 1.08,
  );

  // ── Fuji Superia 400 ───────────────────────────────────────────────────
  // Cool greens, slightly muted, versatile everyday film.
  static const fujiSuperia400 = FilmStock(
    id: 'fuji_superia_400',
    name: 'Fuji Superia 400',
    shortName: 'SUPERIA',
    description: 'Cool green tones with natural colors. '
        'Perfect for everyday memories.',
    badgeColor: RetroColors.fujiGreen,
    icon: Icons.eco,
    temperature: -0.1,
    saturation: 0.95,
    contrast: 1.1,
    brightness: 0.0,
    highlightTint: Color(0xFFC8E6C9),
    shadowTint: Color(0xFF1B5E20),
    tintStrength: 0.12,
    baseGrain: 0.15,
    coloredGrain: true,
    baseVignette: 0.3,
    redGamma: 1.04,
    greenGamma: 0.94,
    blueGamma: 1.0,
  );

  // ── Ilford HP5 Plus (B&W) ──────────────────────────────────────────────
  // Classic black & white with rich tonal range and heavy grain.
  static const ilfordHP5 = FilmStock(
    id: 'ilford_hp5',
    name: 'Ilford HP5 Plus',
    shortName: 'HP5 B&W',
    description: 'Legendary B&W film. Deep contrast with creamy mid-tones '
        'and expressive grain.',
    badgeColor: RetroColors.ilfordWhite,
    icon: Icons.contrast,
    temperature: 0.0,
    saturation: 0.0, // B&W
    contrast: 1.25,
    brightness: 0.02,
    highlightTint: Color(0xFFF5F5F5),
    shadowTint: Color(0xFF212121),
    tintStrength: 0.05,
    baseGrain: 0.22,
    coloredGrain: false,
    baseVignette: 0.35,
    redGamma: 1.0,
    greenGamma: 1.0,
    blueGamma: 1.0,
  );

  // ── Polaroid 600 ───────────────────────────────────────────────────────
  // Soft, washed-out, dreamy with slight blue shadows.
  static const polaroid600 = FilmStock(
    id: 'polaroid_600',
    name: 'Polaroid 600',
    shortName: 'POL 600',
    description: 'Dreamy soft tones with washed-out highlights. '
        'Instant nostalgia.',
    badgeColor: RetroColors.polaroidWhite,
    icon: Icons.photo,
    temperature: 0.05,
    saturation: 0.8,
    contrast: 0.85,
    brightness: 0.08,
    highlightTint: Color(0xFFF3E5F5),
    shadowTint: Color(0xFF283593),
    tintStrength: 0.18,
    baseGrain: 0.1,
    coloredGrain: true,
    baseVignette: 0.2,
    redGamma: 0.96,
    greenGamma: 1.0,
    blueGamma: 0.92,
  );

  // ── Lomo 400 ───────────────────────────────────────────────────────────
  // High saturation, heavy vignette, cross-processed colors.
  static const lomo400 = FilmStock(
    id: 'lomo_400',
    name: 'Lomo 400',
    shortName: 'LOMO',
    description: 'Vivid cross-processed colors with heavy vignette. '
        'Expect the unexpected.',
    badgeColor: RetroColors.lomoBlue,
    icon: Icons.palette,
    temperature: 0.15,
    saturation: 1.4,
    contrast: 1.2,
    brightness: 0.0,
    highlightTint: Color(0xFFFFEB3B),
    shadowTint: Color(0xFF0D47A1),
    tintStrength: 0.2,
    baseGrain: 0.18,
    coloredGrain: true,
    baseVignette: 0.45,
    redGamma: 0.88,
    greenGamma: 1.05,
    blueGamma: 0.9,
  );

  // ── Expired 1998 ───────────────────────────────────────────────────────
  // Degraded colors, pink/magenta cast, unpredictable shifts.
  static const expired1998 = FilmStock(
    id: 'expired_1998',
    name: 'Expired 1998',
    shortName: 'EXP 98',
    description: 'Found in grandma\'s attic. Unpredictable color shifts, '
        'pink casts, and beautiful accidents.',
    badgeColor: RetroColors.expiredPink,
    icon: Icons.auto_awesome,
    temperature: 0.25,
    saturation: 0.75,
    contrast: 0.9,
    brightness: 0.05,
    highlightTint: Color(0xFFF48FB1),
    shadowTint: Color(0xFF880E4F),
    tintStrength: 0.25,
    baseGrain: 0.25,
    coloredGrain: true,
    baseVignette: 0.35,
    redGamma: 0.85,
    greenGamma: 1.1,
    blueGamma: 0.95,
  );

  /// Find a film stock by its ID.
  static FilmStock getById(String id) {
    return all.firstWhere(
      (stock) => stock.id == id,
      orElse: () => kodakGold200,
    );
  }
}
