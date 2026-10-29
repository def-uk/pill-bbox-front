import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 복용 사진을 앱 전용 폴더에 둔다.
///
/// iOS는 앱을 업데이트하면 컨테이너 경로가 바뀌므로 DB에는 상대 경로만 저장한다.
class PhotoStorageService {
  PhotoStorageService({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDirectory;

  /// 사진을 저장하고 상대 경로를 돌려준다.
  Future<String> save(Uint8List bytes) async {
    final relativePath = p.join(
      'photos',
      '${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final file = File(await resolve(relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return relativePath;
  }

  Future<String> resolve(String relativePath) async =>
      p.join((await _baseDirectory()).path, relativePath);

  Future<void> delete(String relativePath) async {
    final file = File(await resolve(relativePath));
    if (await file.exists()) await file.delete();
  }
}
