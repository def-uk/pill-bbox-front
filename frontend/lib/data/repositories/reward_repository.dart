import '../../utils/monster_look.dart';
import '../models/appearance.dart';
import '../../utils/reward_calculator.dart';
import '../models/prescription.dart';
import 'drug_info_repository.dart';
import 'intake_repository.dart';
import 'medication_repository.dart';
import 'prescription_repository.dart';

/// 처방 몬스터 체력과 경험치. 저장하지 않고 기록에서 매번 다시 센다 ([calculateRewards]).
/// 그래서 따로 알리지 않는다. 바뀌는지 보려면 약·기록·처방 저장소를 듣는다.
class RewardRepository {
  RewardRepository(
    this._medications,
    this._intakes,
    this._prescriptions,
    this._drugs,
  );

  final MedicationRepository _medications;
  final IntakeRepository _intakes;
  final PrescriptionRepository _prescriptions;
  final DrugInfoRepository _drugs;

  Future<RewardState> current() async => calculateRewards(
    medications: await _medications.getAll(),
    prescriptions: await _prescriptions.getAll(),
    records: await _intakes.allRecords(),
  );

  /// 처방마다 몬스터 생김새. 모르면 null. 처음 알게 되면 남겨 두고 그 뒤로는 바꾸지 않는다.
  ///
  /// 처방 속 약의 식약처 생김새를 먼저 쓰고, 없으면 사진으로 남긴 색·모양을 쓴다.
  Future<Map<int, MonsterLook?>> monsterLooks(
    List<Prescription> prescriptions,
  ) async {
    final stored = await _prescriptions.monsterLooks();
    final appearances = await _medications.appearances();
    final looks = <int, MonsterLook?>{};
    for (final p in prescriptions) {
      var look = switch (stored[p.id]) {
        (final color, final shape) => (color: color, shape: shape),
        null => null,
      };
      if (look == null) {
        for (final item in p.items) {
          look = await _itemLook(item.medicationId, appearances);
          if (look != null) break;
        }
        if (look != null) {
          await _prescriptions.setMonsterLook(p.id, look.color, look.shape);
        }
      }
      looks[p.id] = look;
    }
    return looks;
  }

  /// 약 하나의 생김새. 식약처 생김새를 먼저, 없으면 사진으로 남긴 색·모양.
  Future<MonsterLook?> _itemLook(
    int medicationId,
    List<(int, Appearance)> appearances,
  ) async {
    final drug = (await _drugs.cached(medicationId))?.detail;
    return (drug == null ? null : lookFromDrug(drug.colors, drug.shape)) ??
        lookFromAppearances([
          for (final (id, a) in appearances)
            if (id == medicationId) a,
        ]);
  }

  /// 새 몬스터 화면에서 고를 수 있는 생김새. 처방 속 약들의 생김새가 먼저, 그다음 [presetMonsterLooks].
  Future<List<MonsterLook>> lookChoices(Prescription prescription) async {
    final appearances = await _medications.appearances();
    final choices = <MonsterLook>[];
    for (final item in prescription.items) {
      final look = await _itemLook(item.medicationId, appearances);
      if (look != null && !choices.contains(look)) choices.add(look);
    }
    for (final look in presetMonsterLooks) {
      if (!choices.contains(look)) choices.add(look);
    }
    return choices;
  }

  /// 처방마다 몬스터 이름 ([monsterLooks]로 짓는다).
  Future<Map<int, String>> monsterNames(
    List<Prescription> prescriptions,
  ) async => (await monsterLooks(
    prescriptions,
  )).map((id, look) => MapEntry(id, monsterName(look)));
}
