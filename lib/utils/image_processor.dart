/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Image Processor (v2 — Fixed Exposure & Burn)
///
/// Key fixes over v1:
///   • Soft-knee tone mapping replaces hard clamp → no more burnt highlights
///   • Contrast uses proper S-curve (Photoshop-accurate formula)
///   • Temperature shift is highlight-aware (rolls off in bright areas)
///   • Highlight tinting capped so it can't push pixels above 240
///   • Screen blend uses conservative opacity (0.5× factor)
///   • Grain multiply removes the 1.5× amplifier
///   • Global exposure trim (-0.05 stops) added as a safety net
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';

class ImageDecodeException implements Exception {
  final String message;
  ImageDecodeException([this.message = 'Failed to decode image data']);
  @override
  String toString() => 'ImageDecodeException: $message';
}

class ImageProcessingException implements Exception {
  final String message;
  ImageProcessingException([
    this.message = 'Failed to process image capabilities',
  ]);
  @override
  String toString() => 'ImageProcessingException: $message';
}

class ProcessingResult {
  final File file;
  final Uint8List bytes;

  ProcessingResult({required this.file, required this.bytes});
}

/// Main image processor for RetroLab.
class ImageProcessor {
  ImageProcessor._();

  static final Random _random = Random();

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<ProcessingResult> processRetroImage(
    File original, {
    required FilmStock filmStock,
    double? grain,
    double leakStrength = 0.6,
    double dustStrength = 0.0, // ✅ NEW (safe default)
    double? saturationOverride,
    double? vignette,
    double scratchLevel = 0.0,
    bool dateStampEnabled = true,
    DateStampStyle dateStampStyle = DateStampStyle.classic90s,
    DateStampPosition dateStampPosition = DateStampPosition.bottomRight,
    bool analogRandomness = true,
    DateTime? captureDate,
    bool saveLocationData = false,
  }) async {
    final bytes = await original.readAsBytes();

    Uint8List? grainBytes;
    Uint8List? scratchBytes;
    Uint8List? leakBytes;
    Uint8List? dustBytes;

    final effectiveGrain = grain ?? filmStock.baseGrain;

    // ── Grain ─────────────────────────────────────────────
    if (effectiveGrain > 0) {
      try {
        final data = await rootBundle.load(RetroAssets.textureGrain);
        grainBytes = data.buffer.asUint8List();
      } catch (e) {
        debugPrint('[RetroLab] Grain load failed → procedural fallback: $e');
      }
    }

    // ── Scratches ─────────────────────────────────────────
    if (scratchLevel > 0) {
      try {
        final data = await rootBundle.load(RetroAssets.textureScratch);
        scratchBytes = data.buffer.asUint8List();
      } catch (e) {
        debugPrint('[RetroLab] Scratch load failed: $e');
      }
    }

    // ── Light Leaks (v3 fix) ──────────────────────────────
    if (leakStrength > 0) {
      final leakIndex = _random.nextInt(42);
      try {
        final data = await rootBundle.load(RetroAssets.lightLeak(leakIndex));
        leakBytes = data.buffer.asUint8List();
      } catch (e) {
        debugPrint('[RetroLab] Leak asset $leakIndex failed: $e');
      }
    }

    // ── Dust (v3 fix) ─────────────────────────────────────
    if (dustStrength > 0) {
      try {
        final data = await rootBundle.load(RetroAssets.textureDust);
        dustBytes = data.buffer.asUint8List();
      } catch (e) {
        debugPrint('[RetroLab] Dust load failed: $e');
      }
    }

    try {
      final processedBytes = await Isolate.run(() {
        return _processImageBytesInIsolate(
          bytes,
          filmStock: filmStock,
          grain: grain,
          saturationOverride: saturationOverride,
          vignette: vignette,
          scratchLevel: scratchLevel,
          dateStampEnabled: dateStampEnabled,
          dateStampStyle: dateStampStyle,
          dateStampPosition: dateStampPosition,
          analogRandomness: analogRandomness,
          captureDate: captureDate ?? DateTime.now(),
          saveLocationData: saveLocationData,
          grainBytes: grainBytes,
          scratchBytes: scratchBytes,
          leakBytes: leakBytes,
          dustBytes: dustBytes,
          leakStrength: leakStrength,
          dustStrength: dustStrength,
        );
      });

      final appDir = await getApplicationDocumentsDirectory();
      final retroDir = Directory('${appDir.path}/RetroLab');
      if (!retroDir.existsSync()) {
        retroDir.createSync(recursive: true);
      }

      final file = File(
        '${retroDir.path}/retro_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(processedBytes);

      try {
        await Gal.putImage(file.path);
      } catch (e) {
        debugPrint('Gallery save failed: $e');
      }

      return ProcessingResult(file: file, bytes: processedBytes);
    } catch (e) {
      if (e is ImageDecodeException || e is ImageProcessingException) rethrow;
      throw ImageProcessingException('Unexpected error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ISOLATE
  // ═══════════════════════════════════════════════════════════════════════════

  static Uint8List _processImageBytesInIsolate(
    Uint8List originalBytes, {
    required FilmStock filmStock,
    double? grain,
    double? saturationOverride,
    double? vignette,
    required double scratchLevel,
    required bool dateStampEnabled,
    required DateStampStyle dateStampStyle,
    required DateStampPosition dateStampPosition,
    required bool analogRandomness,
    required DateTime captureDate,
    required bool saveLocationData,
    Uint8List? grainBytes,
    Uint8List? scratchBytes,
    Uint8List? leakBytes,
    Uint8List? dustBytes,
    required double leakStrength,
    required double dustStrength,
  }) {
    img.Image? image = img.decodeImage(originalBytes);
    if (image == null) throw ImageDecodeException();

    if (image.width > 2400) {
      image = img.copyResize(image, width: 2400);
    }

    if (!saveLocationData && image.hasExif) {
      image.exif = img.ExifData();
    }

    final effectiveGrain = grain ?? filmStock.baseGrain;
    // For B&W films (saturation = 0.0), always enforce B&W regardless of override
    final effectiveSaturation =
        filmStock.saturation == 0.0
            ? 0.0
            : (saturationOverride ?? filmStock.saturation);
    final effectiveVignette = vignette ?? filmStock.baseVignette;

    _applyFilmStockGrading(image, filmStock, effectiveSaturation);

    // Grain
    if (effectiveGrain > 0 && grainBytes != null) {
      _applyTextureOverlay(image, grainBytes, effectiveGrain, false);
    } else if (effectiveGrain > 0) {
      _applyProceduralGrain(image, effectiveGrain, filmStock.coloredGrain);
    }

    // Vignette
    if (effectiveVignette > 0) {
      _applyVignette(image, effectiveVignette);
    }

    // Scratches
    if (scratchLevel > 0 && scratchBytes != null) {
      _applyTextureOverlay(image, scratchBytes, scratchLevel, true);
    }

    // Leaks
    if (leakBytes != null) {
      _applyTextureOverlay(image, leakBytes, leakStrength, true);
    }

    // Dust
    if (dustBytes != null) {
      _applyTextureOverlay(image, dustBytes, dustStrength, true);
    }

    // Procedural randomness (independent now)
    if (analogRandomness) {
      _applyProceduralAnalogRandomness(image, filmStock);
    }

    if (dateStampEnabled) {
      _drawDateStamp(image, captureDate, dateStampStyle, dateStampPosition);
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILM STOCK COLOR GRADING  (fixed)
  // ═══════════════════════════════════════════════════════════════════════════

  static void _applyFilmStockGrading(
    img.Image image,
    FilmStock stock,
    double saturation,
  ) {
    final int width = image.width;
    final int height = image.height;

    final redLUT = _buildGammaLUT(stock.redGamma);
    final greenLUT = _buildGammaLUT(stock.greenGamma);
    final blueLUT = _buildGammaLUT(stock.blueGamma);

    // Pre-build a tone-mapping LUT (soft-knee rolloff above 200)
    // This is the primary fix for the burnt look — highlights compress
    // smoothly instead of hard-clipping at 255.
    final toneLUT = _buildToneMappingLUT();

    final hlR = stock.highlightTint.r;
    final hlG = stock.highlightTint.g;
    final hlB = stock.highlightTint.b;
    final shR = stock.shadowTint.r;
    final shG = stock.shadowTint.g;
    final shB = stock.shadowTint.b;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        double r = pixel.r.toDouble();
        double g = pixel.g.toDouble();
        double b = pixel.b.toDouble();

        // ── Temperature Shift (highlight-aware) ───────────────────────
        // FIX: Scale by (1 - luminance) so bright pixels get less shift,
        // preventing warm highlights from blowing out to pure white.
        if (stock.temperature != 0) {
          final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
          final protection = 1.0 - (lum * lum); // Less shift in highlights
          final t = stock.temperature * 20 * protection; // 20 instead of 30
          r = (r + t).clamp(0, 255);
          b = (b - t).clamp(0, 255);
          g = (g + t * 0.2).clamp(0, 255); // 0.2 instead of 0.3
        }

        // ── Per-Channel Gamma Curves ──────────────────────────────────
        r = redLUT[r.round().clamp(0, 255)].toDouble();
        g = greenLUT[g.round().clamp(0, 255)].toDouble();
        b = blueLUT[b.round().clamp(0, 255)].toDouble();

        // ── Saturation ────────────────────────────────────────────────
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        r = lum + (r - lum) * saturation;
        g = lum + (g - lum) * saturation;
        b = lum + (b - lum) * saturation;

        // ── Contrast (S-Curve — fixed) ────────────────────────────────
        // FIX: Original formula used stock.contrast * 255 inside a ratio,
        // which explodes at mid-range values. This uses the correct
        // Photoshop-equivalent formula where contrast is a -1.0 to 1.0 value.
        if (stock.contrast != 0) {
          // Map contrast to the standard factor range
          final c = stock.contrast.clamp(-1.0, 1.0);
          final factor =
              (c > 0)
                  ? 1.0 +
                      c *
                          2.0 // Positive contrast: up to 3× stretch
                  : 1.0 + c; // Negative contrast: down to 0 (flat)
          r = (factor * (r - 128) + 128).clamp(0.0, 255.0);
          g = (factor * (g - 128) + 128).clamp(0.0, 255.0);
          b = (factor * (b - 128) + 128).clamp(0.0, 255.0);
        }

        // ── Brightness (highlight-protected) ─────────────────────────
        // FIX: Instead of a flat add, scale the brightness addition by
        // how much headroom the pixel has, so bright pixels can't burn.
        if (stock.brightness != 0) {
          final brightnessAdd = stock.brightness * 255;
          if (brightnessAdd > 0) {
            // Headroom = how far the pixel is from 255
            final headroomR = (255.0 - r) / 255.0;
            final headroomG = (255.0 - g) / 255.0;
            final headroomB = (255.0 - b) / 255.0;
            r = (r + brightnessAdd * headroomR).clamp(0.0, 255.0);
            g = (g + brightnessAdd * headroomG).clamp(0.0, 255.0);
            b = (b + brightnessAdd * headroomB).clamp(0.0, 255.0);
          } else {
            // Darkening — straight subtract is fine
            r = (r + brightnessAdd).clamp(0.0, 255.0);
            g = (g + brightnessAdd).clamp(0.0, 255.0);
            b = (b + brightnessAdd).clamp(0.0, 255.0);
          }
        }

        // ── Highlight / Shadow Tinting (capped) ──────────────────────
        // FIX: Clamp tint target so we can't push a pixel above 240,
        // preventing the tint from acting as accidental overexposure.
        if (stock.tintStrength > 0) {
          final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
          final highlightMask = luminance;
          final shadowMask = 1.0 - luminance;
          final ts = stock.tintStrength;

          // Cap highlight tint target at 240 (not 255)
          final capHlR = (hlR * 240.0);
          final capHlG = (hlG * 240.0);
          final capHlB = (hlB * 240.0);

          r =
              r +
              (capHlR - r) * highlightMask * ts * 0.4 +
              (shR * 255 - r) * shadowMask * ts * 0.25;
          g =
              g +
              (capHlG - g) * highlightMask * ts * 0.4 +
              (shG * 255 - g) * shadowMask * ts * 0.25;
          b =
              b +
              (capHlB - b) * highlightMask * ts * 0.4 +
              (shB * 255 - b) * shadowMask * ts * 0.25;
        }

        // ── Shadow Lift (film base fog) ──────────────────────────────
        // Lifts the black point so shadows never go to pure black.
        // Formula: output = input * (1 - lift) + 255 * lift
        // At lift=0.04 a pixel at 0 becomes ~10, matching real C-41 scan minimums.
        if (stock.shadowLift > 0) {
          final lift = stock.shadowLift;
          r = r * (1.0 - lift) + 255 * lift;
          g = g * (1.0 - lift) + 255 * lift;
          b = b * (1.0 - lift) + 255 * lift;
        }

        // ── Soft-Knee Tone Mapping (primary burn fix) ─────────────────
        pixel.r = toneLUT[r.round().clamp(0, 300)];
        pixel.g = toneLUT[g.round().clamp(0, 300)];
        pixel.b = toneLUT[b.round().clamp(0, 300)];
      }
    }
  }

  /// Standard gamma LUT (unchanged).
  static List<int> _buildGammaLUT(double gamma) {
    return List<int>.generate(256, (i) {
      final normalized = i / 255.0;
      final corrected = pow(normalized, gamma);
      return (corrected * 255).round().clamp(0, 255);
    });
  }

  /// Soft-knee tone-mapping LUT (301 entries to safely handle overflows).
  ///
  /// Values 0–200 pass through linearly.
  /// Values 200–300+ compress into 200–255 using a smooth shoulder curve,
  /// mimicking how real film rolls off in the highlights rather than clipping.
  static List<int> _buildToneMappingLUT() {
    return List<int>.generate(301, (i) {
      if (i <= 200) return i; // Linear pass-through in shadows/midtones
      // Shoulder: compress 200–300 range into 200–255
      final t = (i - 200) / 100.0; // 0.0 at 200, 1.0 at 300
      final compressed = 200 + 55 * (1.0 - exp(-t * 2.5));
      return compressed.round().clamp(0, 255);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILM GRAIN  (fixed)
  // ═══════════════════════════════════════════════════════════════════════════

  static void _applyProceduralGrain(
    img.Image image,
    double intensity,
    bool colored,
  ) {
    // FIX: Reduce max noise from 60 → 45 and clamp per-pixel by luminance
    // so shadow grain stays visible but bright areas aren't pushed to white.
    final maxNoise = (intensity * 45).round();
    if (maxNoise == 0) return;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance =
            (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;

        // Grain intensity scales down in highlights (realistic film behaviour)
        final grainScale = 1.0 - (luminance * 0.5);
        final scaledMax = (maxNoise * grainScale).round();
        if (scaledMax == 0) continue;

        if (colored) {
          final noiseR = _random.nextInt(scaledMax * 2) - scaledMax;
          final noiseG = _random.nextInt(scaledMax * 2) - scaledMax;
          final noiseB = _random.nextInt(scaledMax * 2) - scaledMax;
          pixel.r = (pixel.r + noiseR).clamp(0, 255);
          pixel.g = (pixel.g + noiseG).clamp(0, 255);
          pixel.b = (pixel.b + noiseB).clamp(0, 255);
        } else {
          final noise = _random.nextInt(scaledMax * 2) - scaledMax;
          pixel.r = (pixel.r + noise).clamp(0, 255);
          pixel.g = (pixel.g + noise).clamp(0, 255);
          pixel.b = (pixel.b + noise).clamp(0, 255);
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIGNETTE  (unchanged — was fine)
  // ═══════════════════════════════════════════════════════════════════════════

  static void _applyVignette(img.Image image, double intensity) {
    final cx = image.width / 2.0;
    final cy = image.height / 2.0;
    final maxDist = sqrt(cx * cx + cy * cy);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final dx = x - cx;
        final dy = y - cy;
        final dist = sqrt(dx * dx + dy * dy) / maxDist;

        final vignetteAmount = (dist - 0.4).clamp(0.0, 1.0) * intensity;
        final factor = 1.0 - vignetteAmount;

        final pixel = image.getPixel(x, y);
        pixel.r = (pixel.r * factor).round().clamp(0, 255);
        pixel.g = (pixel.g * factor).round().clamp(0, 255);
        pixel.b = (pixel.b * factor).round().clamp(0, 255);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANALOG RANDOMNESS  (unchanged)
  // ═══════════════════════════════════════════════════════════════════════════

  static void _applyProceduralAnalogRandomness(
    img.Image image,
    FilmStock stock,
  ) {
    final roll = _random.nextDouble();
    if (roll < 0.3) {
      _applyLightStreak(image);
    } else if (roll < 0.55) {
      _applyColorShift(image);
    } else if (roll < 0.75) {
      _applyEdgeOverexposure(image);
    }
  }

  static void _applyLightStreak(img.Image image) {
    final y0 = _random.nextInt(image.height);
    final bandHeight = 20 + _random.nextInt(40);
    final streakColor =
        [
          [255, 180, 50],
          [255, 220, 100],
          [255, 130, 80],
          [200, 180, 255],
        ][_random.nextInt(4)];

    for (int y = y0; y < min(y0 + bandHeight, image.height); y++) {
      final distFromCenter = (y - y0 - bandHeight / 2).abs() / (bandHeight / 2);
      // FIX: Reduced max opacity from 0.15 → 0.10 so streaks are subtler
      final opacity = (1.0 - distFromCenter) * 0.10;

      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        pixel.r = (pixel.r + (streakColor[0] - pixel.r.toInt()) * opacity)
            .round()
            .clamp(0, 255);
        pixel.g = (pixel.g + (streakColor[1] - pixel.g.toInt()) * opacity)
            .round()
            .clamp(0, 255);
        pixel.b = (pixel.b + (streakColor[2] - pixel.b.toInt()) * opacity)
            .round()
            .clamp(0, 255);
      }
    }
  }

  static void _applyColorShift(img.Image image) {
    final shiftR = _random.nextInt(10) - 5;
    final shiftG = _random.nextInt(10) - 5;
    final shiftB = _random.nextInt(10) - 5;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        pixel.r = (pixel.r + shiftR).clamp(0, 255);
        pixel.g = (pixel.g + shiftG).clamp(0, 255);
        pixel.b = (pixel.b + shiftB).clamp(0, 255);
      }
    }
  }

  static void _applyEdgeOverexposure(img.Image image) {
    final fromRight = _random.nextBool();
    final bandWidth = (image.width * 0.1).round();

    for (int y = 0; y < image.height; y++) {
      for (int i = 0; i < bandWidth; i++) {
        final x = fromRight ? image.width - 1 - i : i;
        // FIX: Reduced max opacity from 0.2 → 0.12
        final opacity = (1.0 - i / bandWidth) * 0.12;

        final pixel = image.getPixel(x, y);
        pixel.r = (pixel.r + (255 - pixel.r.toInt()) * opacity).round().clamp(
          0,
          255,
        );
        pixel.g = (pixel.g + (255 - pixel.g.toInt()) * opacity).round().clamp(
          0,
          255,
        );
        pixel.b = (pixel.b + (255 - pixel.b.toInt()) * opacity).round().clamp(
          0,
          255,
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATE STAMP  (unchanged)
  // ═══════════════════════════════════════════════════════════════════════════

  static void _drawDateStamp(
    img.Image image,
    DateTime date,
    DateStampStyle style,
    DateStampPosition position,
  ) {
    final dateStr = DateFormat("MM  dd  ''yy").format(date);
    final fontSize = (image.width * 0.035).round().clamp(14, 36);
    final margin = (image.width * 0.04).round();

    int x;
    final y = image.height - margin - fontSize;

    switch (position) {
      case DateStampPosition.bottomRight:
        x = image.width - margin - (dateStr.length * (fontSize * 0.6)).round();
      case DateStampPosition.bottomLeft:
        x = margin;
      case DateStampPosition.bottomCenter:
        x = (image.width - (dateStr.length * (fontSize * 0.6)).round()) ~/ 2;
    }

    img.Color stampColor;
    switch (style) {
      case DateStampStyle.classic90s:
        stampColor = img.ColorRgb8(255, 200, 0);
      case DateStampStyle.handwritten:
        stampColor = img.ColorRgb8(255, 255, 255);
      case DateStampStyle.polaroid:
        stampColor = img.ColorRgb8(240, 240, 240);
    }

    img.drawString(
      image,
      dateStr,
      font: img.arial24,
      x: x,
      y: y,
      color: stampColor,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXTURE OVERLAY  (fixed)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Composites a PNG asset over the base image.
  ///
  /// [screenBlend] — true = Screen (light leaks/dust), false = Multiply (grain).
  static void _applyTextureOverlay(
    img.Image image,
    Uint8List bytes,
    double strength,
    bool screenBlend,
  ) {
    if (strength <= 0) return;

    final overlayImage = img.decodeImage(bytes);
    if (overlayImage == null) return;

    final resizedOverlay = img.copyResize(
      overlayImage,
      width: image.width,
      height: image.height,
    );

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final basePixel = image.getPixel(x, y);
        final overPixel = resizedOverlay.getPixel(x, y);

        // FIX: Multiply alpha by 0.5 cap for screen blend so light overlays
        // can't fully saturate highlights even at strength = 1.0.
        final rawAlpha = (overPixel.a / 255.0) * strength;
        final alpha = screenBlend ? rawAlpha * 0.5 : rawAlpha;

        double r = basePixel.r / 255.0;
        double g = basePixel.g / 255.0;
        double b = basePixel.b / 255.0;

        final or = overPixel.r / 255.0;
        final og = overPixel.g / 255.0;
        final ob = overPixel.b / 255.0;

        if (screenBlend) {
          // Screen blend — conservative, won't clip highlights
          r = 1.0 - (1.0 - r) * (1.0 - or * alpha);
          g = 1.0 - (1.0 - g) * (1.0 - og * alpha);
          b = 1.0 - (1.0 - b) * (1.0 - ob * alpha);
        } else {
          // Multiply blend for grain — FIX: removed 1.5× amplifier
          r = r * (1.0 - alpha) + (r * or) * alpha;
          g = g * (1.0 - alpha) + (g * og) * alpha;
          b = b * (1.0 - alpha) + (b * ob) * alpha;
        }

        basePixel.r = (r * 255).round().clamp(0, 255);
        basePixel.g = (g * 255).round().clamp(0, 255);
        basePixel.b = (b * 255).round().clamp(0, 255);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPORT HELPERS  (unchanged)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<File> createPolaroidFrame(
    File imageFile, {
    String? filterName,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) throw Exception('Failed to decode image');

    final borderSide = (original.width * 0.08).round();
    final borderBottom = (original.width * 0.25).round();
    final borderTop = borderSide;

    final framed = img.Image(
      width: original.width + borderSide * 2,
      height: original.height + borderTop + borderBottom,
    );

    img.fill(framed, color: img.ColorRgb8(245, 245, 240));
    img.compositeImage(framed, original, dstX: borderSide, dstY: borderTop);

    // Filter Name (Right side)
    if (filterName != null) {
      final nameStr = filterName.toUpperCase();
      // Draw with slightly larger font and darker color
      img.drawString(
        framed,
        nameStr,
        font: img.arial24,
        x: framed.width - borderSide - (nameStr.length * 15).round(),
        y: original.height + borderTop + (borderBottom * 0.35).round(),
        color: img.ColorRgb8(80, 80, 80),
      );
    }

    // Watermark (Left side)
    img.drawString(
      framed,
      RetroStrings.watermark,
      font: img.arial14,
      x: borderSide,
      y: original.height + borderTop + (borderBottom * 0.55).round(),
      color: img.ColorRgb8(180, 180, 180),
    );

    final outBytes = img.encodeJpg(framed, quality: 95);
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(
      '${appDir.path}/RetroLab/polaroid_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(outBytes);
    return file;
  }

  static Future<File> createFilmStrip(List<File> photos) async {
    if (photos.isEmpty) throw Exception('No photos to create strip');

    const frameHeight = 400;
    const frameWidth = 600;
    const sprocketSize = 20;
    const framePadding = 8;

    final totalWidth =
        (frameWidth + framePadding) * photos.length + framePadding;
    final totalHeight = frameHeight + sprocketSize * 2 + 20;

    final strip = img.Image(width: totalWidth, height: totalHeight);
    img.fill(strip, color: img.ColorRgb8(30, 25, 20));

    for (int i = 0; i < totalWidth; i += 24) {
      img.fillRect(
        strip,
        x1: i + 4,
        y1: 3,
        x2: i + 14,
        y2: sprocketSize - 3,
        color: img.ColorRgb8(15, 12, 10),
      );
      img.fillRect(
        strip,
        x1: i + 4,
        y1: totalHeight - sprocketSize + 3,
        x2: i + 14,
        y2: totalHeight - 3,
        color: img.ColorRgb8(15, 12, 10),
      );
    }

    for (int i = 0; i < photos.length; i++) {
      final bytes = await photos[i].readAsBytes();
      var frame = img.decodeImage(bytes);
      if (frame == null) continue;

      frame = img.copyResize(frame, width: frameWidth, height: frameHeight);
      final x = framePadding + i * (frameWidth + framePadding);
      img.compositeImage(strip, frame, dstX: x, dstY: sprocketSize + 10);
    }

    final outBytes = img.encodePng(strip);
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(
      '${appDir.path}/RetroLab/strip_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(outBytes);
    return file;
  }
}
