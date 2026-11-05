import '../../utils/monster_look.dart';
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

  /// 처방마다 몬스터 이름. 생김새를 처음 알게 되면 남겨 두고 그 뒤로는 바꾸지 않는다.
  ///
  /// 처방 속 첫 약의 식약처 생김새를 먼저 쓰고, 없으면 사진으로 남긴 색·모양을 쓴다.
  Future<Map<int, String>> monsterNames(
    List<Prescription> prescriptions,
  ) async {
    final looks = await _prescriptions.monsterLooks();
    final appearances = await _medications.appearances();
    final names = <int, String>{};
    for (final p in prescriptions) {
      var look = switch (looks[p.id]) {
        (final color, final shape) => (color: color, shape: shape),
        null => null,
      };
      if (look == null) {
        for (final item in p.items) {
          final drug = (await _drugs.cached(item.medicationId))?.detail;
          look =
              (drug == null ? null : lookFromDrug(drug.colors, drug.shape)) ??
              lookFromAppearances([
                for (final (id, a) in appearances)
                  if (id == item.medicationId) a,
              ]);
          if (look != null) break;
        }
        if (look != null) {
          await _prescriptions.setMonsterLook(p.id, look.color, look.shape);
        }
      }
      names[p.id] = monsterName(look);
    }
    return names;
  }
}
