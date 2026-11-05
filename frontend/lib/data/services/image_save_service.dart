import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// 공유 카드 이미지를 저장한다 (file_picker). 웹은 내려받기로 저장한다.
///
/// 앱은 저장 창으로 파일에 저장한다. 사진첩에 바로 넣으려면 플랫폼 권한 설정이 필요한 플러그인을 더해야 한다.
class ImageSaveService {
  /// 저장했으면 true. 저장 창에서 취소하면 false. 웹은 내려받기를 시작하면 저장한 것으로 본다.
  Future<bool> savePng(String fileName, Uint8List bytes) async {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'image/png',
    );
    return kIsWeb || saved != null;
  }
}
