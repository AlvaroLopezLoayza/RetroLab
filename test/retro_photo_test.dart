import 'package:flutter_test/flutter_test.dart';
import 'package:retrolab/models/retro_photo.dart';

void main() {
  test('texture preview state survives Hive serialization', () {
    final photo = RetroPhoto(
      id: '1',
      originalPath: 'original.jpg',
      processedPath: 'processed.jpg',
      filmStockId: 'stock',
      rollId: 'roll',
      capturedAt: DateTime(2026),
      dustStrength: 0.4,
      lightLeakIndex: 17,
    );

    final restored = RetroPhoto.fromMap(photo.toMap());

    expect(restored.dustStrength, 0.4);
    expect(restored.lightLeakIndex, 17);
  });
}
