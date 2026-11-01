import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/services/db_photo_storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('사진을 저장하고 읽고 지운다', () async {
    sqfliteFfiInit();
    final photos = DbPhotoStorageService(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    final bytes = Uint8List.fromList([1, 2, 3]);

    final path = await photos.save(bytes);
    expect(await photos.load(path), bytes);

    await photos.delete(path);
    expect(await photos.load(path), isNull);
    expect(await photos.load('photos/없는.jpg'), isNull);
  });
}
