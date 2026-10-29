/// 하루 안의 시각을 자정부터 센 분으로 다룬다. 복용 시간(HH:mm)과 비교할 때 쓴다.
int minuteOfDay(DateTime t) => t.hour * 60 + t.minute;

String formatMinuteOfDay(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

int parseMinuteOfDay(String hhmm) {
  final [hour, minute] = hhmm.split(':').map(int.parse).toList();
  return hour * 60 + minute;
}

String formatTime(DateTime t) => formatMinuteOfDay(minuteOfDay(t));

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 예: 10월 30일 (목)
String formatDate(DateTime d) =>
    '${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';

/// 화면 주소에 쓰는 날짜. 예: 2026-10-30
String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDateKey(String key) {
  final parsed = DateTime.tryParse(key);
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}
