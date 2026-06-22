library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';

class VideoEffectSettings {
  final FilmStock stock;
  final double grain;
  final double leakStrength;
  final double dustStrength;
  final int lightLeakIndex;
  final double saturation;
  final double vignette;
  final double scratchLevel;
  final bool analogRandomness;
  final int artifactSeed;

  const VideoEffectSettings({
    required this.stock,
    required this.grain,
    required this.leakStrength,
    required this.dustStrength,
    required this.lightLeakIndex,
    required this.saturation,
    required this.vignette,
    required this.scratchLevel,
    required this.analogRandomness,
    required this.artifactSeed,
  });

  Map<String, dynamic> toMap() {
    final highlight = stock.highlightTint;
    final shadow = stock.shadowTint;
    final glare = stock.glareTint;
    final artifacts = stock.resolveArtifacts(
      seed: artifactSeed,
      analogRandomness: analogRandomness,
    );
    final matrix = stock.colorMatrix;
    return {
      'filmStockId': stock.id,
      'temperature': stock.temperature,
      'saturation': saturation,
      'contrast': stock.contrast,
      'brightness': stock.brightness,
      'shadowLift': stock.shadowLift,
      'tintStrength': stock.tintStrength,
      'redGamma': stock.redGamma,
      'greenGamma': stock.greenGamma,
      'blueGamma': stock.blueGamma,
      'highlightTint': [highlight.r, highlight.g, highlight.b],
      'shadowTint': [shadow.r, shadow.g, shadow.b],
      'grain': grain,
      'grainSize': stock.grainSize,
      'grainColored': stock.coloredGrain,
      'vignette': vignette,
      'scratchLevel': scratchLevel,
      'leakStrength': leakStrength,
      'dustStrength': dustStrength,
      'halation': stock.halation,
      'colorMatrixRow0': [matrix[0], matrix[1], matrix[2]],
      'colorMatrixRow1': [matrix[3], matrix[4], matrix[5]],
      'colorMatrixRow2': [matrix[6], matrix[7], matrix[8]],
      'glareTint': [glare.r / 255.0, glare.g / 255.0, glare.b / 255.0],
      'borderGlare': artifacts.borderGlare,
      'glareWidth': artifacts.glareWidth,
      'glareAngle': artifacts.glareAngle,
      'caOffset': [
        artifacts.chromaticAberrationX,
        artifacts.chromaticAberrationY,
      ],
      'leakAsset': RetroAssets.lightLeak(lightLeakIndex),
      'dustAsset': RetroAssets.textureDust,
      'scratchAsset': RetroAssets.textureScratch,
    };
  }
}

class VideoProcessResult {
  final File processedFile;
  final File thumbnailFile;
  final int durationMs;

  const VideoProcessResult({
    required this.processedFile,
    required this.thumbnailFile,
    required this.durationMs,
  });
}

class VideoProcessor {
  VideoProcessor._();

  static const MethodChannel _channel = MethodChannel('retrolab/video');

  static Future<VideoProcessResult> processVideo(
    File inputFile, {
    required String outputId,
    required VideoEffectSettings settings,
  }) async {
    final dir = await getTemporaryDirectory();
    final processedPath = '${dir.path}/retro_video_$outputId.mp4';
    final thumbnailPath = '${dir.path}/retro_video_$outputId.jpg';
    final result = await _channel
        .invokeMapMethod<String, dynamic>('processVideo', {
          'inputPath': inputFile.path,
          'outputPath': processedPath,
          'thumbnailPath': thumbnailPath,
          'settings': settings.toMap(),
        });
    if (result == null) {
      throw StateError('Video processor returned no result.');
    }
    return VideoProcessResult(
      processedFile: File(result['outputPath'] as String),
      thumbnailFile: File(result['thumbnailPath'] as String),
      durationMs: (result['durationMs'] as num?)?.toInt() ?? 0,
    );
  }
}
