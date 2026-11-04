import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/appearance.dart';
import 'package:pillbbox/data/models/detection.dart';
import 'package:pillbbox/data/repositories/intake_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/services/database_service.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/pill_detector.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/ui/result/result_view_model.dart';
import 'package:pillbbox/utils/intake_matcher.dart';
import 'package:pillbbox/utils/object_finder.dart';

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

  /// [objects]는 물체 찾기 결과. 기본은 아무것도 찾지 않는다.
  Future<ResultViewModel> detect({
    PillDetector? detector,
    List<FoundObject> objects = const [],
  }) async {
    final photo = (await rootBundle.load(
      FakePillDetector.photoAsset,
    )).buffer.asUint8List();
    final vm = ResultViewModel(
      photo: photo,
      detector: detector ?? FakePillDetector(delay: Duration.zero),
      medications: medications,
      intakes: intakes,
      labels: PillLabelService(),
      objectFinder: (_) async => objects,
      now: () => now,
    );
    await vm.detect();
    return vm;
  }

  /// 샘플 사진의 인식 결과: A 2정, B 1정, C 1정.
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
          (l.name, l.count, l.expected, l.status, l.isRegistered),
      ],
      [
        ('A', 2, 2, MatchStatus.ok, true),
        ('B', 1, 2, MatchStatus.missing, true),
        ('D', 0, 1, MatchStatus.missing, true),
        ('샘플약 C (주황색 타원형)', 1, 0, MatchStatus.unscheduled, false),
      ],
    );
  });

  test('약을 바꾸고 더한 대로 저장한다', () async {
    await register();
    final vm = await detect();
    final b = vm.medications.singleWhere((m) => m.name == 'B');
    final d = vm.medications.singleWhere((m) => m.name == 'D');

    vm.changeMedication(lineOf(vm, '샘플약 C (주황색 타원형)'), choiceOf(vm, 'B'));
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
      lineOf(vm, '샘플약 C (주황색 타원형)'),
      choiceOf(vm, '샘플약 A (흰색)'),
    );
    vm.addMedication(choiceOf(vm, '샘플약 C (주황색 타원형)'));

    expect(lineOf(vm, '샘플약 A (흰색)').count, 3);
    expect(lineOf(vm, '샘플약 C (주황색 타원형)').count, 1);
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

  test('알약 하나에 두 약이 겹쳐 잡히면 1정으로 세고, 헷갈린 약을 바꿀 후보로 둔다', () async {
    const box = Rect.fromLTRB(100, 100, 200, 200);
    final vm = await detect(
      detector: _FixedDetector(const [
        Detection(
          categoryId: 9001,
          name: '샘플약 A (흰색)',
          confidence: 0.8,
          box: box,
        ),
        Detection(
          categoryId: 9002,
          name: '샘플약 B (노란색 타원형)',
          confidence: 0.6,
          box: Rect.fromLTRB(102, 101, 203, 199),
        ),
      ]),
    );

    expect([for (final l in vm.lines) (l.name, l.count)], [('샘플약 A (흰색)', 1)]);
    expect(
      [for (final c in vm.alternativesOf(vm.lines.single)) c.name],
      ['샘플약 B (노란색 타원형)'],
    );
  });

  group('예전 기록으로 고칠 약 추천', () {
    const orange = Appearance(l: 60, a: 35, b: 55, elongation: 1.8);
    // FakePillDetector의 샘플약 C 박스와 같은 자리에서 찾은 물체.
    const atC = [
      FoundObject(box: Rect.fromLTRB(92, 378, 168, 512), appearance: orange),
    ];

    test('모델이 찾은 알약을 다른 약으로 고쳐 기록하면, 다음 사진에서 그 약으로 바꾸자고 한다', () async {
      await register();
      final first = await detect(objects: atC);
      const c = '샘플약 C (주황색 타원형)';
      expect(first.correctionOf(lineOf(first, c)), isNull);

      first.changeMedication(lineOf(first, c), choiceOf(first, 'B'));
      expect(await first.save(), isTrue);
      final b = first.medications.singleWhere((m) => m.name == 'B');
      expect(
        [for (final (id, _) in await medications.appearances()) id],
        [b.id],
        reason: '고친 약에 색·모양을 남긴다',
      );

      final next = await detect(objects: atC);
      expect(next.correctionOf(lineOf(next, c))?.id, b.id);
      expect(
        next.correctionOf(lineOf(next, 'A')),
        isNull,
        reason: '물체를 못 찾은 줄',
      );
    });

    test('모델이 맞힌 대로 기록했으면 바꾸자고 하지 않는다', () async {
      final first = await detect(objects: atC);
      expect(await first.save(), isTrue);

      final next = await detect(objects: atC);
      final line = lineOf(next, '샘플약 C (주황색 타원형)');
      expect(line.isRegistered, isTrue);
      expect(next.correctionOf(line), isNull);
    });

    test('약마다 최근 색·모양만 남긴다', () async {
      final id = await medications.save(
        categoryId: null,
        name: 'D',
        dosePerTake: 1,
        times: const [],
      );
      for (
        var i = 0;
        i < MedicationRepository.appearancesPerMedication + 5;
        i++
      ) {
        await medications.addAppearance(
          id,
          Appearance(l: i.toDouble(), a: 0, b: 0, elongation: 1),
        );
      }
      final kept = [for (final (_, a) in await medications.appearances()) a.l];
      expect(kept, hasLength(MedicationRepository.appearancesPerMedication));
      expect(kept.reduce((a, b) => a < b ? a : b), 5, reason: '오래된 5개를 지웠다');
    });
  });

  group('알 수 없는 물체', () {
    const yellow = Appearance(l: 70, a: 5, b: 45, elongation: 2.1);
    const purple = Appearance(l: 40, a: 30, b: -30, elongation: 1);
    FoundObject object(Rect box, Appearance appearance) =>
        FoundObject(box: box, appearance: appearance);

    test('모델이 알약을 못 찾으면 알약이 없다고 하고, 찾은 물체에 위에서부터 번호를 붙인다', () async {
      final vm = await detect(
        detector: _NoPillDetector(),
        objects: [
          object(const Rect.fromLTRB(10, 300, 60, 350), purple),
          object(const Rect.fromLTRB(10, 100, 60, 150), yellow),
        ],
      );

      expect(vm.noPills, isTrue);
      expect(
        [for (final o in vm.unknowns) (o.number, o.box.top)],
        [(1, 100), (2, 300)],
      );
      expect(vm.canSave, isFalse);
    });

    test('모델 박스와 절반 넘게 겹치는 물체는 빼고 보여 준다', () async {
      final vm = await detect(
        objects: [
          // FakePillDetector의 큰 흰색 알약 박스(287, 45, 438, 233) 안
          object(const Rect.fromLTRB(300, 60, 420, 220), yellow),
          object(const Rect.fromLTRB(10, 580, 60, 630), purple),
        ],
      );

      expect(vm.noPills, isFalse);
      expect(vm.unknowns.single.box.top, 580);
    });

    test('물체에 약을 고르면 1정으로 기록하고, 다음 사진에서 색·모양이 비슷하면 그 약을 추천한다', () async {
      final first = await detect(
        detector: _NoPillDetector(),
        objects: [object(const Rect.fromLTRB(10, 10, 60, 60), yellow)],
      );
      expect(first.unknowns.single.suggestion, isNull);

      first.identify(first.unknowns.single, choiceOf(first, '샘플약 B (노란색 타원형)'));
      expect(first.unknowns, isEmpty);
      expect(lineOf(first, '샘플약 B (노란색 타원형)').count, 1);
      expect(await first.save(), isTrue);

      final b = (await medications.getAll()).single;
      expect(b.categoryId, 9002);
      expect(
        [for (final (id, _) in await medications.appearances()) id],
        [b.id],
      );

      final next = await detect(
        detector: _NoPillDetector(),
        objects: [
          object(
            const Rect.fromLTRB(10, 10, 60, 60),
            const Appearance(l: 72, a: 4, b: 43, elongation: 2.0),
          ),
          object(const Rect.fromLTRB(10, 100, 60, 150), purple),
        ],
      );
      expect(
        [for (final o in next.unknowns) o.suggestion?.name],
        ['샘플약 B (노란색 타원형)', null],
      );
    });

    test('목록에 없는 약은 이름을 넣어 등록하고, 같은 이름은 한 약으로 센다', () async {
      final vm = await detect(
        detector: _NoPillDetector(),
        objects: [
          object(const Rect.fromLTRB(10, 10, 60, 60), purple),
          object(const Rect.fromLTRB(10, 100, 60, 150), purple),
        ],
      );
      vm.identify(vm.unknowns.first, const PillChoice.custom('비타민 D'));
      expect(
        choiceOf(vm, '비타민 D').isCustom,
        isFalse,
        reason: '고를 수 있는 약에 들어간다',
      );
      vm.identify(vm.unknowns.single, const PillChoice.custom(' 비타민 D '));

      expect(lineOf(vm, '비타민 D').count, 2);
      expect(await vm.save(), isTrue);

      final saved = (await medications.getAll()).single;
      expect(
        (saved.name, saved.categoryId, saved.dosePerTake),
        ('비타민 D', null, 2),
      );
      expect(await medications.appearances(), hasLength(2));
    });

    test('물체에 고른 약을 다른 약으로 바꾸면 색·모양도 바꾼 약에 남긴다', () async {
      final vm = await detect(
        detector: _NoPillDetector(),
        objects: [object(const Rect.fromLTRB(10, 10, 60, 60), yellow)],
      );
      vm.identify(vm.unknowns.single, choiceOf(vm, '샘플약 A (흰색)'));
      vm.changeMedication(
        lineOf(vm, '샘플약 A (흰색)'),
        choiceOf(vm, '샘플약 B (노란색 타원형)'),
      );
      await vm.save();

      final b = (await medications.getAll()).singleWhere(
        (m) => m.categoryId == 9002,
      );
      expect(
        [for (final (id, _) in await medications.appearances()) id],
        [b.id],
      );
    });

    test('모델을 쓰지 못해도 찾은 물체를 골라 기록할 수 있다', () async {
      final vm = await detect(
        detector: _FailingDetector(),
        objects: [object(const Rect.fromLTRB(10, 10, 60, 60), yellow)],
      );

      expect(vm.status, ResultStatus.ready);
      expect((vm.modelFailed, vm.noPills), (true, true));
      vm.identify(vm.unknowns.single, choiceOf(vm, '샘플약 B (노란색 타원형)'));
      expect(await vm.save(), isTrue);
      expect(await intakes.recordsOn(now), hasLength(1));
    });

    test('약이 아니라고 뺀 물체는 기록하지 않는다', () async {
      final vm = await detect(
        detector: _NoPillDetector(),
        objects: [object(const Rect.fromLTRB(10, 10, 60, 60), yellow)],
      );
      vm.dismiss(vm.unknowns.single);

      expect(vm.unknowns, isEmpty);
      expect(vm.canSave, isFalse);
    });
  });
}

class _NoPillDetector implements PillDetector {
  @override
  Future<void> load() async {}

  @override
  Future<List<Detection>> detect(Uint8List imageBytes) async => const [];
}

class _FailingDetector implements PillDetector {
  @override
  Future<void> load() async => throw StateError('모델을 읽지 못했습니다');

  @override
  Future<List<Detection>> detect(Uint8List imageBytes) async => const [];
}

class _FixedDetector implements PillDetector {
  _FixedDetector(this.results);

  final List<Detection> results;

  @override
  Future<void> load() async {}

  @override
  Future<List<Detection>> detect(Uint8List imageBytes) async => results;
}
