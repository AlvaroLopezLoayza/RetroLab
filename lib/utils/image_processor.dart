/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Image Processor
///
/// The heart of RetroLab. Applies analog film effects to digital photos:
///   1. Film stock color grading (temperature, saturation, contrast, curves)
///   2. Realistic film grain (monochrome + colored noise)
///   3. Random light leak overlays
///   4. Vignette + optional scratches
///   5. Date stamp with selectable style & position
///   6. Analog "randomness" defects (color shifts, dust, overexposure)
///
/// Uses the `image` package for pixel-level manipulation.
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
  @override String toString() => 'ImageDecodeException: $message';
}

class ImageProcessingException implements Exception {
  final String message;
  ImageProcessingException([this.message = 'Failed to process image capabilities']);
  @override String toString() => 'ImageProcessingException: $message';
}

/// Result of image processing — contains both the file and raw bytes.
class ProcessingResult {
  final File file;
  final Uint8List bytes;

  ProcessingResult({required this.file, required this.bytes});
}

/// Main image processor for RetroLab.
///
/// Usage:
/// ```dart
/// final result = await ImageProcessor.processRetroImage(
///   originalFile,
///   filmStock: FilmStocks.kodakGold200,
///   grain: 0.18,
///   leakStrength: 0.6,
///   vignette: 0.3,
///   dateStampEnabled: true,
/// );
/// ```
class ImageProcessor {
  ImageProcessor._();

  static final Random _random = Random();

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Process an image with full retro film effects.
  ///
  /// [original] — The source image file.
  /// [filmStock] — The film stock preset to apply.
  /// [grain] — Grain intensity override (0.0–1.0). Uses filmStock default if null.
  /// [leakStrength] — Light leak overlay opacity (0.0–1.0).
  /// [saturationOverride] — Saturation multiplier override. Uses filmStock default if null.
  /// [vignette] — Vignette intensity override (0.0–1.0).
  /// [scratchLevel] — Scratch overlay intensity (0.0–1.0).
  /// [dateStampEnabled] — Whether to render a date stamp.
  /// [dateStampStyle] — Style of the date stamp.
  /// [dateStampPosition] — Position of the date stamp.
  /// [analogRandomness] — Add random analog defects (light streaks, color shifts, dust).
  /// [captureDate] — Date to show on the stamp (defaults to now).
  static Future<ProcessingResult> processRetroImage(
    File original, {
    required FilmStock filmStock,
    double? grain,
    double leakStrength = 0.6,
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
    // Read original image
    final bytes = await original.readAsBytes();

    Uint8List? grainBytes;
    Uint8List? scratchBytes;
    Uint8List? leakBytes;
    Uint8List? dustBytes;

    // Load authentic assets before jumping into the background isolate
    final effectiveGrain = grain ?? filmStock.baseGrain;
    if (effectiveGrain > 0) {
      try {
        final data = await rootBundle.load(RetroAssets.textureGrain);
        grainBytes = data.buffer.asUint8List();
      } catch (_) {}
    }

    if (scratchLevel > 0) {
      try {
        final data = await rootBundle.load(RetroAssets.textureScratch);
        scratchBytes = data.buffer.asUint8List();
      } catch (_) {}
    }

    if (analogRandomness) {
      final roll = Random().nextDouble();
      if (roll < 0.3) {
         final leakIndex = Random().nextInt(10) + 1;
         try {
           final data = await rootBundle.load(RetroAssets.lightLeak(leakIndex));
           leakBytes = data.buffer.asUint8List();
         } catch (_) {}
      } else if (roll < 0.55) {
         try {
           final data = await rootBundle.load(RetroAssets.textureDust);
           dustBytes = data.buffer.asUint8List();
         } catch (_) {}
      }
    }

    try {
      // Offload all heavy computation to a background isolate
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
        );
      });

