library;

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
    this.grain = 0.10,
    this.leakStrength = 0.10,
    this.dustStrength = 0.05,
    this.lightLeakIndex = 0,
    this.saturation = 1.0,
    this.vignette = 0.3,
    this.scratchLevel = 0.0,
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
      grain: (map['grain'] as num?)?.toDouble() ?? 0.10,
      leakStrength: (map['leakStrength'] as num?)?.toDouble() ?? 0.10,
      dustStrength: (map['dustStrength'] as num?)?.toDouble() ?? 0.05,
      lightLeakIndex: (map['lightLeakIndex'] as num?)?.toInt() ?? 0,
      saturation: (map['saturation'] as num?)?.toDouble() ?? 1.0,
      vignette: (map['vignette'] as num?)?.toDouble() ?? 0.3,
      scratchLevel: (map['scratchLevel'] as num?)?.toDouble() ?? 0.0,
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
