import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/photo_resize.dart';

enum PhotoSource { camera, gallery }

/// 카메라로 찍거나 갤러리(웹은 파일 선택 창)에서 사진 한 장을 골라 저장할 크기로 줄인다.
///
/// 웹의 카메라는 휴대폰 브라우저에서 바로 열리고, PC 브라우저에서는 파일 선택 창이 열린다.
class PhotoPickerService {
  final _picker = ImagePicker();

  /// 찍거나 고른 사진. 그냥 닫으면 null. 카메라가 없으면 예외를 던진다.
  Future<Uint8List?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: switch (source) {
        PhotoSource.camera => ImageSource.camera,
        PhotoSource.gallery => ImageSource.gallery,
      },
      // 플랫폼이 먼저 줄인다. iOS는 이때 HEIC 사진을 JPEG로 바꾼다.
      maxWidth: photoMaxSide.toDouble(),
      maxHeight: photoMaxSide.toDouble(),
      imageQuality: photoJpegQuality,
    );
    if (file == null) return null;
    return compute(shrinkPhoto, await file.readAsBytes());
  }
}
