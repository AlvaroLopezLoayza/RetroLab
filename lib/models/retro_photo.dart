/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Retro Photo Model
/// ─────────────────────────────────────────────────────────────────────────────
library;

import '../core/constants.dart';

class RetroPhoto {
  final String id;
  final String originalPath;
  final String processedPath;
  final String filmStockId;
  final String rollId;
  final DateTime capturedAt;
  final double grain;
  final double leakStrength;
  final double dustStrength;
  final int lightLeakIndex;
  final double saturation;
  final double vignette;
  final double scratchLevel;
  final String dateStampStyle;
  final String dateStampPosition;
  final bool dateStampEnabled;
  final bool isImported;

  RetroPhoto({
    required this.id,
    required this.originalPath,
    required this.processedPath,
    required this.filmStockId,
    required this.rollId,
    required this.capturedAt,
    this.grain = RetroDefaults.grain,
    this.leakStrength = RetroDefaults.leakStrength,
    this.dustStrength = RetroDefaults.dustStrength,
    this.lightLeakIndex = 0,
    this.saturation = 1.0,
    this.vignette = RetroDefaults.vignette,
    this.scratchLevel = RetroDefaults.scratchLevel,
    this.dateStampStyle = 'classic90s',
    this.dateStampPosition = 'bottomRight',
    this.dateStampEnabled = true,
    this.isImported = false,
  });

  /// Create from Hive map.
  factory RetroPhoto.fromMap(Map map) {
    return RetroPhoto(
      id: map['id'] as String,
      originalPath: map['originalPath'] as String,
      processedPath: map['processedPath'] as String,
      filmStockId: map['filmStockId'] as String,
      rollId: map['rollId'] as String,
      capturedAt: DateTime.parse(map['capturedAt'] as String),
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
      dateStampStyle: map['dateStampStyle'] as String? ?? 'classic90s',
      dateStampPosition: map['dateStampPosition'] as String? ?? 'bottomRight',
      dateStampEnabled: map['dateStampEnabled'] as bool? ?? true,
      isImported: map['isImported'] as bool? ?? false,
    );
  }

  /// Convert to Hive-storable map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originalPath': originalPath,
      'processedPath': processedPath,
      'filmStockId': filmStockId,
      'rollId': rollId,
      'capturedAt': capturedAt.toIso8601String(),
      'grain': grain,
      'leakStrength': leakStrength,
      'dustStrength': dustStrength,
      'lightLeakIndex': lightLeakIndex,
      'saturation': saturation,
      'vignette': vignette,
      'scratchLevel': scratchLevel,
      'dateStampStyle': dateStampStyle,
      'dateStampPosition': dateStampPosition,
      'dateStampEnabled': dateStampEnabled,
      'isImported': isImported,
    };
  }

  /// Create a copy with modified fields (for re-editing).
  RetroPhoto copyWith({
    String? processedPath,
    String? filmStockId,
    double? grain,
    double? leakStrength,
    double? dustStrength,
    int? lightLeakIndex,
    double? saturation,
    double? vignette,
    double? scratchLevel,
    String? dateStampStyle,
    String? dateStampPosition,
    bool? dateStampEnabled,
  }) {
    return RetroPhoto(
      id: id,
      originalPath: originalPath,
      processedPath: processedPath ?? this.processedPath,
      filmStockId: filmStockId ?? this.filmStockId,
      rollId: rollId,
      capturedAt: capturedAt,
      grain: grain ?? this.grain,
      leakStrength: leakStrength ?? this.leakStrength,
      dustStrength: dustStrength ?? this.dustStrength,
      lightLeakIndex: lightLeakIndex ?? this.lightLeakIndex,
      saturation: saturation ?? this.saturation,
      vignette: vignette ?? this.vignette,
      scratchLevel: scratchLevel ?? this.scratchLevel,
      dateStampStyle: dateStampStyle ?? this.dateStampStyle,
      dateStampPosition: dateStampPosition ?? this.dateStampPosition,
      dateStampEnabled: dateStampEnabled ?? this.dateStampEnabled,
      isImported: isImported,
    );
  }
}
