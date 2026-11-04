import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pillbbox/data/models/appearance.dart';
import 'package:pillbbox/utils/object_finder.dart';

void main() {
  test('단색 배경에서 물체만 찾고, 잡티와 가장자리에 닿은 것은 버린다', () {
    final image = img.Image(width: 400, height: 300)
      ..clear(img.ColorRgb8(150, 160, 200));
    // 가로 120, 세로 60 타원 (빨강)
    for (var y = 0; y < 300; y++) {
      for (var x = 0; x < 400; x++) {
        if (((x - 120) / 60) * ((x - 120) / 60) +
                ((y - 100) / 30) * ((y - 100) / 30) <=
            1) {
          image.setPixelRgb(x, y, 200, 40, 40);
        }
      }
    }
    img.fillCircle(
      image,
      x: 300,
      y: 200,
      radius: 30,
      color: img.ColorRgb8(250, 250, 250),
    );
    // 잡티와 가장자리에 걸친 물체
    img.fillRect(
      image,
      x1: 200,
      y1: 250,
      x2: 202,
      y2: 252,
      color: img.ColorRgb8(0, 0, 0),
    );
    img.fillRect(
      image,
      x1: 0,
      y1: 200,
      x2: 40,
      y2: 260,
      color: img.ColorRgb8(30, 120, 30),
    );

    final objects = findObjects(img.encodePng(image))
      ..sort((a, b) => a.box.left.compareTo(b.box.left));

    expect(objects, hasLength(2));
    final (ellipse, circle) = (objects[0], objects[1]);
    expect(ellipse.box.left, closeTo(60, 3));
    expect(ellipse.box.right, closeTo(181, 3));
    expect(ellipse.box.top, closeTo(70, 3));
    expect(ellipse.box.bottom, closeTo(131, 3));
    expect(ellipse.appearance.elongation, closeTo(2, 0.15));
    expect(ellipse.appearance.a, greaterThan(40), reason: '빨간색');
    expect(circle.box.center.dx, closeTo(300, 2));
    expect(circle.appearance.elongation, closeTo(1, 0.1));
    expect(circle.appearance.l, greaterThan(90), reason: '흰색');
  });

  test('큰 사진은 줄여서 찾고 박스는 원본 좌표로 돌려준다', () {
    final image = img.Image(width: 1600, height: 1200)
      ..clear(img.ColorRgb8(150, 160, 200));
    img.fillCircle(
      image,
      x: 800,
      y: 600,
      radius: 100,
      color: img.ColorRgb8(250, 250, 250),
    );

    final objects = findObjects(img.encodeJpg(image));

    expect(objects, hasLength(1));
    expect(objects.single.box.center.dx, closeTo(800, 6));
    expect(objects.single.box.width, closeTo(200, 10));
  });

  test('물체가 없는 사진과 읽을 수 없는 데이터에서는 아무것도 찾지 않는다', () {
    final empty = img.Image(width: 300, height: 200)
      ..clear(img.ColorRgb8(150, 160, 200));

    expect(findObjects(img.encodePng(empty)), isEmpty);
    expect(findObjects(Uint8List.fromList([1, 2, 3])), isEmpty);
  });

  test('실제 사진: 알약 4개를 찾고, 같은 약은 다른 사진에서도 색·모양이 가깝다', () {
    List<FoundObject> find(String name) =>
        findObjects(File('assets/images/test_images/$name').readAsBytesSync());
    // 1.jpg와 3.jpg는 같은 알약 4개를 다른 자리에 놓고 찍었다.
    final first = find('1.jpg');
    final second = find('3.jpg');
    expect(first, hasLength(4));
    expect(second, hasLength(4));

    final matched = <FoundObject>{};
    for (final o in first) {
      final nearest = second.reduce(
        (x, y) =>
            o.appearance.distanceTo(x.appearance) <
                o.appearance.distanceTo(y.appearance)
            ? x
            : y,
      );
      expect(
        o.appearance.distanceTo(nearest.appearance),
        lessThan(Appearance.similarDistance),
      );
      matched.add(nearest);
    }
    expect(matched, hasLength(4), reason: '서로 다른 약끼리 짝이 맞는다');
  });
}
