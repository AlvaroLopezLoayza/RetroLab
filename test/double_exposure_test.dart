import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:retrolab/utils/image_processor.dart';

void main() {
  test('double exposure uses screen blend across both sources', () {
    final first = img.Image(width: 1, height: 1);
    final second = img.Image(width: 1, height: 1);

    first.setPixelRgba(0, 0, 128, 0, 0, 255);
    second.setPixelRgba(0, 0, 0, 128, 0, 255);

    final bytes = ImageProcessor.composeDoubleExposureBytes(
      img.encodeJpg(first),
      img.encodeJpg(second),
    );
    final composed = img.decodeImage(bytes)!;
    final pixel = composed.getPixel(0, 0);

    expect(pixel.r, greaterThan(120));
    expect(pixel.g, greaterThan(120));
    expect(pixel.b, lessThan(20));
  });
}
