import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// 엑셀 백업 파일을 고르고 저장한다 (file_picker). 웹은 내려받기로 저장한다.
class BackupFileService {
  static const _mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// .xlsx 파일을 골라 내용을 돌려준다. 고르지 않으면 null.
  ///
  /// 웹은 사용자가 누른 그 처리 안에서 불러야 브라우저가 파일 창을 막지 않는다.
  Future<Uint8List?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    return file?.readAsBytes();
  }

  /// 저장했으면 true. 저장 창에서 취소하면 false.
  ///
  /// 웹은 저장 창 없이 내려받기만 하고 언제나 null을 돌려주므로, 내려받기를 시작하면 저장한 것으로 본다.
  Future<bool> save(String fileName, Uint8List bytes) async {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: _mimeType,
    );
    return kIsWeb || saved != null;
  }
}
