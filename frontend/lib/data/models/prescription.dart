import '../../utils/time_format.dart';

/// 처방 상태. DB에 이름으로 저장하므로 이름을 바꾸지 않는다.
enum PrescriptionStatus {
  active('진행'),

  /// 예전 이름. 퇴치는 기록에서 다시 세므로(utils/reward_calculator.dart) 저장하지 않는다.
  /// 이 값으로 저장된 처방은 진행과 같게 다룬다.
  defeated('퇴치'),

  /// 사용자가 처방을 끝냈다. 끝낸 날부터 일정에서 빠진다.
  ended('끝냄');

  const PrescriptionStatus(this.label);

  final String label;

  static PrescriptionStatus? fromName(Object? name) =>
      values.where((s) => s.name == name).firstOrNull;
}

/// 처방 속 약 하나.
class PrescriptionItem {
  const PrescriptionItem({
    required this.medicationId,
    required this.dosePerTake,
    required this.times,
  });

  final int medicationId;

  /// 1회 알 수.
  final int dosePerTake;

  /// 회차 시간. 자정부터 센 분, 오름차순. 개수가 하루 복용 횟수다.
  final List<int> times;

  /// 하루 기준량: 하루 횟수 × 1회 알 수.
  int get dailyAmount => dosePerTake * times.length;

  static String encodeTimes(List<int> times) =>
      times.map(formatMinuteOfDay).join(',');

  static List<int> decodeTimes(String text) => [
    for (final t in text.split(','))
      if (t.trim().isNotEmpty) parseMinuteOfDay(t.trim()),
  ]..sort();
}

/// 병원에서 한 번에 받은 약들의 묶음 (docs/MVP.md 4.2).
class Prescription {
  const Prescription({
    required this.id,
    required this.startDate,
    required this.days,
    required this.status,
    required this.items,
    this.endedOn,
  });

  final int id;

  /// 시작일 (자정).
  final DateTime startDate;

  /// 처방 일수. 2단계에서 몬스터 체력이 된다.
  final int days;
  final PrescriptionStatus status;
  final List<PrescriptionItem> items;

  /// 처방을 끝낸 날 (자정). 끝내지 않았으면 null.
  final DateTime? endedOn;

  /// 마지막 날 (자정).
  DateTime get endDate =>
      DateTime(startDate.year, startDate.month, startDate.day + days - 1);

  /// [day]의 일정에 이 처방의 회차가 들어가는가. 처방 기간 안이고 끝내지 않았으면.
  bool isScheduledOn(DateTime day) {
    if (status == PrescriptionStatus.ended) return false;
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(startDate) && !d.isAfter(endDate);
  }

  /// [day]의 기록이 이 몬스터 체력을 깎을 수 있는가. 처방 기간 안이고, 끝냈으면 끝낸 날까지.
  bool countsForRewardOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (d.isBefore(startDate) || d.isAfter(endDate)) return false;
    if (status != PrescriptionStatus.ended) return true;
    return endedOn != null && !d.isAfter(endedOn!);
  }

  /// 처방 기간이 [day] 전에 끝났다.
  bool isOverOn(DateTime day) =>
      DateTime(day.year, day.month, day.day).isAfter(endDate);
}
