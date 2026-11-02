import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// 갤러리(웹은 파일 선택 창)에서 사진 한 장을 고른다.
class PhotoPickerService {
  /// 저장하는 사진이 너무 커지지 않게 긴 변을 줄인다. 탐지 모델 입력(640)보다 충분히 크다.
  static const maxSide = 1920.0;

  final _picker = ImagePicker();

  /// 고른 사진. 고르지 않고 닫으면 null.
  Future<Uint8List?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxSide,
      maxHeight: maxSide,
      // iOS의 HEIC 사진을 JPEG로 바꾼다.
      imageQuality: 90,
    );
    return file?.readAsBytes();
  }
}
