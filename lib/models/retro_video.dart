library;

import '../core/constants.dart';

class RetroVideo {
  final String id;
  final String rawPath;
  final String processedPath;
  final String thumbnailPath;
  final String filmStockId;
  final DateTime capturedAt;
  final int durationMs;
  final double grain;
  final double leakStrength;
  final double dustStrength;
  final int lightLeakIndex;
  final double saturation;
  final double vignette;
  final double scratchLevel;

  const RetroVideo({
    required this.id,
    required this.rawPath,
    required this.processedPath,
    required this.thumbnailPath,
    required this.filmStockId,
    required this.capturedAt,
    required this.durationMs,
    this.grain = RetroDefaults.grain,
    this.leakStrength = RetroDefaults.leakStrength,
    this.dustStrength = RetroDefaults.dustStrength,
    this.lightLeakIndex = 0,
    this.saturation = 1.0,
    this.vignette = RetroDefaults.vignette,
    this.scratchLevel = RetroDefaults.scratchLevel,
  });

  factory RetroVideo.fromMap(Map map) {
    return RetroVideo(
      id: map['id'] as String,
      rawPath: map['rawPath'] as String? ?? '',
      processedPath: map['processedPath'] as String,
      thumbnailPath: map['thumbnailPath'] as String,
      filmStockId: map['filmStockId'] as String,
      capturedAt: DateTime.parse(map['capturedAt'] as String),
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      grain: (map['grain'] as num?)?.toDouble() ?? RetroDefaults.grain,
      leakStrength:
          (map['leakStrength'] as num?)?.toDouble() ??
          RetroDefaults.leakStrength,
      dustStrength:
          (map['dustStrength'] as num?)?.toDouble() ??
          RetroDefaults.dustStrength,
      lightLeakIndex: (map['lightLeakIndex'] as num?)?.toInt() ?? 0,
      saturation: (map['saturation'] as num?)?.toDouble() ?? 1.0,
      vignette: (map['vignette'] as num?)?.toDouble() ?? RetroDefaults.vignette,
      scratchLevel:
          (map['scratchLevel'] as num?)?.toDouble() ??
          RetroDefaults.scratchLevel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawPath': rawPath,
      'processedPath': processedPath,
      'thumbnailPath': thumbnailPath,
      'filmStockId': filmStockId,
      'capturedAt': capturedAt.toIso8601String(),
      'durationMs': durationMs,
      'grain': grain,
      'leakStrength': leakStrength,
      'dustStrength': dustStrength,
      'lightLeakIndex': lightLeakIndex,
      'saturation': saturation,
      'vignette': vignette,
      'scratchLevel': scratchLevel,
    };
  }
}
