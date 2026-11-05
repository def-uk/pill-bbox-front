import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/intake_record.dart';
import 'package:pillbbox/data/models/medication.dart';
import 'package:pillbbox/data/models/prescription.dart';
import 'package:pillbbox/utils/metrics.dart';
import 'package:pillbbox/utils/reward_calculator.dart';

const vitamin = Medication(
  id: 1,
  categoryId: null,
  name: '비타민',
  dosePerTake: 1,
  times: [480],
  kind: MedicationKind.supplement,
  dailyLimit: 1,
);
const pill = Medication(
  id: 2,
  categoryId: null,
  name: '항생제',
  dosePerTake: 1,
  kind: MedicationKind.prescription,
);

var _id = 1;
IntakeRecord rec(
  int medicationId,
  int day, {
  IntakeSource source = IntakeSource.camera,
}) => IntakeRecord(
  id: _id++,
  medicationId: medicationId,
  takenAt: DateTime(2026, 11, day, 8),
  count: 1,
  source: source,
  photoPath: null,
);

TesterMetrics metrics(
  List<IntakeRecord> records, {
  List<Medication> medications = const [vitamin],
  List<Prescription> prescriptions = const [],
  int today = 10,
}) => computeMetrics(
  medications: medications,
  prescriptions: prescriptions,
  records: records,
  rewards: calculateRewards(
    medications: medications,
    prescriptions: prescriptions,
    records: records,
  ),
  today: DateTime(2026, 11, today, 21),
  shareSaves: 2,
);

void main() {
  test('기록이 없으면 기간도 비율도 없다', () {
    final m = metrics(const []);
    expect((m.start, m.days, m.recordedDays, m.records), (null, 0, 0, 0));
    expect(m.shareSaves, 2);
  });

  test('첫 기록 날부터 오늘까지 기록한 날, 일정을 다 지킨 날, 사진 기록 비율을 센다', () {
    // 11월 3일 시작. 3·4·6일 사진, 7일은 직접 기록. 오늘 10일.
    final m = metrics([
      rec(1, 3),
      rec(1, 4),
      rec(1, 6),
      rec(1, 7, source: IntakeSource.manual),
    ]);
    expect(m.start, DateTime(2026, 11, 3));
    expect(m.days, 8);
    expect(m.recordedDays, 4);
    // 영양제 일정은 매일 있다: 8일 중 사진으로 지킨 날 3일.
    expect((m.scheduledDays, m.completedDays), (8, 3));
    expect((m.records, m.cameraRecords), (4, 3));
  });

  test('28일보다 오래되었으면 최근 28일만 센다', () {
    final m = metrics([rec(1, 1), rec(1, 30)], today: 30);
    expect(m.start, DateTime(2026, 11, 3));
    expect(m.days, 28);
    expect(m.recordedDays, 1);
  });

  test('처방만 있는 날은 처방 기간 안에서만 일정이 있고, 퇴치한 몬스터를 센다', () {
    final short = Prescription(
      id: 1,
      startDate: DateTime(2026, 11, 3),
      days: 2,
      status: PrescriptionStatus.active,
      items: const [
        PrescriptionItem(medicationId: 2, dosePerTake: 1, times: [480]),
      ],
    );
    final long = Prescription(
      id: 2,
      startDate: DateTime(2026, 11, 20),
      days: 7,
      status: PrescriptionStatus.active,
      items: const [
        PrescriptionItem(medicationId: 2, dosePerTake: 1, times: [480]),
      ],
    );
    final m = metrics(
      [rec(2, 3), rec(2, 4)],
      medications: const [pill],
      prescriptions: [short, long],
      today: 6,
    );
    expect((m.scheduledDays, m.completedDays), (2, 2));
    expect((m.prescriptions, m.defeated), (2, 1));
  });
}
