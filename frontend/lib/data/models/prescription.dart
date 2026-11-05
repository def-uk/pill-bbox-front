import '../../utils/time_format.dart';

/// 처방 상태. DB에 이름으로 저장하므로 이름을 바꾸지 않는다.
enum PrescriptionStatus {
  active('진행'),

  /// 몬스터를 퇴치했다 (2단계).
  defeated('퇴치'),

  /// 사용자가 처방을 끝냈다 (2단계). 일정에서 빠진다.
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
  });

  final int id;

  /// 시작일 (자정).
  final DateTime startDate;

  /// 처방 일수. 2단계에서 몬스터 체력이 된다.
  final int days;
  final PrescriptionStatus status;
  final List<PrescriptionItem> items;

  /// 마지막 날 (자정).
  DateTime get endDate =>
      DateTime(startDate.year, startDate.month, startDate.day + days - 1);

  /// [day]의 일정에 이 처방의 회차가 들어가는가. 처방 기간 안이고 끝내지 않았으면.
  bool isScheduledOn(DateTime day) {
    if (status == PrescriptionStatus.ended) return false;
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(startDate) && !d.isAfter(endDate);
  }

  /// 처방 기간이 [day] 전에 끝났다.
  bool isOverOn(DateTime day) =>
      DateTime(day.year, day.month, day.day).isAfter(endDate);
}
