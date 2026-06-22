import 'package:flutter_test/flutter_test.dart';
import 'package:retrolab/core/film_stocks.dart';

void main() {
  test('film stocks stay valid and complete', () {
    expect(FilmStocks.all, hasLength(19));

    final ids = FilmStocks.all.map((stock) => stock.id).toSet();
    expect(ids, hasLength(19));

    for (final stock in FilmStocks.all) {
      expect(stock.tintStrength, inInclusiveRange(0.0, 1.0));
      expect(stock.grainSize, greaterThan(0.0));
      expect(stock.halation, inInclusiveRange(0.0, 1.0));
      expect(stock.borderGlare, inInclusiveRange(0.0, 1.0));
      expect(stock.chromaticAberration, inInclusiveRange(0.0, 1.0));
      expect(stock.colorMatrix, hasLength(9));
    }
  });

  test('custom stock and artifact toggle resolve predictably', () {
    final stock = FilmStocks.custom400C41;
    final enabled = stock.resolveArtifacts(seed: 1234, analogRandomness: true);
    final disabled = stock.resolveArtifacts(
      seed: 1234,
      analogRandomness: false,
    );

    expect(stock.id, 'custom_400_c41');
    expect(enabled.borderGlare, greaterThan(0.0));
    expect(
      enabled.chromaticAberrationX.abs() + enabled.chromaticAberrationY.abs(),
      greaterThan(0.0),
    );
    expect(disabled.borderGlare, 0.0);
    expect(disabled.chromaticAberrationX, 0.0);
    expect(disabled.chromaticAberrationY, 0.0);
  });
}
