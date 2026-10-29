import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/repositories/intake_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/services/database_service.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/ui/capture/capture_view_model.dart';
import 'package:pillbbox/ui/result/result_view_model.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
  late IntakeRepository intakes;
  late ResultViewModel vm;

  setUp(() async {
    db = createTestDatabase();
    intakes = IntakeRepository(db, FakePhotoStorageService());
    final photo = (await rootBundle.load(
      CaptureViewModel.samplePhotoAsset,
    )).buffer.asUint8List();
    vm = ResultViewModel(
      photo: photo,
      detector: FakePillDetector(delay: Duration.zero),
      medications: MedicationRepository(db),
      intakes: intakes,
    );
  });
  tearDown(() => db.close());

  test('탐지 결과를 약 종류별 개수로 묶고, 신뢰도 0.5 미만은 확인 필요로 표시한다', () async {
    await vm.detect();

    expect(vm.status, ResultStatus.ready);
    expect(
      [for (final p in vm.pills) (p.name, p.count, p.needsReview)],
      [
        ('샘플약 A (흰색 원형)', 2, false),
        ('샘플약 B (노란색 타원형)', 1, false),
        ('샘플약 C (분홍색 원형)', 1, true),
      ],
    );
  });

  test('개수를 고친 대로 저장하고, 모두 0개면 저장할 수 없다', () async {
    await vm.detect();
    vm
      ..decrement(1)
      ..decrement(1)
      ..increment(0);
    expect(vm.pills[1].count, 0, reason: '0 아래로 내려가지 않는다');

    expect(await vm.save(), isTrue);
    final records = await intakes.recordsOn(DateTime.now());
    expect([for (final r in records) r.count], [3, 1]);

    for (var i = 0; i < vm.pills.length; i++) {
      while (vm.pills[i].count > 0) {
        vm.decrement(i);
      }
    }
    expect(vm.canSave, isFalse);
  });
}
