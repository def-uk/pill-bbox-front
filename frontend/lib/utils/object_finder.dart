import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../data/models/appearance.dart';

/// 배경과 다른 색의 덩어리 하나. 박스는 원본 이미지 픽셀 좌표다.
class FoundObject {
  const FoundObject({required this.box, required this.appearance});

  final Rect box;
  final Appearance appearance;
}

/// 단색 배경 위의 물체를 찾는다. 모델이 알약으로 보지 않은 물체도 사용자가 무엇인지 고를 수 있게 하려는 것이다.
///
/// 1. 긴 변 640px로 줄이고 CIELAB 색으로 바꾼다.
/// 2. 가장자리 픽셀의 중앙값을 배경색으로 보고, 픽셀마다 배경색과의 거리를 잰다.
/// 3. 거리를 Otsu로 나눠 물체 마스크를 만들고, 열기·닫기·구멍 메우기로 다듬는다.
/// 4. 이어진 덩어리마다 박스를 친다. 너무 작거나 크거나 사진 가장자리에 닿은 덩어리는 버린다.
///
/// 대회 학습 사진 232장에서 알약 763개 중 99%를 찾았고, 알약이 아닌 박스는 17개였다.
/// 읽을 수 없는 이미지면 빈 목록을 돌려준다.
List<FoundObject> findObjects(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return const [];
  var image = img.bakeOrientation(decoded);
  final scale = min(1.0, objectFinderSide / max(image.width, image.height));
  if (scale < 1) {
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }
  return findObjectsInImage(image, scale);
}

/// 이미 긴 변 [objectFinderSide]px 이하로 줄인 [image]에서 물체를 찾는다. [scale]은 원본 대비 줄인 비율이고,
/// 박스는 원본 좌표로 되돌려 준다. 웹은 브라우저가 디코드와 축소를 맡아 이것만 부른다.
List<FoundObject> findObjectsInImage(img.Image image, double scale) {
  final w = image.width, h = image.height;
  final lab = _toLab(image);
  final background = _borderMedian(lab, w, h);

  final dist = Float64List(w * h);
  for (var i = 0; i < w * h; i++) {
    final dl = lab[i * 3] - background[0];
    final da = lab[i * 3 + 1] - background[1];
    final db = lab[i * 3 + 2] - background[2];
    dist[i] = sqrt(dl * dl + da * da + db * db);
  }
  final threshold = max(_otsu(dist), _minColorDistance);
  var mask = Uint8List(w * h);
  for (var i = 0; i < w * h; i++) {
    if (dist[i] > threshold) mask[i] = 1;
  }
  mask = _dilate(_erode(mask, w, h, 2), w, h, 2);
  mask = _erode(_dilate(mask, w, h, 2), w, h, 2);
  _fillHoles(mask, w, h);

  final objects = <FoundObject>[];
  final labels = Int32List(w * h);
  var next = 0;
  for (var start = 0; start < w * h; start++) {
    if (mask[start] == 0 || labels[start] != 0) continue;
    final pixels = _flood(mask, labels, w, h, start, ++next);
    final object = _describe(pixels, lab, w, h);
    if (object == null) continue;
    objects.add(
      FoundObject(
        box: Rect.fromLTRB(
          object.box.left / scale,
          object.box.top / scale,
          object.box.right / scale,
          object.box.bottom / scale,
        ),
        appearance: object.appearance,
      ),
    );
  }
  return objects;
}

/// 물체를 찾기 전에 사진의 긴 변을 이 크기로 줄인다.
const objectFinderSide = 640;

/// 배경과 이만큼은 달라야 물체로 본다. 알약이 없는 사진에서 잡티를 물체로 잡지 않게 한다.
const _minColorDistance = 12.0;

/// 이미지 넓이 대비 덩어리 넓이의 범위.
const _minAreaRatio = 0.002;
const _maxAreaRatio = 0.3;

