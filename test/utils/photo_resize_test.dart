import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pillbbox/utils/photo_resize.dart';

void main() {
  img.Image photo(int width, int height) =>
      img.Image(width: width, height: height)
        ..clear(img.ColorRgb8(200, 180, 160));

  test('큰 PNG는 긴 변을 줄인 JPEG로 바꾼다', () {
    final png = img.encodePng(photo(1000, 2000));

    final out = shrinkPhoto(png);

    final decoded = img.decodeJpg(out)!;
    expect((decoded.width, decoded.height), (640, photoMaxSide));
  });

  test('작은 PNG도 JPEG로 바꾸고 크기는 그대로 둔다', () {
    final out = shrinkPhoto(img.encodePng(photo(800, 600)));

    final decoded = img.decodeJpg(out)!;
    expect((decoded.width, decoded.height), (800, 600));
  });

  test('이미 작은 JPEG는 그대로 돌려준다', () {
    final jpeg = img.encodeJpg(photo(1280, 960));

    expect(identical(shrinkPhoto(jpeg), jpeg), isTrue);
  });

  test('큰 JPEG는 줄인다', () {
    final decoded = img.decodeJpg(
      shrinkPhoto(img.encodeJpg(photo(4000, 3000))),
    )!;

    expect((decoded.width, decoded.height), (photoMaxSide, 960));
  });

  test('읽을 수 없으면 그대로 돌려준다', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    expect(shrinkPhoto(bytes), bytes);
  });
}
