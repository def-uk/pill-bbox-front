import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/repositories/intake_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/services/database_service.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/ui/result/result_view_model.dart';
import 'package:pillbbox/ui/home/home_view_model.dart';
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
      HomeViewModel.samplePhotoAsset,
    )).buffer.asUint8List();
    final vm = ResultViewModel(
      photo: photo,
      detector: FakePillDetector(delay: Duration.zero),
      medications: medications,
      intakes: intakes,
      labels: PillLabelService(),
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

  PillChoice choiceOf(ResultViewModel vm, String name) =>
      vm.choices.singleWhere((c) => c.name == name);

  test('인식 결과를 지금 예정과 비교하고, 못 찾은 예정 약과 처음 기록하는 약도 보여 준다', () async {
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
  });

  test('약을 바꾸고 더한 대로 저장한다', () async {
    await register();
    final vm = await detect();
    final b = vm.medications.singleWhere((m) => m.name == 'B');
    final d = vm.medications.singleWhere((m) => m.name == 'D');

    vm.changeMedication(lineOf(vm, '샘플약 C (분홍색 원형)'), choiceOf(vm, 'B'));
    expect(
      lineOf(vm, 'B').status,
      MatchStatus.ok,
      reason: 'C로 잘못 인식한 1정을 B로 옮겼다',
    );
    expect(vm.lines.every((l) => l.isRegistered), isTrue);

    vm.addMedication(choiceOf(vm, 'D'));
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

    vm.changeMedication(lineOf(vm, 'A'), choiceOf(vm, 'D'));

    expect(lineOf(vm, 'A').count, 0);
    expect(lineOf(vm, 'A').status, MatchStatus.missing);
    expect(lineOf(vm, 'D').count, 2);
  });

  test('등록한 약이 없어도 인식한 약을 등록하며 저장한다', () async {
    final vm = await detect();
    expect(vm.lines.every((l) => !l.isRegistered), isTrue);

    expect(await vm.save(), isTrue);

    final registered = {
      for (final m in await medications.getAll())
        m.categoryId: (m.dosePerTake, m.times.length),
    };
    expect(registered, {9001: (2, 0), 9002: (1, 0), 9003: (1, 0)});
    final saved = await intakes.recordsOn(now);
    expect([for (final r in saved) r.count]..sort(), [1, 1, 2]);
  });

  test('모델이 놓친 약은 등록하지 않은 약 중에서도 고를 수 있다', () async {
    final vm = await detect();
    vm.changeMedication(
      lineOf(vm, '샘플약 C (분홍색 원형)'),
      choiceOf(vm, '샘플약 A (흰색 원형)'),
    );
    vm.addMedication(choiceOf(vm, '샘플약 C (분홍색 원형)'));

    expect(lineOf(vm, '샘플약 A (흰색 원형)').count, 3);
    expect(lineOf(vm, '샘플약 C (분홍색 원형)').count, 1);
  });

  test('저장하면 처음 기록한 약이 등록한 약 줄로 바뀌어, 같은 약을 또 등록하지 않는다', () async {
    final vm = await detect();
    await vm.save();
    expect(vm.lines.every((l) => l.isRegistered), isTrue);
    expect((await medications.getAll()).length, 3);
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
