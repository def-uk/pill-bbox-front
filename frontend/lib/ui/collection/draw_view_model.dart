import 'package:flutter/foundation.dart';

import '../../data/models/cosmetic.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../utils/reward_calculator.dart';

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

  /// 다음 뽑기권까지 남은 연속 일수.
  int get daysToNextTicket => ticketStreakDays - streak % ticketStreakDays;

  bool get canDraw => !loading && !drawing && tickets > 0;

  Future<void> load() async {
    final state = await _rewards.current();
    final tickets = await _collection.availableTickets();
    if (_disposed) return;
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
      tickets = await _collection.availableTickets();
    } on NoTicketException {
      tickets = 0;
    } finally {
      drawing = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
