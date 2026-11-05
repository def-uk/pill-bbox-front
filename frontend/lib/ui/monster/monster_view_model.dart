import 'package:flutter/foundation.dart';

import '../../data/repositories/intake_repository.dart';
import '../../data/repositories/prescription_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../utils/monster_look.dart';
import '../../utils/reward_calculator.dart';

/// 처방 몬스터 하나. 병명과 약 이름은 보여 주지 않는다 (docs/MVP.md 3장).
class MonsterViewModel extends ChangeNotifier {
  MonsterViewModel({
    required this.prescriptionId,
    required this._rewards,
    required this._prescriptions,
    required this._intakes,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _prescriptions.addListener(load);
    _intakes.addListener(load);
  }

  final int prescriptionId;
  final RewardRepository _rewards;
  final PrescriptionRepository _prescriptions;
  final IntakeRepository _intakes;
  final DateTime Function() _now;
  bool _disposed = false;

  bool loading = true;
  bool ending = false;

  /// 지워진 처방이면 null.
  MonsterState? monster;
  String name = defaultMonsterName;

  /// 생김새. 모르면 null.
  MonsterLook? look;

  /// 다른 몬스터로 바꿀 때 차례로 보여 줄 생김새 ([RewardRepository.lookChoices]).
  List<MonsterLook> lookChoices = const [];

  /// 처방 마지막 날까지 남은 날. 오늘을 넣어 센다.
  int get daysLeft => monster?.daysLeftOn(today) ?? 0;

  DateTime get today {
    final t = _now();
    return DateTime(t.year, t.month, t.day);
  }

  /// 처방 기간 중 오늘까지(끝냈으면 끝낸 날까지)의 날. 최근 날부터.
  List<DateTime> get pastDays {
    final m = monster;
    if (m == null) return const [];
    final p = m.prescription;
    var last = p.endDate.isAfter(today) ? today : p.endDate;
    if (p.endedOn case final ended? when ended.isBefore(last)) last = ended;
    return [
      for (
        var d = last;
        !d.isBefore(p.startDate);
        d = DateTime(d.year, d.month, d.day - 1)
      )
        d,
    ];
  }

  Future<void> load() async {
    final state = await _rewards.current();
    final monster = state.monsterOf(prescriptionId);
    final looks = monster == null
        ? const <int, MonsterLook?>{}
        : await _rewards.monsterLooks([monster.prescription]);
    final choices = monster == null
        ? const <MonsterLook>[]
        : await _rewards.lookChoices(monster.prescription);
    if (_disposed) return;
    this.monster = monster;
    look = looks[prescriptionId];
    lookChoices = choices;
    name = monsterName(look);
    loading = false;
    notifyListeners();
  }

  /// 다음 생김새로 바꾼다. 이름도 생김새를 따라 바뀐다. 병명·약 이름은 쓰지 않는다.
  Future<void> nextLook() async {
    if (lookChoices.isEmpty) return;
    final at = look == null ? -1 : lookChoices.indexOf(look!);
    final next = lookChoices[(at + 1) % lookChoices.length];
    await _prescriptions.replaceMonsterLook(
      prescriptionId,
      next.color,
      next.shape,
    );
  }

  /// 처방을 끝낸다. 몬스터가 물러나고 깎은 체력만큼 경험치를 받는다.
  Future<void> end() async {
    ending = true;
    notifyListeners();
    await _prescriptions.end(prescriptionId);
    ending = false;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _prescriptions.removeListener(load);
    _intakes.removeListener(load);
    super.dispose();
  }
}
