import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/photo_resize.dart';

/// 갤러리(웹은 파일 선택 창)에서 사진 한 장을 골라 저장할 크기로 줄인다.
class PhotoPickerService {
  final _picker = ImagePicker();

  /// 고른 사진. 고르지 않고 닫으면 null.
  Future<Uint8List?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      // 플랫폼이 먼저 줄인다. iOS는 이때 HEIC 사진을 JPEG로 바꾼다.
      maxWidth: photoMaxSide.toDouble(),
      maxHeight: photoMaxSide.toDouble(),
      imageQuality: photoJpegQuality,
    );
    if (file == null) return null;
    return compute(shrinkPhoto, await file.readAsBytes());
  }
}
