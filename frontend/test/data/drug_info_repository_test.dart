import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/repositories/drug_info_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/services/database_service.dart';
import 'package:pillbbox/data/services/drug_info_service.dart';
import 'package:pillbbox/ui/medication/drug_info_view_model.dart';

import '../helpers.dart';

void main() {
  late DatabaseService db;
  late MedicationRepository medications;
  late List<Uri> requests;
  late DrugInfoRepository drugs;

  setUp(() {
    db = createTestDatabase();
    medications = MedicationRepository(db, FakePhotoStorageService());
    requests = [];
    drugs = DrugInfoRepository(db, fakeDrugInfo(requests: requests));
  });
  tearDown(() => db.close());

  Future<int> addMedication(String name) => medications.save(
    categoryId: null,
    name: name,
    dosePerTake: 1,
    times: const [],
  );

  test('서버 주소가 없으면 쓰지 않는다', () async {
    final off = DrugInfoService(baseUrl: '');
    expect(off.available, isFalse);
    expect(off.search('두통'), throwsA(isA<DrugInfoException>()));
  });

  test('찾기와 오류 메시지', () async {
    final page = await drugs.search('두통약');
    expect(page.items.map((d) => d.itemSeq), ['200000001', '200000002']);
    expect(page.items.first.looks, '원형 · 하양 · GN');
    expect(
      requests.single.toString(),
      'https://api.test/v1/drugs?q=%EB%91%90%ED%86%B5%EC%95%BD&page=1',
    );

    final busy = DrugInfoRepository(db, fakeDrugInfo(searchStatus: 429));
    expect(
      busy.search('두통'),
      throwsA(
        isA<DrugInfoException>().having(
          (e) => e.message,
          'message',
          '잠시 뒤에 다시 시도해 주세요',
        ),
      ),
    );
  });

  test('이은 약 정보를 기기에 두고, 약을 지우면 함께 지운다', () async {
    final id = await addMedication('두통약정500밀리그램');
    expect(await drugs.cached(id), isNull);

    final detail = await drugs.link(id, '200000001');
    expect(detail!.guide!.efficacy, '두통, 치통에 씁니다.');
    expect(detail.size, '8 × 8 × 3.2mm');

    final cached = (await drugs.cached(id))!;
    expect(cached.detail.name, '두통약정500밀리그램');
    expect(cached.detail.guide!.storage, '실온에서 보관하십시오.');
    expect(cached.stale, isFalse);

    expect(await drugs.link(id, '999'), isNull);
    expect((await drugs.cached(id))!.detail.itemSeq, '200000001');

    await medications.delete(id);
    expect(await drugs.cached(id), isNull);
  });

  group('약 정보 화면', () {
    test('이름이 꼭 같은 약이 하나면 바로 잇는다', () async {
      final id = await addMedication('두통약정500밀리그램');
      final vm = DrugInfoViewModel(
        medicationId: id,
        medications: medications,
        drugs: drugs,
      );
      await vm.load();
      expect(vm.choosing, isFalse);
      expect(vm.detail!.itemSeq, '200000001');
      expect((await drugs.cached(id))!.detail.itemSeq, '200000001');
    });

    test('같은 이름이 없으면 고르게 하고, 복약 정보가 없는 약도 잇는다', () async {
      final id = await addMedication('혈압약');
      final vm = DrugInfoViewModel(
        medicationId: id,
        medications: medications,
        drugs: drugs,
      );
      await vm.load();
      expect(vm.choosing, isTrue);
      expect(vm.candidates!.items.single.name, '혈압약정');

      await vm.choose(vm.candidates!.items.single);
      expect(vm.choosing, isFalse);
      expect(vm.detail!.guide, isNull);
    });

    test('서버가 없어도 받아 둔 정보를 보여 준다', () async {
      final id = await addMedication('두통약정500밀리그램');
      await drugs.link(id, '200000001');

      final vm = DrugInfoViewModel(
        medicationId: id,
        medications: medications,
        drugs: DrugInfoRepository(db, DrugInfoService(baseUrl: '')),
      );
      await vm.load();
      expect(vm.available, isFalse);
      expect(vm.detail!.guide!.efficacy, '두통, 치통에 씁니다.');
    });
  });
}
