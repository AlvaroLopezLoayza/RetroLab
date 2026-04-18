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
  // Warm golden highlights, slightly boosted reds, fine grain.
  // FIX: contrast was 1.05 (old multiplier) → 0.03 (subtle S-curve boost).
  static const kodakGold200 = FilmStock(
    id: 'kodak_gold_200',
    name: 'Kodak Gold 200',
    shortName: 'GOLD 200',
    description:
        'Warm golden tones with rich skin colours. The definitive summer film.',
    badgeColor: RetroColors.kodakYellow,
    icon: Icons.wb_sunny,
    filmProcess: FilmProcess.c41,
    iso: 200,
    temperature: 0.28,
    saturation: 1.12,
    contrast: 0.03, // was 1.05 — subtle warmth lift, not a hard push
    brightness: 0.02,
    shadowLift: 0.04, // slight milky lift in shadows
    highlightTint: Color(0xFFFFE082),
    shadowTint: Color(0xFF4E342E),
    tintStrength: 0.14,
    baseGrain: 0.10, // ISO 200 = tighter grain than 400
    coloredGrain: true,
    baseVignette: 0.25,
    redGamma: 0.91, // boost reds for warmth
    greenGamma: 0.98,
    blueGamma: 1.10, // roll off blue to reduce coolness
  );

  // ── Kodak Ultramax 400 ────────────────────────────────────────────────
  // The everyday consumer workhorse. Slightly warmer and punchier than Gold.
  // Visible grain, strong contrast, great colour separation.
  static const kodakUltramax400 = FilmStock(
    id: 'kodak_ultramax_400',
    name: 'Kodak Ultramax 400',
    shortName: 'UMAX 400',
    description: 'Punchy and versatile. Strong colour separation with a '
        'slight warm bias. The original point-and-shoot staple.',
    badgeColor: Color(0xFFE65100),
    icon: Icons.filter_vintage,
    filmProcess: FilmProcess.c41,
    iso: 400,
    temperature: 0.22,
    saturation: 1.10,
    contrast: 0.07,
    brightness: 0.01,
    shadowLift: 0.03,
    highlightTint: Color(0xFFFFCC80),
    shadowTint: Color(0xFF3E2723),
    tintStrength: 0.12,
    baseGrain: 0.15,
    coloredGrain: true,
    baseVignette: 0.28,
    redGamma: 0.93,
    greenGamma: 0.99,
    blueGamma: 1.07,
  );

  // ── Kodak Portra 400 ──────────────────────────────────────────────────
  // The professional portrait standard. Pastel, skin-flattering, wide latitude.
  // Low contrast, lifted shadows, natural warmth — NOT punchy.
  static const kodakPortra400 = FilmStock(
    id: 'kodak_portra_400',
    name: 'Kodak Portra 400',
    shortName: 'PORTRA',
    description: 'The professional portrait standard. Pastel highlights, '
        'flattering skin tones, and extraordinary latitude.',
    badgeColor: Color(0xFFBCAAA4),
    icon: Icons.face,
    filmProcess: FilmProcess.c41,
    iso: 400,
    temperature: 0.14,
    saturation: 0.88, // intentionally desaturated — Portra is not vivid
    contrast: -0.04, // deliberately soft / low contrast
    brightness: 0.02,
    shadowLift: 0.06, // lifted blacks — very characteristic of Portra
    highlightTint: Color(0xFFFFE0B2), // peach
    shadowTint: Color(0xFF37474F), // cool blue-grey shadows
    tintStrength: 0.16,
    baseGrain: 0.13,
    coloredGrain: true,
    baseVignette: 0.20,
    redGamma: 0.93, // warm reds
    greenGamma: 0.97,
    blueGamma: 1.05, // slightly muted blue
  );

  // ── Kodak Ektar 100 ───────────────────────────────────────────────────
  // The most vivid consumer negative film ever made.
  // Ultra-fine grain, punchy saturation, deep reds.
  static const kodakEktar100 = FilmStock(
    id: 'kodak_ektar_100',
    name: 'Kodak Ektar 100',
    shortName: 'EKTAR',
    description: 'Ultra-vivid landscape film with the finest grain of any '
        'colour negative. Reds are extraordinary.',
    badgeColor: Color(0xFFC62828),
    icon: Icons.landscape,
    filmProcess: FilmProcess.c41,
    iso: 100,
    temperature: 0.18,
    saturation: 1.28,
    contrast: 0.10,
    brightness: 0.01,
    shadowLift: 0.02, // very small lift — Ektar has deep blacks
    highlightTint: Color(0xFFFFAB91),
    shadowTint: Color(0xFF1A237E),
    tintStrength: 0.10,
    baseGrain: 0.06, // ISO 100 — very fine
    coloredGrain: true,
    baseVignette: 0.22,
    redGamma: 0.88, // strong red boost
    greenGamma: 0.97,
    blueGamma: 1.06,
  );

  // ── Fuji Superia 400 ──────────────────────────────────────────────────
  // Cool greens, natural skin tones, slightly muted palette.
  // FIX: contrast was 1.1 → 0.07; tightened temperature from -0.1 → -0.08.
  static const fujiSuperia400 = FilmStock(
    id: 'fuji_superia_400',
    name: 'Fuji Superia 400',
    shortName: 'SUPERIA',
    description:
        'Cool green tones with natural colours. Perfect for everyday memories.',
    badgeColor: RetroColors.fujiGreen,
    icon: Icons.eco,
    filmProcess: FilmProcess.c41,
    iso: 400,
    temperature: -0.08,
    saturation: 0.95,
    contrast: 0.07, // was 1.1
    brightness: 0.0,
    shadowLift: 0.03,
    highlightTint: Color(0xFFDCEDC8), // pale green tint in highlights
    shadowTint: Color(0xFF1B5E20),
    tintStrength: 0.11,
    baseGrain: 0.15,
    coloredGrain: true,
    baseVignette: 0.30,
    redGamma: 1.05,
    greenGamma: 0.92, // enhanced green channel
    blueGamma: 1.0,
  );

  // ── Agfa Vista 200 ────────────────────────────────────────────────────
  // Warm pinks and purples, slightly faded, beloved for its accidental beauty.
  static const agfaVista200 = FilmStock(
    id: 'agfa_vista_200',
    name: 'Agfa Vista 200',
    shortName: 'VISTA',
    description: 'Pink and purple casts with a warm glow. '
        'Discontinued but never forgotten.',
    badgeColor: Color(0xFFAD1457),
    icon: Icons.favorite,
    filmProcess: FilmProcess.c41,
    iso: 200,
    temperature: 0.12,
    saturation: 0.92,
    contrast: 0.02,
    brightness: 0.03,
    shadowLift: 0.05,
    highlightTint: Color(0xFFF8BBD9), // pink highlights
    shadowTint: Color(0xFF6A1B9A), // purple shadows
    tintStrength: 0.20,
    baseGrain: 0.11,
    coloredGrain: true,
    baseVignette: 0.28,
    redGamma: 0.90,
    greenGamma: 1.03,
    blueGamma: 0.94, // slight magenta push
  );

  // ── Fuji Velvia 50 ────────────────────────────────────────────────────
  // Slide (reversal) film. Legendary for landscape photography.
  // Ultra-saturated, punchy contrast, deep blacks, NO shadow lift.
  // E-6 process means no film base fog — blacks are true black.
  static const fujiVelvia50 = FilmStock(
    id: 'fuji_velvia_50',
    name: 'Fuji Velvia 50',
    shortName: 'VELVIA',
    description: 'The landscape photographer\'s weapon. Hyper-saturated colours, '
        'punchy contrast, with greens and blues that glow.',
    badgeColor: Color(0xFF00838F),
    icon: Icons.filter_hdr,
    filmProcess: FilmProcess.e6,
    iso: 50,
    temperature: 0.05,
    saturation: 1.42,
    contrast: 0.18, // slide film is inherently high contrast
    brightness: -0.02, // slightly darker — Velvia holds shadows
    shadowLift: 0.0, // E-6/slide film: NO base fog, true blacks
    highlightTint: Color(0xFFFFF9C4), // barely-there warm shimmer
    shadowTint: Color(0xFF0D47A1),
    tintStrength: 0.08,
    baseGrain: 0.05, // ISO 50 — almost invisible grain
    coloredGrain: false,
    baseVignette: 0.20,
    redGamma: 0.94,
    greenGamma: 0.88, // strong green boost
    blueGamma: 0.90, // strong blue/cyan boost
  );

  // ── Ilford HP5 Plus ───────────────────────────────────────────────────
  // Classic B&W with rich tonal range.
  // FIX: contrast was 1.25 (old multiplier) → 0.14 (S-curve).
  static const ilfordHP5 = FilmStock(
    id: 'ilford_hp5',
    name: 'Ilford HP5 Plus',
    shortName: 'HP5 B&W',
    description: 'Legendary B&W film. Deep contrast with creamy mid-tones '
        'and expressive grain.',
    badgeColor: RetroColors.ilfordWhite,
    icon: Icons.contrast,
    filmProcess: FilmProcess.blackAndWhite,
    iso: 400,
    temperature: 0.0,
    saturation: 0.0, // B&W
    contrast: 0.14, // was 1.25
    brightness: 0.01,
    shadowLift: 0.04, // slight zone-system lift
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

  // ── CineStill 800T ────────────────────────────────────────────────────
  // Kodak Vision 500T motion picture film respooled for stills.
  // Tungsten-balanced (very blue at daylight), heavy halation, cinema grain.
  // The remjet layer is removed, causing the characteristic red halation glow
  // around bright light sources — emulated here via highlight tinting.
  static const cineStill800T = FilmStock(
    id: 'cinestill_800t',
    name: 'CineStill 800T',
    shortName: 'CS 800T',
    description: 'Kodak cinema film respooled for still cameras. '
        'Tungsten blue tones, red halation, and cinematic grain.',
    badgeColor: Color(0xFF1565C0),
    icon: Icons.movie,
    filmProcess: FilmProcess.cinematic,
    iso: 800,
    temperature: -0.32, // very cool / tungsten-balanced
    saturation: 1.05,
    contrast: 0.07,
    brightness: 0.02,
    shadowLift: 0.05,
    highlightTint: Color(0xFFFF5252), // RED halation — the signature look
    shadowTint: Color(0xFF0D47A1), // deep blue shadows
    tintStrength: 0.22, // halation needs to be visible
    baseGrain: 0.22, // ISO 800 motion picture grain
    coloredGrain: true,
    baseVignette: 0.30,
    redGamma: 1.04, // halation adds reds back in highlights via tint
    greenGamma: 1.0,
    blueGamma: 0.86, // strong blue channel boost (tungsten)
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
    temperature: 0.05,
    saturation: 0.78,
    contrast: -0.12, // was 0.85 — flat/matte look
    brightness: 0.05, // was 0.08 — less burning
    shadowLift: 0.09, // heavy lift — instant film has significant base density
    highlightTint: Color(0xFFF3E5F5),
    shadowTint: Color(0xFF283593),
    tintStrength: 0.17,
    baseGrain: 0.10,
    coloredGrain: true,
    baseVignette: 0.20,
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
    temperature: 0.14,
    saturation: 1.38,
    contrast: 0.13, // was 1.2
    brightness: 0.0,
    shadowLift: 0.02,
    highlightTint: Color(0xFFFFEB3B),
    shadowTint: Color(0xFF0D47A1),
    tintStrength: 0.20,
    baseGrain: 0.18,
    coloredGrain: true,
    baseVignette: 0.48, // heavy — very characteristic of Lomo
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
    description: 'Found in grandma\'s attic. Unpredictable colour shifts, '
        'pink casts, and beautiful accidents.',
    badgeColor: RetroColors.expiredPink,
    icon: Icons.auto_awesome,
    filmProcess: FilmProcess.c41,
    iso: 200,
    temperature: 0.22,
    saturation: 0.72,
    contrast: -0.08, // was 0.9 — slightly flat from age
    brightness: 0.03, // was 0.05 — subtle
    shadowLift: 0.12, // heavy fog — expired film loses shadow density
    highlightTint: Color(0xFFF48FB1),
    shadowTint: Color(0xFF880E4F),
    tintStrength: 0.24,
    baseGrain: 0.26, // degradation adds visible grain
    coloredGrain: true,
    baseVignette: 0.35,
    redGamma: 0.84, // magenta push via boosted red
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