      // Save to app documents
      final appDir = await getApplicationDocumentsDirectory();
      final retroDir = Directory('${appDir.path}/RetroLab');
      if (!retroDir.existsSync()) {
        retroDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFile = File('${retroDir.path}/retro_$timestamp.jpg');
      await outputFile.writeAsBytes(processedBytes);

      try {
        await Gal.putImage(outputFile.path);
      } catch (e) {
        debugPrint('Failed to save to gallery: $e');
      }

      return ProcessingResult(file: outputFile, bytes: processedBytes);
    } catch (e) {
      if (e is ImageDecodeException || e is ImageProcessingException) {
        rethrow;
      }
      throw ImageProcessingException('Unexpected error during processing: $e');
    }
  }

  /// The internal pixel manipulation engine to be run in a background isolate
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
  }) {
    img.Image? image = img.decodeImage(originalBytes);
    if (image == null) {
      throw ImageDecodeException('Format potentially unsupported or file corrupted');
    }

    // Ensure reasonable size for processing performance
    if (image.width > 2400) {
      image = img.copyResize(image, width: 2400);
    }

    // Strip EXIF data if privacy setting is disabled
    if (!saveLocationData) {
      if (image.hasExif) {
        image.exif = img.ExifData();
      }
    }

    final effectiveGrain = grain ?? filmStock.baseGrain;
    final effectiveSaturation = saturationOverride ?? filmStock.saturation;
    final effectiveVignette = vignette ?? filmStock.baseVignette;

    // ── Step 1: Apply Film Stock Color Grading ─────────────────────────
    _applyFilmStockGrading(image, filmStock, effectiveSaturation);

    // ── Step 2: Apply Authentic PNG Assets ───────────────────────────
    if (effectiveGrain > 0 && grainBytes != null) {
      _applyTextureOverlay(image, grainBytes, effectiveGrain, false);
    } else if (effectiveGrain > 0) {
      _applyProceduralGrain(image, effectiveGrain, filmStock.coloredGrain);
    }

    if (effectiveVignette > 0) {
      _applyVignette(image, effectiveVignette);
    }

    if (scratchLevel > 0 && scratchBytes != null) {
      _applyTextureOverlay(image, scratchBytes, scratchLevel, true);
    }

    if (leakBytes != null) {
      _applyTextureOverlay(image, leakBytes, leakStrength, true);
    }

    if (dustBytes != null) {
      _applyTextureOverlay(image, dustBytes, 0.4, true);
    }

    // Fallback to procedural randomness if assets weren't provided but requested
    if (analogRandomness && leakBytes == null && dustBytes == null) {
      _applyProceduralAnalogRandomness(image, filmStock);
    }

    // ── Step 6: Draw Date Stamp ───────────────────────────────────────
    if (dateStampEnabled) {
      _drawDateStamp(
        image,
        captureDate,
        dateStampStyle,
        dateStampPosition,
      );
    }

    // ── Step 7: Encode ─────────────────────────────────────────
    return Uint8List.fromList(
      img.encodeJpg(image, quality: 92),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILM STOCK COLOR GRADING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Applies the film stock's color characteristics to the image.
  ///
  /// This includes:
  /// - Temperature (warm/cool shift)
  /// - Saturation adjustment
  /// - Contrast adjustment
  /// - Brightness offset
  /// - Per-channel gamma curves
  /// - Highlight and shadow tinting
  static void _applyFilmStockGrading(
    img.Image image,
    FilmStock stock,
    double saturation,
  ) {
    final int width = image.width;
    final int height = image.height;

    // Pre-calculate gamma lookup tables for speed
    final redLUT = _buildGammaLUT(stock.redGamma);
    final greenLUT = _buildGammaLUT(stock.greenGamma);
    final blueLUT = _buildGammaLUT(stock.blueGamma);

    // Pre-extract tint colors
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

        // ── Temperature Shift ─────────────────────────────────────────
        // Warm = add red/yellow, Cool = add blue
        if (stock.temperature != 0) {
          final t = stock.temperature * 30; // Scale to pixel range
          r = (r + t).clamp(0, 255);
          b = (b - t).clamp(0, 255);
          g = (g + t * 0.3).clamp(0, 255); // Slight green shift for warmth
        }

        // ── Apply Per-Channel Gamma Curves ────────────────────────────
        r = redLUT[r.round().clamp(0, 255)].toDouble();
        g = greenLUT[g.round().clamp(0, 255)].toDouble();
        b = blueLUT[b.round().clamp(0, 255)].toDouble();

        // ── Saturation ────────────────────────────────────────────────
        // Convert to luminance and interpolate
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        r = lum + (r - lum) * saturation;
        g = lum + (g - lum) * saturation;
        b = lum + (b - lum) * saturation;

        // ── Contrast ──────────────────────────────────────────────────
        final factor = (259 * (stock.contrast * 255 + 255)) /
            (255 * (259 - stock.contrast * 255));
        r = factor * (r - 128) + 128;
        g = factor * (g - 128) + 128;
        b = factor * (b - 128) + 128;

        // ── Brightness ────────────────────────────────────────────────
        r += stock.brightness * 255;
        g += stock.brightness * 255;
        b += stock.brightness * 255;

        // ── Highlight / Shadow Tinting ────────────────────────────────
        if (stock.tintStrength > 0) {
          final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
          final highlightMask = luminance; // brighter = more highlight tint
          final shadowMask = 1.0 - luminance; // darker = more shadow tint
          final ts = stock.tintStrength;

          r = r +
              (hlR * 255 - r) * highlightMask * ts * 0.5 +
              (shR * 255 - r) * shadowMask * ts * 0.3;
          g = g +
              (hlG * 255 - g) * highlightMask * ts * 0.5 +
              (shG * 255 - g) * shadowMask * ts * 0.3;
          b = b +
              (hlB * 255 - b) * highlightMask * ts * 0.5 +
              (shB * 255 - b) * shadowMask * ts * 0.3;
        }

        // ── Clamp & Set ──────────────────────────────────────────────
        pixel.r = r.round().clamp(0, 255);
        pixel.g = g.round().clamp(0, 255);
        pixel.b = b.round().clamp(0, 255);
      }
    }
  }

  /// Build a gamma look-up table (256 entries) for fast per-channel correction.
  static List<int> _buildGammaLUT(double gamma) {
    return List<int>.generate(256, (i) {
      final normalized = i / 255.0;
      final corrected = pow(normalized, gamma);
      return (corrected * 255).round().clamp(0, 255);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILM GRAIN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Adds realistic film grain to the image.
  ///
  /// [intensity] — How visible the grain is (0.0–1.0).
  /// [colored] — If true, adds slight color variation to grain (like real color film).
  /// If false, pure luminance noise (like B&W film).
  static void _applyProceduralGrain(img.Image image, double intensity, bool colored) {
    final maxNoise = (intensity * 60).round(); // Max ±pixel deviation
    if (maxNoise == 0) return;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);

        if (colored) {
          // Colored grain: independent noise per channel (like color negative film)
          final noiseR = _random.nextInt(maxNoise * 2) - maxNoise;
          final noiseG = _random.nextInt(maxNoise * 2) - maxNoise;
          final noiseB = _random.nextInt(maxNoise * 2) - maxNoise;
          pixel.r = (pixel.r + noiseR).clamp(0, 255);
          pixel.g = (pixel.g + noiseG).clamp(0, 255);
          pixel.b = (pixel.b + noiseB).clamp(0, 255);
        } else {
          // Monochrome grain: same noise across channels (like B&W film)
          final noise = _random.nextInt(maxNoise * 2) - maxNoise;
          pixel.r = (pixel.r + noise).clamp(0, 255);
          pixel.g = (pixel.g + noise).clamp(0, 255);
          pixel.b = (pixel.b + noise).clamp(0, 255);
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIGNETTE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Applies a radial vignette (darkening at edges).
  ///
  /// Uses distance from center to compute a smooth falloff.
  static void _applyVignette(img.Image image, double intensity) {
    final cx = image.width / 2.0;
    final cy = image.height / 2.0;
    final maxDist = sqrt(cx * cx + cy * cy);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final dx = x - cx;
        final dy = y - cy;
        final dist = sqrt(dx * dx + dy * dy) / maxDist;

        // Smooth vignette curve: starts at ~60% radius
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
  // ANALOG RANDOMNESS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Applies random subtle analog defects for uniqueness.
  ///
  /// Possible effects (randomly chosen):
  /// - Light streak (horizontal bright band)
  /// - Color shift (slight global hue shift)
  /// - Slight overexposure on one edge
  static void _applyProceduralAnalogRandomness(img.Image image, FilmStock stock) {
    final roll = _random.nextDouble();

    // 30% chance of a light streak
    if (roll < 0.3) {
      _applyLightStreak(image);
    }
    // 25% chance of subtle color shift
    else if (roll < 0.55) {
      _applyColorShift(image);
    }
    // 20% chance of edge overexposure
    else if (roll < 0.75) {
      _applyEdgeOverexposure(image);
    }
    // 25% chance of no additional defect (photo is clean)
  }

  /// Draws a horizontal light streak (like light leaking from film gate).
  static void _applyLightStreak(img.Image image) {
    final y0 = _random.nextInt(image.height);
    final bandHeight = 20 + _random.nextInt(40);
    final streakColor = [
      [255, 180, 50], // Orange
      [255, 220, 100], // Yellow
      [255, 130, 80], // Warm red
      [200, 180, 255], // Cool blue
    ][_random.nextInt(4)];

    for (int y = y0; y < min(y0 + bandHeight, image.height); y++) {
      final distFromCenter = (y - y0 - bandHeight / 2).abs() / (bandHeight / 2);
      final opacity = (1.0 - distFromCenter) * 0.15;

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

  /// Applies a subtle global color shift (like an aged or poorly stored film).
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

  /// Overexposes one edge of the image (like light leaking from casette).
  static void _applyEdgeOverexposure(img.Image image) {
    final fromRight = _random.nextBool();
    final bandWidth = (image.width * 0.1).round();

    for (int y = 0; y < image.height; y++) {
      for (int i = 0; i < bandWidth; i++) {
        final x = fromRight ? image.width - 1 - i : i;
        final opacity = (1.0 - i / bandWidth) * 0.2;

        final pixel = image.getPixel(x, y);
        pixel.r = (pixel.r + (255 - pixel.r.toInt()) * opacity)
            .round()
            .clamp(0, 255);
        pixel.g = (pixel.g + (255 - pixel.g.toInt()) * opacity)
            .round()
            .clamp(0, 255);
        pixel.b = (pixel.b + (255 - pixel.b.toInt()) * opacity)
            .round()
            .clamp(0, 255);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATE STAMP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Draws a date stamp on the image.
  ///
  /// Supports three styles:
  /// - **Classic 90s**: Yellow/orange digital font like disposable cameras.
  /// - **Handwritten**: Casual italic script style.
  /// - **Polaroid**: Clean white text with subtle shadow.
  static void _drawDateStamp(
    img.Image image,
    DateTime date,
    DateStampStyle style,
    DateStampPosition position,
  ) {
    final dateStr = DateFormat("MM  dd  ''yy").format(date);

    // Determine position
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

    // Choose color based on style
    img.Color stampColor;
    switch (style) {
      case DateStampStyle.classic90s:
        stampColor = img.ColorRgb8(255, 200, 0); // Yellow-orange
      case DateStampStyle.handwritten:
        stampColor = img.ColorRgb8(255, 255, 255); // White
      case DateStampStyle.polaroid:
        stampColor = img.ColorRgb8(240, 240, 240); // Off-white
    }

    // Draw the date text
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
  // LIGHT LEAK OVERLAY (from asset PNGs)
  // ═══════════════════════════════════════════════════════════════════════════



  // ═══════════════════════════════════════════════════════════════════════════
  // AUTHENTIC ASSET COMPOSITION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Composites a physical PNG byte buffer over the base image.
  /// 
  /// [bytes] - Raw bytes of the asset loaded via rootBundle.
  /// [strength] - Opacity/Intensity of the blend (0.0 to 1.0).
  /// [screenBlend] - If true, uses additive Screen blending (Light Leaks/Dust). If false, uses Multiply (Grain).
  static void _applyTextureOverlay(img.Image image, Uint8List bytes, double strength, bool screenBlend) {
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
        
        final alpha = (overPixel.a / 255.0) * strength;

        double r = basePixel.r / 255.0;
        double g = basePixel.g / 255.0;
        double b = basePixel.b / 255.0;

        final or = overPixel.r / 255.0;
        final og = overPixel.g / 255.0;
        final ob = overPixel.b / 255.0;

        if (screenBlend) {
          // Screen Blend mode (Add light)
          r = 1.0 - (1.0 - r) * (1.0 - or * alpha);
          g = 1.0 - (1.0 - g) * (1.0 - og * alpha);
          b = 1.0 - (1.0 - b) * (1.0 - ob * alpha);
        } else {
          // Multiply/Overlay mode (Grain darkening)
          r = r * (1.0 - alpha) + (r * or) * alpha * 1.5;
          g = g * (1.0 - alpha) + (g * og) * alpha * 1.5;
          b = b * (1.0 - alpha) + (b * ob) * alpha * 1.5;
        }

        basePixel.r = (r * 255).round().clamp(0, 255);
        basePixel.g = (g * 255).round().clamp(0, 255);
        basePixel.b = (b * 255).round().clamp(0, 255);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPORT HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates a Polaroid-style framed version of the image.
  static Future<File> createPolaroidFrame(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) throw Exception('Failed to decode image');

    // Polaroid proportions: wider bottom border
    final borderSide = (original.width * 0.08).round();
    final borderBottom = (original.width * 0.25).round();
    final borderTop = borderSide;

    final framed = img.Image(
      width: original.width + borderSide * 2,
      height: original.height + borderTop + borderBottom,
    );

    // Fill with Polaroid white
    img.fill(framed, color: img.ColorRgb8(245, 245, 240));

    // Composite original onto frame
    img.compositeImage(framed, original, dstX: borderSide, dstY: borderTop);

    // Add watermark at bottom
    img.drawString(
      framed,
      RetroStrings.watermark,
      font: img.arial14,
      x: borderSide,
      y: original.height + borderTop + (borderBottom * 0.4).round(),
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

  /// Creates a film strip PNG from multiple photos.
  static Future<File> createFilmStrip(List<File> photos) async {
    if (photos.isEmpty) throw Exception('No photos to create strip');

    // Standard dimensions per frame on 35mm strip
    const frameHeight = 400;
    const frameWidth = 600;
    const sprocketSize = 20;
    const framePadding = 8;

    final totalWidth =
        (frameWidth + framePadding) * photos.length + framePadding;
    final totalHeight = frameHeight + sprocketSize * 2 + 20;

    final strip = img.Image(width: totalWidth, height: totalHeight);
    img.fill(strip, color: img.ColorRgb8(30, 25, 20)); // Film base color

    // Draw sprocket holes
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

    // Composite each photo
    for (int i = 0; i < photos.length; i++) {
      final bytes = await photos[i].readAsBytes();
      var frame = img.decodeImage(bytes);
      if (frame == null) continue;

      frame = img.copyResize(frame, width: frameWidth, height: frameHeight);
      final x = framePadding + i * (frameWidth + framePadding);
      final y = sprocketSize + 10;
      img.compositeImage(strip, frame, dstX: x, dstY: y);
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