/// 이 픽셀 수 안으로 사진 가장자리에 닿으면 비네팅·책상 끝 같은 배경으로 본다.
const _edgeMargin = 4;

FoundObject? _describe(List<int> pixels, Float64List lab, int w, int h) {
  final area = pixels.length;
  if (area < _minAreaRatio * w * h || area > _maxAreaRatio * w * h) {
    return null;
  }
  var x1 = w, y1 = h, x2 = 0, y2 = 0;
  var sl = 0.0, sa = 0.0, sb = 0.0, sx = 0.0, sy = 0.0;
  for (final p in pixels) {
    final x = p % w, y = p ~/ w;
    x1 = min(x1, x);
    y1 = min(y1, y);
    x2 = max(x2, x + 1);
    y2 = max(y2, y + 1);
    sl += lab[p * 3];
    sa += lab[p * 3 + 1];
    sb += lab[p * 3 + 2];
    sx += x;
    sy += y;
  }
  if (x1 <= _edgeMargin ||
      y1 <= _edgeMargin ||
      x2 >= w - _edgeMargin ||
      y2 >= h - _edgeMargin) {
    return null;
  }
  // 픽셀 좌표의 공분산 고유값으로 긴 축과 짧은 축을 구한다.
  final mx = sx / area, my = sy / area;
  var cxx = 0.0, cyy = 0.0, cxy = 0.0;
  for (final p in pixels) {
    final dx = p % w - mx, dy = p ~/ w - my;
    cxx += dx * dx;
    cyy += dy * dy;
    cxy += dx * dy;
  }
  cxx /= area;
  cyy /= area;
  cxy /= area;
  final mid = (cxx + cyy) / 2;
  final spread = sqrt(pow((cxx - cyy) / 2, 2) + cxy * cxy);
  final elongation = sqrt((mid + spread) / max(mid - spread, 1e-6));
  return FoundObject(
    box: Rect.fromLTRB(
      x1.toDouble(),
      y1.toDouble(),
      x2.toDouble(),
      y2.toDouble(),
    ),
    appearance: Appearance(
      l: sl / area,
      a: sa / area,
      b: sb / area,
      elongation: elongation,
    ),
  );
}

/// sRGB를 CIELAB(D65)로 바꾼다. [l, a, b, l, a, b, ...]
Float64List _toLab(img.Image image) {
  final linear = Float64List.fromList([
    for (var v = 0; v < 256; v++)
      v / 255 > 0.04045
          ? pow((v / 255 + 0.055) / 1.055, 2.4).toDouble()
          : v / 255 / 12.92,
  ]);
  double f(double t) =>
      t > 0.008856 ? pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final out = Float64List(image.width * image.height * 3);
  var i = 0;
  for (final p in image) {
    final r = linear[p.r.toInt()];
    final g = linear[p.g.toInt()];
    final b = linear[p.b.toInt()];
    final fx = f((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047);
    final fy = f(0.2126 * r + 0.7152 * g + 0.0722 * b);
    final fz = f((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883);
    out[i++] = 116 * fy - 16;
    out[i++] = 500 * (fx - fy);
    out[i++] = 200 * (fy - fz);
  }
  return out;
}

/// 가장자리 띠(짧은 변의 2%) 픽셀의 채널별 중앙값.
List<double> _borderMedian(Float64List lab, int w, int h) {
  final k = max(2, (0.02 * min(w, h)).floor());
  final channels = [<double>[], <double>[], <double>[]];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (x >= k && x < w - k && y >= k && y < h - k) continue;
      final i = (y * w + x) * 3;
      for (var c = 0; c < 3; c++) {
        channels[c].add(lab[i + c]);
      }
    }
  }
  return [for (final values in channels) (values..sort())[values.length ~/ 2]];
}

