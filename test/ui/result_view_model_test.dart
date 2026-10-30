import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/repositories/intake_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/services/database_service.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/ui/capture/capture_view_model.dart';
import 'package:pillbbox/ui/result/result_view_model.dart';
import 'package:pillbbox/utils/intake_matcher.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 30, 8, 10);
  late DatabaseService db;
  late MedicationRepository medications;
  late IntakeRepository intakes;

  setUp(() {
    db = createTestDatabase();
    final photos = FakePhotoStorageService();
    medications = MedicationRepository(db, photos);
    intakes = IntakeRepository(db, photos, now: () => now);
  });
  tearDown(() => db.close());

  Future<ResultViewModel> detect() async {
    final photo = (await rootBundle.load(
      CaptureViewModel.samplePhotoAsset,
    )).buffer.asUint8List();
    final vm = ResultViewModel(
      photo: photo,
      detector: FakePillDetector(delay: Duration.zero),
      medications: medications,
      intakes: intakes,
      now: () => now,
    );
    await vm.detect();
    return vm;
  }

  /// 샘플 사진의 인식 결과: A 2정, B 1정, C 1정(신뢰도 0.42).
  Future<void> register() async {
    await medications.save(
      categoryId: 9001,
      name: 'A',
      dosePerTake: 2,
      times: const [480],
    );
    await medications.save(
      categoryId: 9002,
      name: 'B',
      dosePerTake: 2,
      times: const [480],
    );
    await medications.save(
      categoryId: null,
      name: 'D',
      dosePerTake: 1,
      times: const [480],
    );
  }

  ResultLine lineOf(ResultViewModel vm, String name) =>
      vm.lines.singleWhere((l) => l.name == name);

  test('인식 결과를 지금 예정과 비교하고, 못 찾은 예정 약과 등록하지 않은 약도 보여 준다', () async {
    await register();
    final vm = await detect();

    expect(vm.status, ResultStatus.ready);
    expect(
      [
        for (final l in vm.lines)
          (
            l.name,
            l.count,
            l.expected,
            l.status,
            l.isRegistered,
            l.needsReview,
          ),
      ],
      [
        ('A', 2, 2, MatchStatus.ok, true, false),
        ('B', 1, 2, MatchStatus.missing, true, false),
        ('D', 0, 1, MatchStatus.missing, true, false),
        ('샘플약 C (분홍색 원형)', 1, 0, MatchStatus.unscheduled, false, true),
      ],
    );
    expect(vm.hasUnregistered, isTrue);
  });

  test('약을 바꾸고 더한 대로 등록한 약만 저장한다', () async {
    await register();
    final vm = await detect();
    final b = vm.medications.singleWhere((m) => m.name == 'B');
    final d = vm.medications.singleWhere((m) => m.name == 'D');

    vm.changeMedication(lineOf(vm, '샘플약 C (분홍색 원형)'), b);
    expect(
      lineOf(vm, 'B').status,
      MatchStatus.ok,
      reason: 'C로 잘못 인식한 1정을 B로 옮겼다',
    );
    expect(vm.hasUnregistered, isFalse);

    vm.addMedication(d);
    expect(await vm.save(), isTrue);

    final saved = {
      for (final r in await intakes.recordsOn(now)) r.medicationId: r.count,
    };
    expect(saved, {
      vm.medications.singleWhere((m) => m.name == 'A').id: 2,
      b.id: 2,
      d.id: 1,
    });
  });

  test('등록한 약 줄을 다른 약으로 바꾸면 원래 약의 예정은 0정으로 남는다', () async {
    await register();
    final vm = await detect();
    final d = vm.medications.singleWhere((m) => m.name == 'D');

    vm.changeMedication(lineOf(vm, 'A'), d);

    expect(lineOf(vm, 'A').count, 0);
    expect(lineOf(vm, 'A').status, MatchStatus.missing);
    expect(lineOf(vm, 'D').count, 2);
  });

  test('등록한 약이 없으면 저장할 수 없다', () async {
    final vm = await detect();

    expect(vm.lines.every((l) => !l.isRegistered), isTrue);
    expect(vm.canSave, isFalse);
  });

  test('모두 0정이면 저장할 수 없다', () async {
    await register();
    final vm = await detect();
    for (final line in vm.lines) {
      for (var i = 0; i < line.count; i++) {
        vm.decrement(lineOf(vm, line.name));
      }
    }
    expect(vm.canSave, isFalse);
  });
}
