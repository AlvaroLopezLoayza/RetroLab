import 'package:flutter_test/flutter_test.dart';
import 'package:retrolab/models/retro_video.dart';

void main() {
  test('RetroVideo map roundtrip preserves core fields', () {
    final capturedAt = DateTime(2026, 6, 19, 12, 30);
    final video = RetroVideo(
      id: 'vid-1',
      rawPath: 'raw.mp4',
      processedPath: 'processed.mp4',
      thumbnailPath: 'thumb.jpg',
      filmStockId: 'kodak_gold_200',
      capturedAt: capturedAt,
      durationMs: 12345,
      grain: 0.2,
      leakStrength: 0.3,
      dustStrength: 0.1,
      lightLeakIndex: 7,
      saturation: 1.1,
      vignette: 0.4,
      scratchLevel: 0.2,
    );

    final restored = RetroVideo.fromMap(video.toMap());

    expect(restored.id, video.id);
    expect(restored.processedPath, video.processedPath);
    expect(restored.thumbnailPath, video.thumbnailPath);
    expect(restored.filmStockId, video.filmStockId);
    expect(restored.capturedAt, capturedAt);
    expect(restored.durationMs, 12345);
    expect(restored.lightLeakIndex, 7);
  });
}
