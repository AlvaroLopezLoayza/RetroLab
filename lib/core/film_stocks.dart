/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Film Stock Presets  (v2)
///
/// Changes over v1:
///   • All contrast values recalibrated for the v2 S-curve processor.
///     Old values (1.05, 1.25 …) were raw multipliers for the broken formula.
///     New range is -1.0 … 1.0 where 0.0 = no change.
///   • Added `shadowLift` — lifts the black point to emulate film base fog.
///     Every real film has this; without it shadows clip to pure black.
///   • Added `filmProcess` enum for UI labeling and future per-process logic.
///   • Added `iso` for display and grain-scaling metadata.
///   • 5 new stocks: Kodak Portra 400, Kodak Ektar 100, Fuji Velvia 50,
///     CineStill 800T, Agfa Vista 200.
///   • Improved color science on all existing stocks (tighter temperature
///     values, per-channel gamma tuned against real scan references).
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'constants.dart';

// ═════════════════════════════════════════════════════════════════════════════
// ENUMS
// ═════════════════════════════════════════════════════════════════════════════

/// The chemical process used to develop the film.
/// Used for UI labels and can drive future process-specific rendering logic.
enum FilmProcess {
  /// Colour negative — C-41 process. Most consumer/portrait films.
  c41,

  /// Colour reversal (slide film) — E-6 process. Ultra-saturated, no tonal lift.
  e6,

  /// Black & white negative — various developers.
  blackAndWhite,

  /// Instant film — Polaroid / Fuji Instax chemistry.
  instant,

  /// Motion picture film re-spooled for still cameras (e.g. CineStill).
  /// Typically ECN-2 processed as C-41, producing halation.
  cinematic,
}

// ═════════════════════════════════════════════════════════════════════════════
// MODEL
// ═════════════════════════════════════════════════════════════════════════════

/// Represents a photographic film stock with analog characteristics.
class FilmStock {
  final String id;
  final String name;
  final String shortName;
  final String description;
  final Color badgeColor;
  final IconData icon;

  /// Film process type — used for UI badges and future rendering branches.
  final FilmProcess filmProcess;

  /// Nominal ISO speed — display only (grain is set explicitly via [baseGrain]).
  final int iso;

  // ── Color Adjustments ───────────────────────────────────────────────────

  /// Temperature shift (-1.0 cool … 1.0 warm).
  /// Kept in the -0.5 … 0.5 range for realistic results.
  final double temperature;

  /// Saturation multiplier (0.0 = B&W, 1.0 = normal, 1.5 = vivid).
  final double saturation;

  /// Contrast in -1.0 … 1.0 range for the v2 S-curve processor.
  ///   0.0  → no change (factor = 1.0)
  ///   0.1  → subtle boost (factor ≈ 1.2)
  ///   0.2  → moderate (factor ≈ 1.4)
  ///  -0.1  → slight softening (factor = 0.9)
  ///  -0.2  → flat/matte (factor = 0.8)
  final double contrast;

  /// Brightness offset (-1.0 … 1.0). Kept small — highlight protection in
  /// the processor prevents burning, but large values still shift midtones.
  final double brightness;

  /// Shadow lift — raises the minimum black point to emulate film base fog.
  /// (0.0 = pure black shadows, 0.08 = characteristic milky grey lift).
  /// Applied as: `pixel = pixel * (1 - shadowLift) + 255 * shadowLift`.
  final double shadowLift;

  /// Highlight tint color (composited on bright areas).
  final Color highlightTint;

  /// Shadow tint color (composited on dark areas).
  final Color shadowTint;

  /// Tint intensity (0.0 … 1.0). Keep under 0.25 for subtlety.
  final double tintStrength;

  // ── Grain & Texture ─────────────────────────────────────────────────────

  /// Base grain intensity (0.0 … 1.0).
  /// Rough real-world mapping: ISO 100 ≈ 0.06, ISO 400 ≈ 0.15, ISO 800 ≈ 0.22.
  final double baseGrain;

  /// Whether grain is coloured (like real colour negative) or monochrome (B&W).
  final bool coloredGrain;

  // ── Vignette ────────────────────────────────────────────────────────────

  /// Base vignette intensity (0.0 … 1.0).
  final double baseVignette;

  // ── Per-Channel Gamma Curves ─────────────────────────────────────────────
  // Values < 1.0 boost that channel, values > 1.0 roll it off.
  // Keep within 0.85 – 1.15 for realistic results.

  final double redGamma;
  final double greenGamma;
  final double blueGamma;