/// 두 무리로 가장 잘 나뉘는 값 (Otsu, 구간 128개).
double _otsu(Float64List values) {
  const bins = 128;
  var lo = double.infinity, hi = -double.infinity;
  for (final v in values) {
    lo = min(lo, v);
    hi = max(hi, v);
  }
  if (hi <= lo) return hi;
  final width = (hi - lo) / bins;
  final hist = List.filled(bins, 0);
  for (final v in values) {
    hist[min(bins - 1, ((v - lo) / width).floor())]++;
  }
  final total = values.length;
  var sumAll = 0.0;
  for (var i = 0; i < bins; i++) {
    sumAll += hist[i] * (lo + i * width);
  }
  var weight = 0, sum = 0.0, best = -1.0, threshold = lo;
  for (var i = 0; i < bins; i++) {
    weight += hist[i];
    sum += hist[i] * (lo + i * width);
    if (weight == 0 || weight == total) continue;
    final between =
        pow(sumAll * weight / total - sum, 2) /
        (weight * (total - weight)) *
        total;
    if (between > best) {
      best = between.toDouble();
      threshold = lo + i * width;
    }
  }
  return threshold;
}

/// 십자 모양(상하좌우)으로 [times]번 깎는다. 이미지 밖은 배경으로 본다.
Uint8List _erode(Uint8List mask, int w, int h, int times) =>
    _morph(mask, w, h, times, erode: true);

Uint8List _dilate(Uint8List mask, int w, int h, int times) =>
    _morph(mask, w, h, times, erode: false);

Uint8List _morph(
  Uint8List mask,
  int w,
  int h,
  int times, {
  required bool erode,
}) {
  // 깎기는 이웃 중 하나라도 배경이면 배경, 불리기는 이웃 중 하나라도 물체면 물체.
  final keep = erode ? 0 : 1;
  var src = mask;
  for (var t = 0; t < times; t++) {
    final dst = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final left = x > 0 ? src[i - 1] : 0;
        final right = x < w - 1 ? src[i + 1] : 0;
        final up = y > 0 ? src[i - w] : 0;
        final down = y < h - 1 ? src[i + w] : 0;
        final hit =
            src[i] == keep ||
            left == keep ||
            right == keep ||
            up == keep ||
            down == keep;
        dst[i] = hit ? keep : 1 - keep;
      }
    }
    src = dst;
  }
  return src;
}

/// 가장자리에서 이어지지 않는 배경(물체 안의 구멍)을 물체로 채운다.
void _fillHoles(Uint8List mask, int w, int h) {
  final outside = Uint8List(w * h);
  final stack = <int>[];
  void push(int i) {
    if (mask[i] == 0 && outside[i] == 0) {
      outside[i] = 1;
      stack.add(i);
    }
  }

  for (var x = 0; x < w; x++) {
    push(x);
    push((h - 1) * w + x);
  }
  for (var y = 0; y < h; y++) {
    push(y * w);
    push(y * w + w - 1);
  }
  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    final x = i % w, y = i ~/ w;
    if (x > 0) push(i - 1);
    if (x < w - 1) push(i + 1);
    if (y > 0) push(i - w);
    if (y < h - 1) push(i + w);
  }
  for (var i = 0; i < w * h; i++) {
    if (outside[i] == 0) mask[i] = 1;
  }
}

/// [start]에서 상하좌우로 이어진 물체 픽셀에 [label]을 붙이고 돌려준다.
List<int> _flood(
  Uint8List mask,
  Int32List labels,
  int w,
  int h,
  int start,
  int label,
) {
  final pixels = <int>[];
  final stack = [start];
  labels[start] = label;
  void visit(int n) {
    if (mask[n] == 1 && labels[n] == 0) {
      labels[n] = label;
      stack.add(n);
    }
  }

  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    pixels.add(i);
    final x = i % w, y = i ~/ w;
    if (x > 0) visit(i - 1);
    if (x < w - 1) visit(i + 1);
    if (y > 0) visit(i - w);
    if (y < h - 1) visit(i + w);
  }
  return pixels;
}
