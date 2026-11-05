import 'package:flutter/foundation.dart';

import '../../data/models/cosmetic.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../utils/character.dart';
import '../../utils/monster_look.dart';
import '../../utils/reward_calculator.dart';

/// 컬렉션과 장착 (docs/MVP.md 7.3). 퇴치 기록에는 몬스터 모습과 기간만 보여 준다.
class CollectionViewModel extends ChangeNotifier {
  CollectionViewModel({required this._collection, required this._rewards}) {
    _collection.addListener(load);
  }

  final CollectionRepository _collection;
  final RewardRepository _rewards;
  bool _disposed = false;

  bool loading = true;
  Growth growth = const Growth(0);
  Map<String, OwnedCosmetic> owned = const {};
  Equipment equipment = Equipment.none;

  /// 퇴치한 몬스터. 퇴치한 날 순서.
  List<MonsterState> defeated = const [];
  Map<int, MonsterLook?> looks = const {};

  bool isEquipped(Cosmetic c) =>
      equipment.skin?.id == c.id || equipment.accessory?.id == c.id;

  /// 데리고 다니는 펫. 퇴치 기록이 지워져 더는 퇴치한 몬스터가 아니면 null.
  MonsterState? get pet => defeated
      .where((m) => m.prescription.id == equipment.petPrescriptionId)
      .firstOrNull;

  Future<void> load() async {
    final state = await _rewards.current();
    final defeated = [
      for (final m in state.monsters)
        if (m.isDefeated) m,
    ]..sort((a, b) => a.defeatedOn!.compareTo(b.defeatedOn!));
    final looks = await _rewards.monsterLooks([
      for (final m in defeated) m.prescription,
    ]);
    final owned = await _collection.owned();
    final equipment = await _collection.equipment();
    if (_disposed) return;
    growth = Growth(state.totalExp);
    this.defeated = defeated;
    this.looks = looks;
    this.owned = {for (final o in owned) o.cosmetic.id: o};
    this.equipment = equipment;
    loading = false;
    notifyListeners();
  }

  /// 장착하거나, 이미 장착했으면 뺀다.
  Future<void> toggle(Cosmetic c) =>
      isEquipped(c) ? _collection.unequip(c.slot) : _collection.equip(c);

  Future<void> togglePet(MonsterState m) => _collection.setPet(
    pet?.prescription.id == m.prescription.id ? null : m.prescription.id,
  );

  @override
  void dispose() {
    _disposed = true;
    _collection.removeListener(load);
    super.dispose();
  }
}