  const FilmStock({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.badgeColor,
    this.icon = Icons.camera_roll,
    this.filmProcess = FilmProcess.c41,
    this.iso = 400,
    this.temperature = 0.0,
    this.saturation = 1.0,
    this.contrast = 0.0,
    this.brightness = 0.0,
    this.shadowLift = 0.03,
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

  /// Human-readable process label for UI badges.
  String get processLabel => switch (filmProcess) {
    FilmProcess.c41 => 'C-41',
    FilmProcess.e6 => 'E-6',
    FilmProcess.blackAndWhite => 'B&W',
    FilmProcess.instant => 'Instant',
    FilmProcess.cinematic => 'ECN-2',
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// PRESETS
// ═════════════════════════════════════════════════════════════════════════════

/// All available film stock presets.
class FilmStocks {
  FilmStocks._();

  static const List<FilmStock> all = [
    // ── Consumer colour negative ──────────────────────────────────────────
    kodakGold200,
    kodakUltramax400,
    kodakPortra400,
    kodakEktar100,
    fujiSuperia400,
    agfaVista200,
    // ── Slide / reversal ─────────────────────────────────────────────────
    fujiVelvia50,
    // ── Black & white ─────────────────────────────────────────────────────
    ilfordHP5,
    // ── Cinematic ─────────────────────────────────────────────────────────
    cineStill800T,
    // ── Instant ──────────────────────────────────────────────────────────
    polaroid600,
    // ── Special ──────────────────────────────────────────────────────────
    lomo400,
    expired1998,
  ];

  // ── Kodak Gold 200 ─────────────────────────────────────────────────────
  static const FilmStock kodakGold200 = FilmStock(
    id: 'kodak_gold_200',
    name: 'K-Gold 200',
    shortName: 'GOLD',
    description: 'Tonos cálidos nostálgicos. Ideal para días soleados.',
    badgeColor: Color(0xFFFFC107),
    icon: Icons.wb_sunny,
    filmProcess: FilmProcess.c41,
    iso: 200,
    temperature: 0.35,
    saturation: 1.50,
    contrast: 0.18,
    brightness: 0.03,
    shadowLift: 0.06,
    highlightTint: Color(0xFFFFD54F),
    shadowTint: Color(0xFF4E342E),
    tintStrength: 0.40,
    baseGrain: 0.22,
    coloredGrain: true,
    baseVignette: 0.42,
    redGamma: 0.85,
    greenGamma: 1.0,
    blueGamma: 1.25,
  );

  // ── Kodak Ultramax 400 ────────────────────────────────────────────────
  // The everyday consumer workhorse. Slightly warmer and punchier than Gold.
  // Visible grain, strong contrast, great colour separation.
  static const kodakUltramax400 = FilmStock(
    id: 'kodak_ultramax_400',
    name: 'Kodak Ultramax 400',
    shortName: 'UMAX 400',
    description:
        'Punchy and versatile. Strong colour separation with a '
        'slight warm bias. The original point-and-shoot staple.',
    badgeColor: Color(0xFFE65100),
    icon: Icons.filter_vintage,
    filmProcess: FilmProcess.c41,
    iso: 400,
    temperature: 0.32,
    saturation: 1.35,
    contrast: 0.15,
    brightness: 0.02,
    shadowLift: 0.05,
    highlightTint: Color(0xFFFFCC80),
    shadowTint: Color(0xFF3E2723),
    tintStrength: 0.18,
    baseGrain: 0.20,
    coloredGrain: true,
    baseVignette: 0.38,
    redGamma: 0.93,
    greenGamma: 0.99,
    blueGamma: 1.07,
  );

  // ── Kodak Portra 400 ──────────────────────────────────────────────────
  static const FilmStock kodakPortra400 = FilmStock(
    id: 'portra_400',
    name: 'P-Portra 400',
    shortName: 'PRT400',
    description: 'Tonos de piel perfectos. Colores suaves y desaturados.',
    badgeColor: Color(0xFFFF8A65),
    icon: Icons.face,
    filmProcess: FilmProcess.c41,
    iso: 400,
    temperature: 0.28,
    saturation: 1.05,
    contrast: -0.08,
    brightness: 0.03,
    shadowLift: 0.08,
    highlightTint: Color(0xFFFFAB91),
    shadowTint: Color(0xFF37474F),
    tintStrength: 0.16,
    baseGrain: 0.16,
    coloredGrain: true,
    baseVignette: 0.30,
    redGamma: 0.88,
    greenGamma: 1.0,
    blueGamma: 1.12,
  );

  // ── Kodak Ektar 100 ───────────────────────────────────────────────────
  // The most vivid consumer negative film ever made.
  // Ultra-fine grain, punchy saturation, deep reds.
  static const kodakEktar100 = FilmStock(
    id: 'kodak_ektar_100',
    name: 'Kodak Ektar 100',
    shortName: 'EKTAR',
    description:
        'Ultra-vivid landscape film with the finest grain of any '
        'colour negative. Reds are extraordinary.',
    badgeColor: Color(0xFFC62828),
    icon: Icons.landscape,
    filmProcess: FilmProcess.c41,
    iso: 100,
    temperature: 0.26,
    saturation: 1.50,
    contrast: 0.16,
    brightness: 0.02,
    shadowLift: 0.04,
    highlightTint: Color(0xFFFFAB91),
    shadowTint: Color(0xFF1A237E),
    tintStrength: 0.16,
    baseGrain: 0.10,
    coloredGrain: true,
    baseVignette: 0.32,
    redGamma: 0.88,
    greenGamma: 0.97,
    blueGamma: 1.06,
  );

  // ── Fuji Superia 400 ──────────────────────────────────────────────────
  static const FilmStock fujiSuperia400 = FilmStock(
    id: 'fuji_superia_400',
    name: 'F-Superia 400',
    shortName: 'SUP400',
    description: 'Tonos fríos y verdes enfatizados. Estilo clásico.',
    badgeColor: Color(0xFF4CAF50),
    icon: Icons.grass,
    filmProcess: FilmProcess.c41,
    iso: 400,
    temperature: -0.08,
    saturation: 1.45,
    contrast: 0.22,
    brightness: 0.01,
    shadowLift: 0.05,
    highlightTint: Color(0xFF81C784),
    shadowTint: Color(0xFF1B5E20),
    tintStrength: -0.25,
    baseGrain: 0.30,
    coloredGrain: true,
    baseVignette: 0.50,
    redGamma: 1.15,
    greenGamma: 0.82,
    blueGamma: 1.0,
  );

  // ── Agfa Vista 200 ────────────────────────────────────────────────────
  static const FilmStock agfaVista200 = FilmStock(
    id: 'agfa_vista_200',
    name: 'A-Vista 200',
    shortName: 'VISTA',
    description: 'Colores muy saturados y vibrantes. Tonos rojos intensos.',
    badgeColor: Color(0xFFF44336),
    icon: Icons.local_fire_department,
    filmProcess: FilmProcess.c41,
    iso: 200,
    temperature: 0.15,
    saturation: 1.65,
    contrast: 0.32,
    brightness: 0.04,
    shadowLift: 0.07,
    highlightTint: Color(0xFFEF5350),
    shadowTint: Color(0xFF6A1B9A),
    tintStrength: 0.25,
    baseGrain: 0.25,
    coloredGrain: true,
    baseVignette: 0.45,
    redGamma: 0.80,
    greenGamma: 1.0,
    blueGamma: 0.90,
  );

  // ── Fuji Velvia 50 ────────────────────────────────────────────────────
  // Slide (reversal) film. Legendary for landscape photography.
  // Ultra-saturated, punchy contrast, deep blacks, NO shadow lift.
  // E-6 process means no film base fog — blacks are true black.
  static const fujiVelvia50 = FilmStock(
    id: 'fuji_velvia_50',
    name: 'Fuji Velvia 50',
    shortName: 'VELVIA',
    description:
        'The landscape photographer\'s weapon. Hyper-saturated colours, '
        'punchy contrast, with greens and blues that glow.',
    badgeColor: Color(0xFF00838F),
    icon: Icons.filter_hdr,
    filmProcess: FilmProcess.e6,
    iso: 50,
    temperature: 0.12,
    saturation: 1.65,
    contrast: 0.26,
    brightness: -0.01,
    shadowLift: 0.02,
    highlightTint: Color(0xFFFFF9C4),
    shadowTint: Color(0xFF0D47A1),
    tintStrength: 0.14,
    baseGrain: 0.08,
    coloredGrain: false,
    baseVignette: 0.30,
    redGamma: 0.94,
    greenGamma: 0.88,
    blueGamma: 0.90,
  );

  // ── Ilford HP5 Plus ───────────────────────────────────────────────────
  static const FilmStock ilfordHP5 = FilmStock(
    id: 'ilford_hp5',
    name: 'I-HP5 Plus',
    shortName: 'HP5+',
    description: 'Blanco y negro clásico con alto contraste y grano.',
    badgeColor: Color(0xFF424242),
    icon: Icons.contrast,
    filmProcess: FilmProcess.blackAndWhite,
    iso: 400,
    temperature: 0.0,
    saturation: 0.0,
    contrast: 0.45,
    brightness: 0.02,
    shadowLift: 0.06,
    highlightTint: Colors.white,
    shadowTint: Color(0xFF212121),
    tintStrength: 0.0,
    baseGrain: 0.42,
    coloredGrain: false,
    baseVignette: 0.60,
    redGamma: 0.82,
    greenGamma: 0.82,
    blueGamma: 0.88,
  );

  // ── CineStill 800T ────────────────────────────────────────────────────
  static const FilmStock cineStill800T = FilmStock(
    id: 'cinestill_800t',
    name: 'C-Still 800T',
    shortName: '800T',
    description: 'Magia de neón nocturna. Sombras frías y alto contraste.',
    badgeColor: Color(0xFF29B6F6),
    icon: Icons.nightlife,
    filmProcess: FilmProcess.cinematic,
    iso: 800,
    temperature: -0.25,
    saturation: 1.40,
    contrast: 0.30,
    brightness: 0.03,
    shadowLift: 0.07,
    highlightTint: Color(0xFFFF5252),
    shadowTint: Color(0xFF0D47A1),
    tintStrength: -0.10,
    baseGrain: 0.35,
    coloredGrain: true,
    baseVignette: 0.55,
    redGamma: 0.90,
    greenGamma: 1.0,
    blueGamma: 0.70,
  );

  // ── Polaroid 600 ──────────────────────────────────────────────────────
  // Soft, washed-out, dreamy with blue shadows.
  // FIX: contrast was 0.85 → -0.12 (correct sign for softening).
  // FIX: brightness was 0.08 → 0.05 (less burning).
  static const polaroid600 = FilmStock(
    id: 'polaroid_600',
    name: 'Polaroid 600',
    shortName: 'POL 600',
    description:
        'Dreamy soft tones with washed-out highlights. Instant nostalgia.',
    badgeColor: RetroColors.polaroidWhite,
    icon: Icons.photo,
    filmProcess: FilmProcess.instant,
    iso: 160,
    temperature: 0.15,
    saturation: 0.95,
    contrast: -0.08,
    brightness: 0.06,
    shadowLift: 0.11,
    highlightTint: Color(0xFFF3E5F5),
    shadowTint: Color(0xFF283593),
    tintStrength: 0.24,
    baseGrain: 0.14,
    coloredGrain: true,
    baseVignette: 0.30,
    redGamma: 0.97,
    greenGamma: 1.0,
    blueGamma: 0.93,
  );

  // ── Lomo 400 ──────────────────────────────────────────────────────────
  // Cross-processed, vivid, heavy vignette.
  // FIX: contrast was 1.2 → 0.13.
  static const lomo400 = FilmStock(
    id: 'lomo_400',
    name: 'Lomo 400',
    shortName: 'LOMO',
    description:
        'Vivid cross-processed colours with heavy vignette. Expect the unexpected.',
    badgeColor: RetroColors.lomoBlue,
    icon: Icons.palette,
    filmProcess: FilmProcess.c41,
    iso: 400,
    temperature: 0.24,
    saturation: 1.60,
    contrast: 0.20,
    brightness: 0.02,
    shadowLift: 0.05,
    highlightTint: Color(0xFFFFEB3B),
    shadowTint: Color(0xFF0D47A1),
    tintStrength: 0.30,
    baseGrain: 0.24,
    coloredGrain: true,
    baseVignette: 0.58,
    redGamma: 0.87,
    greenGamma: 1.05,
    blueGamma: 0.89,
  );

  // ── Expired 1998 ──────────────────────────────────────────────────────
  // Degraded, heavy pink/magenta cast, significant base fog.
  // FIX: contrast was 0.9 → -0.08. brightness 0.05 → 0.03.
  static const expired1998 = FilmStock(
    id: 'expired_1998',
    name: 'Expired 1998',
    shortName: 'EXP 98',
    description:
        'Found in grandma\'s attic. Unpredictable colour shifts, '
        'pink casts, and beautiful accidents.',
    badgeColor: RetroColors.expiredPink,
    icon: Icons.auto_awesome,
    filmProcess: FilmProcess.c41,
    iso: 200,
    temperature: 0.32,
    saturation: 0.92,
    contrast: -0.02,
    brightness: 0.05,
    shadowLift: 0.14,
    highlightTint: Color(0xFFF48FB1),
    shadowTint: Color(0xFF880E4F),
    tintStrength: 0.32,
    baseGrain: 0.32,
    coloredGrain: true,
    baseVignette: 0.45,
    redGamma: 0.84,
    greenGamma: 1.12,
    blueGamma: 0.96,
  );

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Find a film stock by its ID. Falls back to [kodakGold200].
  static FilmStock getById(String id) {
    return all.firstWhere(
      (stock) => stock.id == id,
      orElse: () => kodakGold200,
    );
  }

  /// All stocks grouped by film process type.
  static Map<FilmProcess, List<FilmStock>> get byProcess {
    final Map<FilmProcess, List<FilmStock>> groups = {};
    for (final stock in all) {
      groups.putIfAbsent(stock.filmProcess, () => []).add(stock);
    }
    return groups;
  }
}
