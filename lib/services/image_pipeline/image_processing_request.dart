library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/film_stocks.dart';

class ImageProcessingRequest {
  final String filmStockId;
  final double grain;
  final double leakStrength;
  final double dustStrength;
  final int lightLeakIndex;
  final double saturation;
  final double vignette;
  final double scratchLevel;
  final bool dateStampEnabled;
  final String dateStampStyle;
  final String dateStampPosition;
  final bool analogRandomness;
  final int artifactSeed;
  final int captureTimestampMillis;
  final bool saveLocationData;
  final int iso;
  final double temperature;
  final double contrast;
  final double brightness;
  final double shadowLift;
  final double tintStrength;
  final double baseGrain;
  final bool coloredGrain;
  final double grainSize;
  final double baseVignette;
  final double halation;
  final double redGamma;
  final double greenGamma;
  final double blueGamma;
  final double borderGlare;
  final double glareWidth;
  final double glareAngle;
  final double chromaticAberrationX;
  final double chromaticAberrationY;
  final List<double> colorMatrix;
  final int highlightTintArgb;
  final int shadowTintArgb;
  final int glareTintArgb;

  const ImageProcessingRequest({
    required this.filmStockId,
    required this.grain,
    required this.leakStrength,
    required this.dustStrength,
    required this.lightLeakIndex,
    required this.saturation,
    required this.vignette,
    required this.scratchLevel,
    required this.dateStampEnabled,
    required this.dateStampStyle,
    required this.dateStampPosition,
    required this.analogRandomness,
    required this.artifactSeed,
    required this.captureTimestampMillis,
    required this.saveLocationData,
    required this.iso,
    required this.temperature,
    required this.contrast,
    required this.brightness,
    required this.shadowLift,
    required this.tintStrength,
    required this.baseGrain,
    required this.coloredGrain,
    required this.grainSize,
    required this.baseVignette,
    required this.halation,
    required this.redGamma,
    required this.greenGamma,
    required this.blueGamma,
    required this.borderGlare,
    required this.glareWidth,
    required this.glareAngle,
    required this.chromaticAberrationX,
    required this.chromaticAberrationY,
    required this.colorMatrix,
    required this.highlightTintArgb,
    required this.shadowTintArgb,
    required this.glareTintArgb,
  });

  factory ImageProcessingRequest.fromFilmStock({
    required FilmStock filmStock,
    required double grain,
    required double leakStrength,
    required double dustStrength,
    required int lightLeakIndex,
    required double saturation,
    required double vignette,
    required double scratchLevel,
    required bool dateStampEnabled,
    required DateStampStyle dateStampStyle,
    required DateStampPosition dateStampPosition,
    required bool analogRandomness,
    required int artifactSeed,
    required DateTime captureDate,
    required bool saveLocationData,
  }) {
    final artifacts = filmStock.resolveArtifacts(
      seed: artifactSeed,
      analogRandomness: analogRandomness,
    );
    return ImageProcessingRequest(
      filmStockId: filmStock.id,
      grain: grain,
      leakStrength: leakStrength,
      dustStrength: dustStrength,
      lightLeakIndex: lightLeakIndex,
      saturation: saturation,
      vignette: vignette,
      scratchLevel: scratchLevel,
      dateStampEnabled: dateStampEnabled,
      dateStampStyle: dateStampStyle.name,
      dateStampPosition: dateStampPosition.name,
      analogRandomness: analogRandomness,
      artifactSeed: artifactSeed,
      captureTimestampMillis: captureDate.millisecondsSinceEpoch,
      saveLocationData: saveLocationData,
      iso: filmStock.iso,
      temperature: filmStock.temperature,
      contrast: filmStock.contrast,
      brightness: filmStock.brightness,
      shadowLift: filmStock.shadowLift,
      tintStrength: filmStock.tintStrength,
      baseGrain: filmStock.baseGrain,
      coloredGrain: filmStock.coloredGrain,
      grainSize: filmStock.grainSize,
      baseVignette: filmStock.baseVignette,
      halation: filmStock.halation,
      redGamma: filmStock.redGamma,
      greenGamma: filmStock.greenGamma,
      blueGamma: filmStock.blueGamma,
      borderGlare: artifacts.borderGlare,
      glareWidth: artifacts.glareWidth,
      glareAngle: artifacts.glareAngle,
      chromaticAberrationX: artifacts.chromaticAberrationX,
      chromaticAberrationY: artifacts.chromaticAberrationY,
      colorMatrix: filmStock.colorMatrix,
      highlightTintArgb: _argb(filmStock.highlightTint),
      shadowTintArgb: _argb(filmStock.shadowTint),
      glareTintArgb: _argb(filmStock.glareTint),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'filmStockId': filmStockId,
      'grain': grain,
      'leakStrength': leakStrength,
      'dustStrength': dustStrength,
      'lightLeakIndex': lightLeakIndex,
      'saturation': saturation,
      'vignette': vignette,
      'scratchLevel': scratchLevel,
      'dateStampEnabled': dateStampEnabled,
      'dateStampStyle': dateStampStyle,
      'dateStampPosition': dateStampPosition,
      'analogRandomness': analogRandomness,
      'artifactSeed': artifactSeed,
      'captureTimestampMillis': captureTimestampMillis,
      'saveLocationData': saveLocationData,
      'iso': iso,
      'temperature': temperature,
      'contrast': contrast,
      'brightness': brightness,
      'shadowLift': shadowLift,
      'tintStrength': tintStrength,
      'baseGrain': baseGrain,
      'coloredGrain': coloredGrain,
      'grainSize': grainSize,
      'baseVignette': baseVignette,
      'halation': halation,
      'redGamma': redGamma,
      'greenGamma': greenGamma,
      'blueGamma': blueGamma,
      'borderGlare': borderGlare,
      'glareWidth': glareWidth,
      'glareAngle': glareAngle,
      'chromaticAberrationX': chromaticAberrationX,
      'chromaticAberrationY': chromaticAberrationY,
      'colorMatrix': colorMatrix,
      'highlightTintArgb': highlightTintArgb,
      'shadowTintArgb': shadowTintArgb,
      'glareTintArgb': glareTintArgb,
      'scratchAsset': RetroAssets.textureScratch,
      'dustAsset': RetroAssets.textureDust,
      'leakAsset': RetroAssets.lightLeak(lightLeakIndex),
    };
  }

  static int _argb(Color color) {
    return ((color.a * 255).round() << 24) |
        ((color.r * 255).round() << 16) |
        ((color.g * 255).round() << 8) |
        (color.b * 255).round();
  }
}
