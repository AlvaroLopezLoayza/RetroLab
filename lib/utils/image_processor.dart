library;

import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
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

class ImageProcessor {
  ImageProcessor._();

  static final Random _random = Random();

  static Future<File> composeDoubleExposure(File first, File second) async {
    final firstBytes = await first.readAsBytes();
    final secondBytes = await second.readAsBytes();
    final composedBytes = await Isolate.run(() {
      return composeDoubleExposureBytes(firstBytes, secondBytes);
    });

    final appDir = await getApplicationDocumentsDirectory();
    final retroDir = Directory('${appDir.path}/RetroLab');
    if (!retroDir.existsSync()) {
      retroDir.createSync(recursive: true);
    }

    final file = File(
      '${retroDir.path}/double_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(composedBytes);
    return file;
  }

  static Uint8List composeDoubleExposureBytes(
    Uint8List firstBytes,
    Uint8List secondBytes,
  ) {
    final first = img.decodeImage(firstBytes);
    final second = img.decodeImage(secondBytes);
    if (first == null || second == null) {
      throw ImageDecodeException('Failed to decode double exposure sources');
    }

    final base = img.copyResize(
      first,
      width: first.width,
      height: first.height,
    );
    final overlay = img.copyResize(
      second,
      width: first.width,
      height: first.height,
    );

    for (int y = 0; y < base.height; y++) {
      for (int x = 0; x < base.width; x++) {
        final firstPixel = base.getPixel(x, y);
        final secondPixel = overlay.getPixel(x, y);
        firstPixel.r = _screenChannel(firstPixel.r, secondPixel.r);
        firstPixel.g = _screenChannel(firstPixel.g, secondPixel.g);
        firstPixel.b = _screenChannel(firstPixel.b, secondPixel.b);
      }
    }

    return Uint8List.fromList(img.encodeJpg(base, quality: 92));
  }

  static Future<ProcessingResult> processRetroImage(
    File original, {
    required FilmStock filmStock,
    double? grain,
    double leakStrength = 0.6,
    double dustStrength = 0.0,
    int? lightLeakIndex,
    double? saturationOverride,
    double? vignette,
    double scratchLevel = 0.0,
    bool dateStampEnabled = true,
    DateStampStyle dateStampStyle = DateStampStyle.classic90s,
    DateStampPosition dateStampPosition = DateStampPosition.bottomRight,
    bool analogRandomness = true,
    int? artifactSeed,
    DateTime? captureDate,
    bool saveLocationData = false,
  }) async {
    final bytes = await original.readAsBytes();

    Uint8List? scratchBytes;
    Uint8List? leakBytes;
    Uint8List? dustBytes;

    if (scratchLevel > 0) {
      try {
        final data = await rootBundle.load(RetroAssets.textureScratch);
        scratchBytes = data.buffer.asUint8List();
      } catch (e) {
        debugPrint('[RetroLab] Scratch load failed: $e');
      }
    }

    if (leakStrength > 0) {
      final leakIndex = lightLeakIndex ?? _random.nextInt(42);
      try {
        final data = await rootBundle.load(RetroAssets.lightLeak(leakIndex));
        leakBytes = data.buffer.asUint8List();
      } catch (e) {
        debugPrint('[RetroLab] Leak asset $leakIndex failed: $e');
      }
    }

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
          artifactSeed: artifactSeed,
          captureDate: captureDate ?? DateTime.now(),
          saveLocationData: saveLocationData,
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
    required int? artifactSeed,
    required DateTime captureDate,
    required bool saveLocationData,
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
    final effectiveSaturation =
        filmStock.saturation == 0.0
            ? 0.0
            : (saturationOverride ?? filmStock.saturation);
    final effectiveVignette = vignette ?? filmStock.baseVignette;
    final artifacts = filmStock.resolveArtifacts(
      seed: artifactSeed ?? filmStock.id.hashCode,
      analogRandomness: analogRandomness,
    );

    if (filmStock.halation > 0) {
      _applyHalation(image, filmStock.halation);
    }

    _applyFilmStockGrading(image, filmStock, effectiveSaturation);

    if (artifacts.chromaticAberrationX != 0 ||
        artifacts.chromaticAberrationY != 0) {
      _applyChromaticAberration(
        image,
        artifacts.chromaticAberrationX,
        artifacts.chromaticAberrationY,
      );
    }

    if (effectiveGrain > 0) {
      _applyProceduralGrain(
        image,
        effectiveGrain,
        filmStock.coloredGrain,
        filmStock.grainSize,
      );
    }

    if (effectiveVignette > 0) {
      _applyVignette(image, effectiveVignette);
    }

    if (artifacts.borderGlare > 0) {
      _applyBorderGlare(
        image,
        strength: artifacts.borderGlare,
        width: artifacts.glareWidth,
        angle: artifacts.glareAngle,
        tint: filmStock.glareTint,
      );
    }

    if (scratchLevel > 0 && scratchBytes != null) {
      _applyTextureOverlay(image, scratchBytes, scratchLevel, true);
    }
    if (leakBytes != null) {
      _applyTextureOverlay(image, leakBytes, leakStrength, true);
    }
    if (dustBytes != null) {
      _applyTextureOverlay(image, dustBytes, dustStrength, true);
    }

    if (analogRandomness) {
      _applyProceduralAnalogRandomness(image);
    }

    if (dateStampEnabled) {
      _drawDateStamp(image, captureDate, dateStampStyle, dateStampPosition);
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  static void _applyHalation(img.Image image, double intensity) {
    final source = img.copyResize(
      image,
      width: image.width,
      height: image.height,
    );
    final glow = intensity * 24.0;

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final pixel = source.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;
        final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        final redBias = max(0.0, r - max(g, b) * 0.5);
        final amount =
            _smoothstep(0.78, 1.0, luminance) * (0.2 + redBias) * glow;
        if (amount <= 0) continue;

        for (final offset in const [
          [1, 0],
          [-1, 0],
          [0, 1],
          [0, -1],
        ]) {
          final target = image.getPixel(x + offset[0], y + offset[1]);
          target.r = (target.r + amount).round().clamp(0, 255);
          target.g = (target.g + amount * 0.35).round().clamp(0, 255);
          target.b = (target.b + amount * 0.06).round().clamp(0, 255);
        }
      }
    }
  }

  static void _applyFilmStockGrading(
    img.Image image,
    FilmStock stock,
    double saturation,
  ) {
    final redLUT = _buildGammaLUT(stock.redGamma);
    final greenLUT = _buildGammaLUT(stock.greenGamma);
    final blueLUT = _buildGammaLUT(stock.blueGamma);
    final highlight = stock.highlightTint;
    final shadow = stock.shadowTint;
    final matrix = stock.colorMatrix;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        double r = pixel.r / 255.0;
        double g = pixel.g / 255.0;
        double b = pixel.b / 255.0;

        if (stock.temperature != 0) {
          final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
          final t =
              stock.temperature *
              (24.0 / 255.0) *
              (1.0 - luminance * luminance);
          r += t;
          g += t * 0.18;
          b -= t;
        }

        r = redLUT[(r * 255.0).round().clamp(0, 255)] / 255.0;
        g = greenLUT[(g * 255.0).round().clamp(0, 255)] / 255.0;
        b = blueLUT[(b * 255.0).round().clamp(0, 255)] / 255.0;

        if (matrix != FilmStock.identityColorMatrix) {
          final transformed = _applyColorMatrix(r, g, b, matrix);
          r = transformed.$1;
          g = transformed.$2;
          b = transformed.$3;
        }

        final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        r = luminance + (r - luminance) * saturation;
        g = luminance + (g - luminance) * saturation;
        b = luminance + (b - luminance) * saturation;

        r = _applyContrastCurve(r, stock.contrast);
        g = _applyContrastCurve(g, stock.contrast);
        b = _applyContrastCurve(b, stock.contrast);

        if (stock.brightness != 0) {
          if (stock.brightness > 0) {
            r += stock.brightness * (1.0 - r);
            g += stock.brightness * (1.0 - g);
            b += stock.brightness * (1.0 - b);
          } else {
            r += stock.brightness;
            g += stock.brightness;
            b += stock.brightness;
          }
        }

        if (stock.tintStrength > 0) {
          final tone = 0.299 * r + 0.587 * g + 0.114 * b;
          final highlightMix =
              _smoothstep(0.55, 0.92, tone) * stock.tintStrength;
          final shadowMix =
              (1.0 - _smoothstep(0.08, 0.45, tone)) * stock.tintStrength;
          r = _mix(r, highlight.r / 255.0 * (240.0 / 255.0), highlightMix);
          g = _mix(g, highlight.g / 255.0 * (240.0 / 255.0), highlightMix);
          b = _mix(b, highlight.b / 255.0 * (240.0 / 255.0), highlightMix);
          r = _mix(r, shadow.r / 255.0, shadowMix);
          g = _mix(g, shadow.g / 255.0, shadowMix);
          b = _mix(b, shadow.b / 255.0, shadowMix);
        }

        if (stock.shadowLift > 0) {
          r += stock.shadowLift * pow(1.0 - r, 2.0).toDouble();
          g += stock.shadowLift * pow(1.0 - g, 2.0).toDouble();
          b += stock.shadowLift * pow(1.0 - b, 2.0).toDouble();
        }

        pixel.r = (_applyShoulder(r) * 255.0).round().clamp(0, 255);
        pixel.g = (_applyShoulder(g) * 255.0).round().clamp(0, 255);
        pixel.b = (_applyShoulder(b) * 255.0).round().clamp(0, 255);
      }
    }
  }

  static List<int> _buildGammaLUT(double gamma) {
    return List<int>.generate(256, (i) {
      final normalized = i / 255.0;
      final corrected = pow(normalized, gamma);
      return (corrected * 255).round().clamp(0, 255);
    });
  }

  static double _applyContrastCurve(double value, double contrast) {
    final x = value.clamp(0.0, 1.5);
    if (contrast >= 0) {
      final curve =
          x < 0.5 ? 2.0 * x * x : 1.0 - 2.0 * pow(1.0 - x, 2.0).toDouble();
      return _mix(x, curve, contrast.clamp(0.0, 1.0));
    }
    return 0.5 + (x - 0.5) * (1.0 + contrast.clamp(-1.0, 0.0));
  }

  static double _applyShoulder(double value) {
    final x = value.clamp(0.0, 1.5);
    if (x <= 200.0 / 255.0) return x;
    final t = ((x - 200.0 / 255.0) / (55.0 / 255.0)).clamp(0.0, 2.0);
    final shoulder = (t * 1.35) / (1.0 + 0.35 * t);
    return (200.0 / 255.0) + (55.0 / 255.0) * shoulder.clamp(0.0, 1.0);
  }

  static double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  static double _mix(double a, double b, double t) => a + (b - a) * t;

  static int _screenChannel(num first, num second) {
    final a = first / 255.0;
    final b = second / 255.0;
    return ((1.0 - (1.0 - a) * (1.0 - b)) * 255.0).round().clamp(0, 255);
  }

  static void _applyProceduralGrain(
    img.Image image,
    double intensity,
    bool colored,
    double grainSize,
  ) {
    final scale = 3.4 * grainSize.clamp(0.5, 2.0);
    final amount = intensity * 38.0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance =
            (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
        final visibility = 0.35 + (1.0 - luminance) * 0.65;
        final baseNoise =
            (_noise(x / scale, y / scale) - 0.5) * amount * visibility;

        if (colored) {
          final noiseG =
              (_noise(x / scale + 11.0, y / scale + 7.0) - 0.5) *
              amount *
              0.85 *
              visibility;
          final noiseB =
              (_noise(x / scale + 23.0, y / scale + 19.0) - 0.5) *
              amount *
              1.1 *
              visibility;
          pixel.r = (pixel.r + baseNoise).round().clamp(0, 255);
          pixel.g = (pixel.g + noiseG).round().clamp(0, 255);
          pixel.b = (pixel.b + noiseB).round().clamp(0, 255);
        } else {
          final noise = baseNoise.round();
          pixel.r = (pixel.r + noise).clamp(0, 255);
          pixel.g = (pixel.g + noise).clamp(0, 255);
          pixel.b = (pixel.b + noise).clamp(0, 255);
        }
      }
    }
  }

  static double _noise(double x, double y) {
    final value = sin(x * 12.9898 + y * 78.233) * 43758.5453;
    return value - value.floorToDouble();
  }

  static (double, double, double) _applyColorMatrix(
    double r,
    double g,
    double b,
    List<double> matrix,
  ) {
    final nr = (r * matrix[0] + g * matrix[1] + b * matrix[2]).clamp(0.0, 1.0);
    final ng = (r * matrix[3] + g * matrix[4] + b * matrix[5]).clamp(0.0, 1.0);
    final nb = (r * matrix[6] + g * matrix[7] + b * matrix[8]).clamp(0.0, 1.0);
    return (nr, ng, nb);
  }

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

  static void _applyBorderGlare(
    img.Image image, {
    required double strength,
    required double width,
    required double angle,
    required Color tint,
  }) {
    final cx = image.width / 2.0;
    final cy = image.height / 2.0;
    final cosAngle = cos(angle);
    final sinAngle = sin(angle);
    final tintR = tint.r / 255.0;
    final tintG = tint.g / 255.0;
    final tintB = tint.b / 255.0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final nx = (x - cx) / cx;
        final ny = (y - cy) / cy;
        final radial = max(nx.abs(), ny.abs());
        final edge = _smoothstep(0.58 - width * 0.22, 1.0, radial);
        if (edge <= 0) continue;
        final bias = (((nx * cosAngle) + (ny * sinAngle)) * 0.5 + 0.5).clamp(
          0.0,
          1.0,
        );
        final glare = edge * strength * (0.45 + bias * 0.55);
        final pixel = image.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;
        pixel.r = ((1.0 - (1.0 - r) * (1.0 - tintR * glare)) * 255.0)
            .round()
            .clamp(0, 255);
        pixel.g = ((1.0 - (1.0 - g) * (1.0 - tintG * glare)) * 255.0)
            .round()
            .clamp(0, 255);
        pixel.b = ((1.0 - (1.0 - b) * (1.0 - tintB * glare)) * 255.0)
            .round()
            .clamp(0, 255);
      }
    }
  }

  static void _applyChromaticAberration(
    img.Image image,
    double offsetX,
    double offsetY,
  ) {
    final source = img.copyResize(
      image,
      width: image.width,
      height: image.height,
    );
    final cx = image.width / 2.0;
    final cy = image.height / 2.0;
    final shiftX = offsetX * image.width;
    final shiftY = offsetY * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final dx = (x - cx) / cx;
        final dy = (y - cy) / cy;
        final edge = _smoothstep(
          0.24,
          1.0,
          sqrt(dx * dx + dy * dy) / 1.41421356237,
        );
        if (edge <= 0) continue;
        final redX = (x + shiftX * edge).round().clamp(0, image.width - 1);
        final redY = (y + shiftY * edge).round().clamp(0, image.height - 1);
        final blueX = (x - shiftX * edge).round().clamp(0, image.width - 1);
        final blueY = (y - shiftY * edge).round().clamp(0, image.height - 1);
        final pixel = image.getPixel(x, y);
        pixel.r = source.getPixel(redX, redY).r;
        pixel.b = source.getPixel(blueX, blueY).b;
      }
    }
  }

  static void _applyProceduralAnalogRandomness(img.Image image) {
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
        const [
          [255, 180, 50],
          [255, 220, 100],
          [255, 130, 80],
          [200, 180, 255],
        ][_random.nextInt(4)];

    for (int y = y0; y < min(y0 + bandHeight, image.height); y++) {
      final distFromCenter = (y - y0 - bandHeight / 2).abs() / (bandHeight / 2);
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
        final rawAlpha = (overPixel.a / 255.0) * strength;
        final alpha = screenBlend ? rawAlpha * 0.5 : rawAlpha;

        double r = basePixel.r / 255.0;
        double g = basePixel.g / 255.0;
        double b = basePixel.b / 255.0;

        final or = overPixel.r / 255.0;
        final og = overPixel.g / 255.0;
        final ob = overPixel.b / 255.0;

        if (screenBlend) {
          r = 1.0 - (1.0 - r) * (1.0 - or * alpha);
          g = 1.0 - (1.0 - g) * (1.0 - og * alpha);
          b = 1.0 - (1.0 - b) * (1.0 - ob * alpha);
        } else {
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

    if (filterName != null) {
      final nameStr = filterName.toUpperCase();
      img.drawString(
        framed,
        nameStr,
        font: img.arial24,
        x: framed.width - borderSide - (nameStr.length * 15).round(),
        y: original.height + borderTop + (borderBottom * 0.35).round(),
        color: img.ColorRgb8(80, 80, 80),
      );
    }

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
