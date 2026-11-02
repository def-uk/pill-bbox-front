import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 저장하는 사진의 긴 변. 탐지 모델 입력(640)보다 크고, 기록 화면에서 보기에 넉넉하다.
const photoMaxSide = 1280;

/// 저장하는 사진의 JPEG 품질.
const photoJpegQuality = 80;

/// 사진을 긴 변 [maxSide] 이하의 JPEG로 줄인다.
///
/// 이미 그런 JPEG이면 그대로 돌려준다. 웹의 image_picker는 PNG를 PNG로 두므로 JPEG가 아니면 다시 쓴다.
/// 읽을 수 없는 형식이면 그대로 돌려준다.
Uint8List shrinkPhoto(Uint8List bytes, {int maxSide = photoMaxSide}) {
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (decoder == null || info == null) return bytes;
  if (decoder is img.JpegDecoder && max(info.width, info.height) <= maxSide) {
    return bytes;
  }
  final decoded = decoder.decode(bytes);
  if (decoded == null) return bytes;
  var image = img.bakeOrientation(decoded);
  if (max(image.width, image.height) > maxSide) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? maxSide : null,
      height: image.width < image.height ? maxSide : null,
      interpolation: img.Interpolation.average,
    );
  }
  return img.encodeJpg(image, quality: photoJpegQuality);
}
