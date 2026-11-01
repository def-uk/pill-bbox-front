import 'dart:typed_data';

/// 복용 사진 저장소. DB에는 [save]가 돌려준 상대 경로만 둔다.
///
/// 기기는 FilePhotoStorageService(앱 전용 폴더), 웹은 DbPhotoStorageService(브라우저 저장소)를 쓴다.
abstract class PhotoStorageService {
  /// 사진을 저장하고 상대 경로를 돌려준다.
  Future<String> save(Uint8List bytes);

  /// 저장한 사진. 없으면 null.
  Future<Uint8List?> load(String relativePath);

  Future<void> delete(String relativePath);
}

/// 새 사진의 상대 경로.
String newPhotoPath() => 'photos/${DateTime.now().microsecondsSinceEpoch}.jpg';
