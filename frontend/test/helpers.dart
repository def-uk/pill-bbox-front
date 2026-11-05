import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillbbox/data/services/database_service.dart';
import 'package:pillbbox/data/services/drug_info_service.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/photo_picker_service.dart';
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

/// 카메라든 갤러리든 샘플 사진을 돌려준다.
class SamplePhotoPickerService extends PhotoPickerService {
  final sources = <PhotoSource>[];

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    sources.add(source);
    return (await rootBundle.load(
      FakePillDetector.photoAsset,
    )).buffer.asUint8List();
  }
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

/// 처음 열 때 나오는 나이 확인을 통과한다.
Future<void> passAgeGate(WidgetTester tester) async {
  await pumpUntilFound(tester, find.text('네, 만 14세 이상이에요'));
  await tester.tap(find.text('네, 만 14세 이상이에요'));
}

/// 저장 뒤 보상 결과 화면이 나왔으면 닫는다. 보상은 기록 시각에 따라 달라 나오지 않을 수도 있다.
Future<void> dismissRewardIfShown(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  if (find.text('보상').evaluate().isEmpty) return;
  await tester.tap(find.text('확인'));
  await tester.pump(const Duration(milliseconds: 500));
}

/// 맥미니 백엔드의 `/v1/drugs`를 흉내 낸다. [requests]에 받은 주소를 남긴다.
DrugInfoService fakeDrugInfo({List<Uri>? requests, int searchStatus = 200}) =>
    DrugInfoService(
      baseUrl: 'https://api.test/',
      client: MockClient((request) async {
        requests?.add(request.url);
        final path = request.url.path;
        if (path == '/v1/drugs') {
          if (searchStatus != 200) return http.Response('{}', searchStatus);
          final q = request.url.queryParameters['q']!;
          final items = [
            for (final d in fakeDrugs)
              if (d['name']!.toString().contains(q)) d,
          ];
          return _json({'total': items.length, 'page': 1, 'items': items});
        }
        final seq = path.split('/').last;
        final drug = fakeDrugs.where((d) => d['item_seq'] == seq).firstOrNull;
        if (drug == null) return _json({'detail': '식약처에 없는 약입니다'}, 404);
        return _json({
          ...drug,
          'chart': '흰색의 원형 정제',
          'length_long': 8.0,
          'length_short': 8.0,
          'thickness': 3.2,
          'guide': seq == '200000001'
              ? {'efficacy': '두통, 치통에 씁니다.', 'storage': '실온에서 보관하십시오.'}
              : null,
        });
      }),
    );

const fakeDrugs = [
  {
    'item_seq': '200000001',
    'name': '두통약정500밀리그램',
    'company': '가나제약',
    'otc': '일반의약품',
    'shape': '원형',
    'colors': ['하양'],
    'print_front': 'GN',
    'has_image': false,
  },
  {
    'item_seq': '200000002',
    'name': '두통약정250밀리그램',
    'company': '가나제약',
    'otc': '일반의약품',
    'has_image': false,
  },
  {
    'item_seq': '200000003',
    'name': '혈압약정',
    'company': '다라제약',
    'otc': '전문의약품',
    'has_image': false,
  },
];

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);
