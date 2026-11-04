import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo_storage_service.dart';

/// 복용 사진을 앱 전용 폴더에 둔다.
///
/// iOS는 앱을 업데이트하면 컨테이너 경로가 바뀌므로 DB에는 상대 경로만 저장한다.
class FilePhotoStorageService implements PhotoStorageService {
  FilePhotoStorageService({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDirectory;

  @override
  Future<String> save(Uint8List bytes) async {
    final relativePath = newPhotoPath();
    final file = await _file(relativePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return relativePath;
  }

  @override
  Future<Uint8List?> load(String relativePath) async {
    final file = await _file(relativePath);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> delete(String relativePath) async {
    final file = await _file(relativePath);
    if (await file.exists()) await file.delete();
  }

  Future<File> _file(String relativePath) async =>
      File(p.join((await _baseDirectory()).path, relativePath));
}
