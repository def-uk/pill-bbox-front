import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/appearance.dart';
import 'package:pillbbox/data/models/medication.dart';
import 'package:pillbbox/data/models/prescription.dart';
import 'package:pillbbox/data/repositories/backup_repository.dart';
import 'package:pillbbox/data/repositories/drug_info_repository.dart';
import 'package:pillbbox/data/repositories/intake_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/repositories/prescription_repository.dart';
import 'package:pillbbox/data/repositories/reward_repository.dart';
import 'package:pillbbox/data/services/database_service.dart';
import 'package:pillbbox/data/services/drug_info_service.dart';
import 'package:pillbbox/utils/reward_calculator.dart';

import '../helpers.dart';

void main() {
  late DatabaseService db;
  late MedicationRepository medications;
  late IntakeRepository intakes;
  late PrescriptionRepository prescriptions;
  late RewardRepository rewards;
  late BackupRepository backup;
  var now = DateTime(2026, 11, 5, 8);

  void open() {
    db = createTestDatabase();
    final photos = FakePhotoStorageService();
    medications = MedicationRepository(db, photos);
    intakes = IntakeRepository(db, photos, now: () => now);
    prescriptions = PrescriptionRepository(db, medications, now: () => now);
    rewards = RewardRepository(
      medications,
      intakes,
      prescriptions,
      DrugInfoRepository(db, DrugInfoService(baseUrl: '')),
    );
    backup = BackupRepository(medications, intakes, prescriptions);
  }

  setUp(open);
  tearDown(() => db.close());

  Future<(int, int)> registerAcne() async {
    final acne = await medications.save(
      categoryId: 1900,
      name: '여드름약',
      dosePerTake: 1,
      times: const [],
    );
    final id = await prescriptions.save(
      startDate: DateTime(2026, 11, 5),
      days: 28,
      items: [
        PrescriptionItem(
          medicationId: acne,
          dosePerTake: 1,
          times: const [480],
        ),
      ],
    );
    return (acne, id);
  }

  Future<void> photo(int medicationId, DateTime at) {
    now = at;
    return intakes.addCameraIntake(
      photo: Uint8List(1),
      countsByMedication: {medicationId: 1},
    );
  }

  test('28일 처방을 28일 동안 사진으로 채우면 체력 0이 되어 퇴치한다', () async {
    final (acne, id) = await registerAcne();
    for (var day = 0; day < 28; day++) {
      await photo(acne, DateTime(2026, 11, 5 + day, 8, 10));
    }
    final monster = (await rewards.current()).monsterOf(id)!;
    expect(monster.hp, 0);
    expect(monster.defeatedOn, DateTime(2026, 12, 2));
    expect((await rewards.current()).totalExp, defeatExp);
  });

  test('처방을 끝내면 끝낸 날이 남고, 백업에서 가져와도 보상이 같다', () async {
    final (acne, id) = await registerAcne();
    await photo(acne, DateTime(2026, 11, 5, 8));
    await photo(acne, DateTime(2026, 11, 6, 9));
    now = DateTime(2026, 11, 7, 12);
    await prescriptions.end(id);

    final ended = (await prescriptions.getById(id))!;
    expect(
      (ended.status, ended.endedOn),
      (PrescriptionStatus.ended, DateTime(2026, 11, 7)),
    );
    expect(ended.isScheduledOn(DateTime(2026, 11, 7)), isFalse);
    final state = await rewards.current();
    expect((state.monsterOf(id)!.dealt, state.totalExp), (2, 2));

    final bytes = await backup.exportExcel();
    await db.close();
    open();
    await backup.importExcel(bytes);
    final restored = await rewards.current();
    expect(restored.monsters.single.dealt, 2);
    expect(restored.monsters.single.isEnded, isTrue);
    expect(restored.totalExp, 2);
  });

  test('기록을 지우면 그날 체력이 돌아온다', () async {
    final (acne, id) = await registerAcne();
    await photo(acne, DateTime(2026, 11, 5, 8));
    expect((await rewards.current()).monsterOf(id)!.hp, 27);

    await intakes.delete((await intakes.allRecords()).single.id);
    expect((await rewards.current()).monsterOf(id)!.hp, 28);
  });

  test('몬스터 이름은 처음 알게 된 생김새로 정해지고 그 뒤로 바뀌지 않는다', () async {
    final (acne, id) = await registerAcne();
    final p = (await prescriptions.getById(id))!;
    expect(await rewards.monsterNames([p]), {id: '처방 몬스터'});

    await medications.addAppearance(
      acne,
      const Appearance(l: 75, a: 24, b: 79, elongation: 2.0),
    );
    expect(await rewards.monsterNames([p]), {id: '주황 길쭉 몬스터'});

    for (var i = 0; i < 5; i++) {
      await medications.addAppearance(
        acne,
        const Appearance(l: 95, a: 0, b: 3, elongation: 1.0),
      );
    }
    expect(await rewards.monsterNames([p]), {id: '주황 길쭉 몬스터'});
  });

  test('필요할 때 먹는 약으로 바꾸면 그 약 기록은 보상에서 빠진다', () async {
    final (acne, id) = await registerAcne();
    await photo(acne, DateTime(2026, 11, 5, 8));
    await medications.setKind([acne], MedicationKind.asNeeded);
    expect((await rewards.current()).monsterOf(id)!.hp, 28);
  });
}
