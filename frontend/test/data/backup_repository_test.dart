import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/appearance.dart';
import 'package:pillbbox/data/models/cosmetic.dart';
import 'package:pillbbox/data/models/intake_record.dart';
import 'package:pillbbox/data/models/medication.dart';
import 'package:pillbbox/data/models/prescription.dart';
import 'package:pillbbox/data/repositories/backup_repository.dart';
import 'package:pillbbox/data/repositories/collection_repository.dart';
import 'package:pillbbox/data/repositories/drug_info_repository.dart';
import 'package:pillbbox/data/repositories/intake_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/repositories/prescription_repository.dart';
import 'package:pillbbox/data/repositories/reward_repository.dart';
import 'package:pillbbox/data/services/database_service.dart';
import 'package:pillbbox/data/services/drug_info_service.dart';
import 'package:pillbbox/utils/xlsx.dart';

import '../helpers.dart';

void main() {
  late DatabaseService db;
  late MedicationRepository medications;
  late IntakeRepository intakes;
  late PrescriptionRepository prescriptions;
  late CollectionRepository collection;
  late BackupRepository backup;
  var now = DateTime(2026, 10, 30, 8, 10, 23, 456);

  void open() {
    db = createTestDatabase();
    final photos = FakePhotoStorageService();
    medications = MedicationRepository(db, photos);
    intakes = IntakeRepository(db, photos, now: () => now);
    prescriptions = PrescriptionRepository(db, medications, now: () => now);
    final rewards = RewardRepository(
      medications,
      intakes,
      prescriptions,
      DrugInfoRepository(db, DrugInfoService(baseUrl: '')),
    );
    collection = CollectionRepository(db, rewards, now: () => now);
    backup = BackupRepository(medications, intakes, prescriptions, collection);
  }

  setUp(open);
  tearDown(() => db.close());

  /// 복용 시간은 "480,1200"처럼 이어 붙인다 (레코드 안의 리스트는 값으로 비교되지 않는다).
  Future<List<(String, int?, int, String)>> savedMedications() async => [
    for (final m in await medications.getAll())
      (m.name, m.categoryId, m.dosePerTake, m.times.join(',')),
  ];

  Future<List<(String, DateTime, int, IntakeSource)>> savedRecords() async {
    final names = {for (final m in await medications.getAll()) m.id: m.name};
    return [
      for (final r in await intakes.allRecords())
        (names[r.medicationId]!, r.takenAt, r.count, r.source),
    ];
  }

  test('내보낸 엑셀을 빈 기기에서 가져오면 약·기록·색·모양이 같다. 사진은 빠진다', () async {
    final a = await medications.save(
      categoryId: 1900,
      name: '보령부스파정 5mg',
      dosePerTake: 2,
      times: const [480, 1200],
    );
    final d = await medications.save(
      categoryId: null,
      name: '비타민 D',
      dosePerTake: 1,
      times: const [],
    );
    await intakes.addCameraIntake(
      photo: Uint8List(3),
      countsByMedication: {a: 2, d: 1},
    );
    now = DateTime(2026, 10, 30, 20, 5);
    await intakes.addManualIntake(medicationId: a, count: 2);
    await medications.addAppearance(
      d,
      const Appearance(l: 70.5, a: 5, b: 45.25, elongation: 2.1),
    );
    final meds = await savedMedications();
    final records = await savedRecords();

    final bytes = await backup.exportExcel();
    await db.close();
    open();
    final summary = await backup.importExcel(bytes);

    expect(summary, (
      medications: 2,
      records: 3,
      prescriptions: 0,
      skippedRows: 0,
    ));
    expect(await savedMedications(), meds);
    expect(await savedRecords(), [
      for (final (name, t, count, source) in records)
        (
          name,
          t.subtract(Duration(milliseconds: t.millisecond)),
          count,
          source,
        ),
    ], reason: '시각은 초까지 남는다');
    expect(
      (await intakes.allRecords()).every((r) => r.photoPath == null),
      isTrue,
    );
    final (_, appearance) = (await medications.appearances()).single;
    expect(
      (appearance.l, appearance.b, appearance.elongation),
      (70.5, 45.25, 2.1),
    );
  });

  test('같은 파일을 다시 가져오거나 이미 있는 약이면 겹쳐 넣지 않는다', () async {
    final a = await medications.save(
      categoryId: 1900,
      name: 'A',
      dosePerTake: 1,
      times: const [480],
    );
    await intakes.addManualIntake(medicationId: a, count: 1);
    await medications.addAppearance(
      a,
      const Appearance(l: 1, a: 2, b: 3, elongation: 1.5),
    );
    final bytes = await backup.exportExcel();

    expect(await backup.importExcel(bytes), (
      medications: 0,
      records: 0,
      prescriptions: 0,
      skippedRows: 0,
    ));
    expect(await intakes.allRecords(), hasLength(1));
    expect(await medications.appearances(), hasLength(1));
  });

  test('약 번호가 같으면 이름이 달라도 같은 약으로 보고 기록을 붙인다', () async {
    final mine = await medications.save(
      categoryId: 1900,
      name: '부스파',
      dosePerTake: 1,
      times: const [],
    );

    final summary = await backup.importExcel(
      encodeXlsx({
        BackupRepository.medicationSheet: [
          ['이름', '약 번호', '1회 개수', '복용 시간'],
          ['보령부스파정 5mg', 1900, 2, '08:00'],
        ],
        BackupRepository.recordSheet: [
          ['시각', '약', '개수', '방법'],
          ['2026-10-29 08:00:00', '보령부스파정 5mg', 2, '사진'],
        ],
      }),
    );

    expect(summary, (
      medications: 0,
      records: 1,
      prescriptions: 0,
      skippedRows: 0,
    ));
    expect((await intakes.allRecords()).single.medicationId, mine);
    expect(await savedMedications(), [('부스파', 1900, 1, '')]);
  });

  test('엑셀에서 고친 날짜·시각 서식도 읽고, 읽을 수 없는 행은 건너뛴다', () async {
    final summary = await backup.importExcel(
      encodeXlsx({
        BackupRepository.medicationSheet: [
          ['이름', '약 번호', '1회 개수', '복용 시간'],
          // 엑셀이 "08:30"을 시각(하루의 비율)으로 바꾼 경우
          ['A', null, 1, 8.5 / 24],
          ['B', null, 1, '8시'],
        ],
        BackupRepository.recordSheet: [
          ['시각', '약', '개수', '방법'],
          // 2026-10-30 12:00 (엑셀 날짜 일련번호)
          [46325.5, 'A', 1, '직접'],
          ['어제', 'A', 1, '직접'],
          ['2026-10-30 09:00:00', '없는 약', 1, '직접'],
          [null, null, null, null],
        ],
      }),
    );

    expect(summary, (
      medications: 1,
      records: 1,
      prescriptions: 0,
      skippedRows: 3,
    ));
    expect(await savedMedications(), [('A', null, 1, '510')]);
    expect(await savedRecords(), [
      ('A', DateTime(2026, 10, 30, 12), 1, IntakeSource.manual),
    ]);
  });

  test('이 앱이 내보낸 형식이 아니면 FormatException', () async {
    expect(
      () => backup.importExcel(
        encodeXlsx({
          'Sheet1': [
            ['name'],
          ],
        }),
      ),
      throwsFormatException,
    );
  });

  test('종류·하루 기준량·처방이 그대로 돌아오고, 같은 처방은 다시 넣지 않는다', () async {
    final vitamin = await medications.save(
      categoryId: null,
      name: '비타민 D',
      dosePerTake: 1,
      times: const [480],
      kind: MedicationKind.supplement,
      dailyLimit: 2,
    );
    final acne = await medications.save(
      categoryId: 1900,
      name: '여드름약',
      dosePerTake: 1,
      times: const [],
    );
    final stomach = await medications.save(
      categoryId: null,
      name: '위장약',
      dosePerTake: 1,
      times: const [],
    );
    await prescriptions.save(
      startDate: DateTime(2026, 11, 5),
      days: 28,
      items: [
        PrescriptionItem(
          medicationId: acne,
          dosePerTake: 1,
          times: const [480, 1200],
        ),
        PrescriptionItem(
          medicationId: stomach,
          dosePerTake: 2,
          times: const [1200],
        ),
      ],
    );
    await prescriptions.save(
      startDate: DateTime(2026, 10, 1),
      days: 7,
      items: [
        PrescriptionItem(
          medicationId: acne,
          dosePerTake: 1,
          times: const [480],
        ),
      ],
      status: PrescriptionStatus.ended,
    );
    expect(vitamin, isPositive);
    final bytes = await backup.exportExcel();

    await db.close();
    open();
    final summary = await backup.importExcel(bytes);
    expect(summary, (
      medications: 3,
      records: 0,
      prescriptions: 2,
      skippedRows: 0,
    ));

    expect(
      {
        for (final m in await medications.getAll())
          m.name: (m.kind, m.dailyLimit),
      },
      {
        '비타민 D': (MedicationKind.supplement, 2),
        '여드름약': (MedicationKind.prescription, null),
        '위장약': (MedicationKind.prescription, null),
      },
    );
    final names = {for (final m in await medications.getAll()) m.id: m.name};
    expect(
      [
        for (final p in await prescriptions.getAll())
          (
            p.startDate,
            p.days,
            p.status,
            [
              for (final i in p.items)
                '${names[i.medicationId]} ${i.dosePerTake} ${i.times.join(',')}',
            ].join(' / '),
          ),
      ],
      [
        (
          DateTime(2026, 11, 5),
          28,
          PrescriptionStatus.active,
          '여드름약 1 480,1200 / 위장약 2 1200',
        ),
        (DateTime(2026, 10, 1), 7, PrescriptionStatus.ended, '여드름약 1 480'),
      ],
    );

    expect(await backup.importExcel(bytes), (
      medications: 0,
      records: 0,
      prescriptions: 0,
      skippedRows: 0,
    ));
    expect(await prescriptions.getAll(), hasLength(2));
  });

  test('종류를 고르지 않은 약은 가져온 파일의 종류를 넣고, 이미 고른 약은 그대로 둔다', () async {
    await medications.save(
      categoryId: null,
      name: 'A',
      dosePerTake: 1,
      times: const [],
    );
    await medications.save(
      categoryId: null,
      name: 'B',
      dosePerTake: 1,
      times: const [],
      kind: MedicationKind.asNeeded,
    );

    final summary = await backup.importExcel(
      encodeXlsx({
        BackupRepository.medicationSheet: [
          ['이름', '약 번호', '1회 개수', '복용 시간', '종류', '하루 기준량'],
          ['A', null, 1, null, '영양제', 3],
          ['B', null, 1, null, '영양제', 3],
          ['C', null, 1, null, '모르는 종류', null],
        ],
        BackupRepository.recordSheet: [
          ['시각', '약', '개수', '방법'],
        ],
        BackupRepository.prescriptionSheet: [
          ['처방', '시작일', '일수', '상태', '약', '1회 개수', '복용 시간'],
          [1, '2026-11-05', 0, '진행', 'A', 1, '08:00'],
          [2, '2026-11-05', 7, '진행', '없는 약', 1, '08:00'],
          [3, '2026-11-05', 7, '진행', 'B', 1, null],
        ],
      }),
    );

    expect(summary, (
      medications: 0,
      records: 0,
      prescriptions: 0,
      skippedRows: 4,
    ));
    expect(
      {
        for (final m in await medications.getAll())
          m.name: (m.kind, m.dailyLimit),
      },
      {
        'A': (MedicationKind.supplement, 3),
        'B': (MedicationKind.asNeeded, null),
      },
    );
  });

  test('뽑기 기록과 장착(펫 포함)이 그대로 돌아오고, 다시 가져와도 겹치지 않는다', () async {
    final pill = await medications.save(
      categoryId: null,
      name: '항생제',
      dosePerTake: 1,
      times: const [],
    );
    // 다른 처방을 먼저 등록해 처방 번호와 id가 달라지게 한다.
    await prescriptions.save(
      startDate: DateTime(2026, 10, 1),
      days: 30,
      items: [
        PrescriptionItem(
          medicationId: pill,
          dosePerTake: 1,
          times: const [1200],
        ),
      ],
    );
    final short = await prescriptions.save(
      startDate: DateTime(2026, 10, 30),
      days: 1,
      items: [
        PrescriptionItem(
          medicationId: pill,
          dosePerTake: 1,
          times: const [480],
        ),
      ],
    );
    now = DateTime(2026, 10, 30, 8, 5);
    await intakes.addCameraIntake(
      photo: Uint8List(1),
      countsByMedication: {pill: 1},
    );
    final drawn = await collection.draw();
    await collection.equip(drawn);
    await collection.setPet(short);
    final bytes = await backup.exportExcel();

    await db.close();
    open();
    await backup.importExcel(bytes);
    expect([for (final (id, _) in await collection.draws()) id], [drawn.id]);
    final e = await collection.equipment();
    expect(
      drawn.slot == CosmeticSlot.skin ? e.skin?.id : e.accessory?.id,
      drawn.id,
    );
    final pet = (await prescriptions.getById(e.petPrescriptionId!))!;
    expect((pet.startDate, pet.days), (DateTime(2026, 10, 30), 1));
    expect(await collection.availableTickets(), 0);

    await backup.importExcel(bytes);
    expect(await collection.draws(), hasLength(1));
  });

  test('몬스터 생김새가 백업으로 옮겨져 이름이 같다', () async {
    final pill = await medications.save(
      categoryId: null,
      name: '여드름약',
      dosePerTake: 1,
      times: const [],
    );
    final id = await prescriptions.save(
      startDate: DateTime(2026, 11, 5),
      days: 28,
      items: [
        PrescriptionItem(
          medicationId: pill,
          dosePerTake: 1,
          times: const [480],
        ),
      ],
    );
    await prescriptions.setMonsterLook(id, '주황', '길쭉');
    final bytes = await backup.exportExcel();

    await db.close();
    open();
    await backup.importExcel(bytes);
    final restored = (await prescriptions.getAll()).single;
    expect((await prescriptions.monsterLooks())[restored.id], ('주황', '길쭉'));
  });
}
