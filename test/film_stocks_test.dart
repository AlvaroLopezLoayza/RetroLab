import 'package:flutter_test/flutter_test.dart';
import 'package:retrolab/core/film_stocks.dart';

void main() {
  test('film stocks stay valid and complete', () {
    expect(FilmStocks.all, hasLength(18));

    final ids = FilmStocks.all.map((stock) => stock.id).toSet();
    expect(ids, hasLength(18));

    for (final stock in FilmStocks.all) {
      expect(stock.tintStrength, inInclusiveRange(0.0, 1.0));
      expect(stock.grainSize, greaterThan(0.0));
      expect(stock.halation, inInclusiveRange(0.0, 1.0));
    }
  });
}
