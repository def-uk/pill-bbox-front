import 'package:flutter/foundation.dart';

import '../../data/models/cosmetic.dart';
import '../../utils/monster_look.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../utils/reward_calculator.dart';
import 'share_card.dart';

/// 뽑기 (docs/MVP.md 7.3). 뽑기권은 기록으로만 얻고 팔지 않는다.
class DrawViewModel extends ChangeNotifier {
  DrawViewModel({
    required this._collection,
    required this._rewards,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final CollectionRepository _collection;
  final RewardRepository _rewards;
  final DateTime Function() _now;
  bool _disposed = false;

  bool loading = true;
  bool drawing = false;
  int tickets = 0;

  /// 일정을 연속으로 지킨 날 수.
  int streak = 0;

  /// 방금 뽑은 것과 그것이 몇 개째인지. 아직 안 뽑았으면 null.
  ({Cosmetic cosmetic, int count})? result;

  /// 지금 장착한 것. 방금 뽑은 것을 장착했는지 보는 데 쓴다.
  Equipment equipment = Equipment.none;

  /// 방금 뽑은 것을 장착했다.
  bool get resultEquipped => switch (result?.cosmetic.id) {
    null => false,
    final id => equipment.skin?.id == id || equipment.accessory?.id == id,
  };

  /// 뽑은 횟수. 뽑을 때마다 연출을 처음부터 다시 보여 주는 데 쓴다.
  int drawSerial = 0;

  /// 다음 뽑기권까지 남은 연속 일수.
  int get daysToNextTicket => ticketStreakDays - streak % ticketStreakDays;

  bool get canDraw => !loading && !drawing && tickets > 0;

  Future<void> load() async {
    final state = await _rewards.current();
    final tickets = await _collection.availableTickets();
    final equipment = await _collection.equipment();
    if (_disposed) return;
    this.equipment = equipment;
    streak = state.streakOn(_now());
    this.tickets = tickets;
    loading = false;
    notifyListeners();
  }

  Future<void> draw() async {
    if (!canDraw) return;
    drawing = true;
    notifyListeners();
    try {
      final cosmetic = await _collection.draw();
      final count = (await _collection.owned())
          .firstWhere((o) => o.cosmetic.id == cosmetic.id)
          .count;
      result = (cosmetic: cosmetic, count: count);
      drawSerial++;
      tickets = await _collection.availableTickets();
    } on NoTicketException {
      tickets = 0;
    } finally {
      drawing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// 방금 뽑은 것을 바로 장착한다 (상황 B · 14쪽).
  Future<void> equipResult() async {
    final cosmetic = result?.cosmetic;
    if (cosmetic == null) return;
    await _collection.equip(cosmetic);
    final equipment = await _collection.equipment();
    if (_disposed) return;
    this.equipment = equipment;
    notifyListeners();
  }

  /// 지금 장착한 캐릭터로 공유 카드를 만든다. 약 이름·병명은 넣지 않는다.
  Future<ShareCardData> shareCard() async {
    final state = await _rewards.current();
    final equipment = await _collection.equipment();
    final pet = state.monsters
        .where(
          (m) =>
              m.isDefeated && m.prescription.id == equipment.petPrescriptionId,
        )
        .firstOrNull;
    final looks = pet == null
        ? const <int, MonsterLook?>{}
        : await _rewards.monsterLooks([pet.prescription]);
    return ShareCardData(
      exp: state.totalExp,
      skin: equipment.skin,
      accessory: equipment.accessory,
      pet: pet == null
          ? null
          : (pet.prescription.id, looks[pet.prescription.id]),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
