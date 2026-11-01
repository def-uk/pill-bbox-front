import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/services/camera_service.dart';
import 'package:pillbbox/data/services/database_service.dart';
import 'package:pillbbox/data/services/photo_storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 메모리 DB. 위젯 테스트의 가짜 시간 안에서도 돌도록 isolate를 쓰지 않는다.
DatabaseService createTestDatabase() {
  sqfliteFfiInit();
  return DatabaseService(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
  );
}

/// 파일 대신 메모리에 사진을 둔다.
class FakePhotoStorageService implements PhotoStorageService {
  final photos = <String, Uint8List>{};

  @override
  Future<String> save(Uint8List bytes) async {
    final path = 'photos/${photos.length}.jpg';
    photos[path] = bytes;
    return path;
  }

  @override
  Future<Uint8List?> load(String relativePath) async => photos[relativePath];

  @override
  Future<void> delete(String relativePath) async => photos.remove(relativePath);
}

/// 카메라가 없는 기기.
class NoCameraService extends CameraService {
  @override
  Future<bool> open() async => false;
}

/// 실제 비동기 작업(에셋 읽기 등)과 가짜 시계의 타이머를 함께 진행하며 [finder]가 나올 때까지 그린다.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
    if (finder.evaluate().isNotEmpty) {
      // 화면 전환·시트 애니메이션이 끝난 뒤에 누르도록 기다린다.
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
  }
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .toList();
  throw TestFailure('찾지 못함: $finder, 화면: $texts');
}
