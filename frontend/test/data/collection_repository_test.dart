import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/cosmetic.dart';
import 'package:pillbbox/data/models/medication.dart';
import 'package:pillbbox/data/models/prescription.dart';
import 'package:pillbbox/data/repositories/collection_repository.dart';
import 'package:pillbbox/data/repositories/drug_info_repository.dart';
import 'package:pillbbox/data/repositories/intake_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/repositories/prescription_repository.dart';
import 'package:pillbbox/data/repositories/reward_repository.dart';
import 'package:pillbbox/data/services/database_service.dart';
import 'package:pillbbox/data/services/drug_info_service.dart';

import '../helpers.dart';

void main() {
  late DatabaseService db;
  late MedicationRepository medications;
  late IntakeRepository intakes;
  late PrescriptionRepository prescriptions;
  late CollectionRepository collection;
  var now = DateTime(2026, 11, 5, 8);

  setUp(() {
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
    collection = CollectionRepository(
      db,
      rewards,
      now: () => now,
      random: Random(1),
    );
  });
  tearDown(() => db.close());

  /// 하루짜리 처방을 하나 등록하고 사진으로 채워 퇴치한다. 처방 id를 돌려준다.
  Future<int> defeatMonster(DateTime day) async {
    final id = await medications.save(
      categoryId: null,
      name: '약 ${day.day}',
      dosePerTake: 1,
      times: const [],
      kind: MedicationKind.prescription,
    );
    final prescriptionId = await prescriptions.save(
      startDate: day,
      days: 1,
      items: [
        PrescriptionItem(medicationId: id, dosePerTake: 1, times: const [480]),
      ],
    );
    now = DateTime(day.year, day.month, day.day, 8, 5);
    await intakes.addCameraIntake(
      photo: Uint8List(1),
      countsByMedication: {id: 1},
    );
    return prescriptionId;
  }

  test('뽑기권이 없으면 뽑을 수 없다', () async {
    expect(await collection.availableTickets(), 0);
    await expectLater(collection.draw(), throwsA(isA<NoTicketException>()));
    expect(await collection.owned(), isEmpty);
  });

  test('퇴치로 얻은 뽑기권만큼 뽑고, 뽑은 것이 컬렉션에 남는다', () async {
    await defeatMonster(DateTime(2026, 11, 5));
    await defeatMonster(DateTime(2026, 11, 6));
    expect(await collection.availableTickets(), 2);

    var notified = 0;
    collection.addListener(() => notified++);
    final first = await collection.draw();
    final second = await collection.draw();
    expect(await collection.availableTickets(), 0);
    await expectLater(collection.draw(), throwsA(isA<NoTicketException>()));

    final owned = await collection.owned();
    expect(owned.fold(0, (sum, o) => sum + o.count), 2);
    expect({for (final o in owned) o.cosmetic.id}, {first.id, second.id});
    expect(notified, 2);
  });

  test('갖고 있는 아이템만 장착하고, 퇴치한 몬스터만 펫이 된다', () async {
    final pet = await defeatMonster(DateTime(2026, 11, 5));
    final alive = await prescriptions.save(
      startDate: DateTime(2026, 11, 5),
      days: 28,
      items: [
        PrescriptionItem(
          medicationId: (await medications.getAll()).first.id,
          dosePerTake: 1,
          times: const [1200],
        ),
      ],
    );
    final drawn = await collection.draw();
    final notOwned = cosmetics.firstWhere((c) => c.id != drawn.id);

    await expectLater(collection.equip(notOwned), throwsStateError);
    await collection.equip(drawn);
    await expectLater(collection.setPet(alive), throwsStateError);
    await collection.setPet(pet);

    var e = await collection.equipment();
    expect(
      drawn.slot == CosmeticSlot.skin ? e.skin?.id : e.accessory?.id,
      drawn.id,
    );
    expect(e.petPrescriptionId, pet);

    await collection.unequip(drawn.slot);
    await collection.setPet(null);
    e = await collection.equipment();
    expect((e.skin, e.accessory, e.petPrescriptionId), (null, null, null));
  });

  test('뽑기 기록을 가져오면 같은 아이템·시각은 건너뛰고, 모르는 아이템은 버린다', () async {
    final at = DateTime(2026, 11, 5, 9);
    expect(
      await collection.importDraws([
        ('skin_mint', at),
        ('skin_mint', at),
        ('acc_wings', at),
        ('없는 아이템', at),
      ]),
      2,
    );
    expect(await collection.importDraws([('skin_mint', at)]), 0);
    expect(await collection.spentTickets(), 2);

    await collection.importEquipment(
      Equipment(skin: Cosmetic.byId('skin_mint')),
    );
    await collection.importEquipment(
      Equipment(
        skin: Cosmetic.byId('skin_galaxy'),
        accessory: Cosmetic.byId('acc_wings'),
      ),
    );
    final e = await collection.equipment();
    expect((e.skin?.id, e.accessory?.id), ('skin_mint', 'acc_wings'));
  });
}
