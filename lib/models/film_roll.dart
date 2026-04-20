/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Film Roll Model
///
/// Simulates a physical film roll with limited exposures.
/// ─────────────────────────────────────────────────────────────────────────────
library;

class FilmRoll {
  final String id;
  final String filmStockId;
  final int totalExposures;
  final int usedExposures;
  final DateTime loadedAt;
  final DateTime? finishedAt;
  final List<String> photoIds;

  FilmRoll({
    required this.id,
    required this.filmStockId,
    this.totalExposures = 36,
    this.usedExposures = 0,
    required this.loadedAt,
    this.finishedAt,
    List<String>? photoIds,
  }) : photoIds = photoIds ?? [];

  /// Remaining shots on this roll.
  int get remainingExposures => totalExposures - usedExposures;

  /// Whether this roll is fully exposed.
  bool get isFinished => usedExposures >= totalExposures;

  /// Progress fraction (0.0 … 1.0).
  double get progress => usedExposures / totalExposures;

  /// Create from Hive map.
  factory FilmRoll.fromMap(Map map) {
    return FilmRoll(
      id: map['id'] as String,
      filmStockId: map['filmStockId'] as String,
      totalExposures: map['totalExposures'] as int? ?? 36,
      usedExposures: map['usedExposures'] as int? ?? 0,
      loadedAt: DateTime.parse(map['loadedAt'] as String),
      finishedAt:
          map['finishedAt'] != null
              ? DateTime.parse(map['finishedAt'] as String)
              : null,
      photoIds: List<String>.from(map['photoIds'] as List? ?? []),
    );
  }

  /// Convert to Hive-storable map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filmStockId': filmStockId,
      'totalExposures': totalExposures,
      'usedExposures': usedExposures,
      'loadedAt': loadedAt.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'photoIds': photoIds,
    };
  }

  /// Create a copy with an additional exposure used.
  FilmRoll withExposureTaken(String photoId) {
    final newUsed = usedExposures + 1;
    return FilmRoll(
      id: id,
      filmStockId: filmStockId,
      totalExposures: totalExposures,
      usedExposures: newUsed,
      loadedAt: loadedAt,
      finishedAt: newUsed >= totalExposures ? DateTime.now() : null,
      photoIds: [...photoIds, photoId],
    );
  }

  /// Create a copy of the FilmRoll with updated fields.
  FilmRoll copyWith({
    String? id,
    String? filmStockId,
    int? totalExposures,
    int? usedExposures,
    DateTime? loadedAt,
    DateTime? finishedAt,
    List<String>? photoIds,
  }) {
    return FilmRoll(
      id: id ?? this.id,
      filmStockId: filmStockId ?? this.filmStockId,
      totalExposures: totalExposures ?? this.totalExposures,
      usedExposures: usedExposures ?? this.usedExposures,
      loadedAt: loadedAt ?? this.loadedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      photoIds: photoIds ?? this.photoIds,
    );
  }
}
