import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/models/medication.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/repositories/intake_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/repositories/prescription_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../data/services/backup_file_service.dart';
import '../../utils/character.dart';
import '../../utils/intake_matcher.dart';
import '../../utils/monster_look.dart';
import '../../utils/reward_calculator.dart';
import '../../utils/time_format.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this._intakes,
    required this._medications,
    required this._prescriptions,
    required this._rewards,
    required this._collection,
    required this._backup,
    required this._backupFiles,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _intakes.addListener(load);
    _medications.addListener(load);
    _prescriptions.addListener(load);
    _collection.addListener(load);
  }

  final IntakeRepository _intakes;
  final MedicationRepository _medications;
  final PrescriptionRepository _prescriptions;
  final RewardRepository _rewards;
  final CollectionRepository _collection;
  final BackupRepository _backup;
  final BackupFileService _backupFiles;
  final DateTime Function() _now;
  bool _disposed = false;

  bool loading = true;

  DateTime today = DateTime.now();
  List<Medication> medications = const [];
  DaySummary summary = const DaySummary(slots: [], unscheduled: []);
  RewardState rewards = RewardState.empty;

  /// 몬스터 생김새. prescription_id → 생김새(모르면 null).
  Map<int, MonsterLook?> monsterLooks = const {};

  Growth get growth => Growth(rewards.totalExp);

  Equipment equipment = Equipment.none;

  /// 쓸 수 있는 뽑기권.
  int tickets = 0;

  /// 데리고 다니는 펫: (처방 id, 생김새). 없거나 더는 퇴치한 몬스터가 아니면 null.
  (int, MonsterLook?)? pet;

  /// 싸우는 중인 몬스터. 먼저 등록한 처방부터.
  List<MonsterState> get activeMonsters => [
    for (final m in rewards.monsters)
      if (m.isActive) m,
  ];

  /// 시간대별 일정. 시간순.
  List<(int, List<DoseSlot>)> get slotsByTime {
    final groups = <int, List<DoseSlot>>{};
    for (final slot in summary.slots) {
      groups.putIfAbsent(slot.time, () => []).add(slot);
    }
    return [for (final e in groups.entries) (e.key, e.value)];
  }

  /// 지금 먹을 시간대: 아직 다 먹지 않은 일정 중 지금과 가장 가까운 시각. 없으면 null.
  int? get currentTime {
    final open = [
      for (final s in summary.slots)
        if (!s.isDone) s.time,
    ];
    return open.isEmpty ? null : nearestTime(open, minuteOfDay(_now()));
  }

  /// 지금 먹을 회차를 알려 주는 카드 (상황 A · 5쪽). 회차 10분 전부터 놓치기 전까지. 없으면 null.
  DoseReminder? get reminder {
    final time = currentTime;
    if (time == null) return null;
    final now = minuteOfDay(_now());
    if (now < time - reminderLeadMinutes || isMissedTime(time)) return null;
    final open = [
      for (final s in summary.slots)
        if (s.time == time && !s.isDone) s,
    ];
    if (open.isEmpty) return null;
    final ids = {for (final s in open) s.medication.id};
    final monster = activeMonsters
        .where(
          (m) => m.prescription.items.any((i) => ids.contains(i.medicationId)),
        )
        .firstOrNull;
    final doses = {for (final s in open) s.remaining};
    return DoseReminder(
      time: time,
      kinds: open.length,
      dose: doses.length == 1 ? doses.single : null,
      monsterHp: monster?.hp,
    );
  }

  /// 오늘 영양제 일정이 있다.
  bool get hasSupplementsToday =>
      summary.slots.any((s) => s.medication.kind == MedicationKind.supplement);

  /// 오늘 영양제 일정을 모두 사진으로 지켜 경험치를 받았다. 더 먹어도 더 받지 않는다.
  bool get supplementsDoneToday => rewards.on(today)?.supplementsDone ?? false;

  /// 일정을 연속으로 지킨 날 수.
  int get streak => rewards.streakOn(today);

  /// 종류를 아직 고르지 않은 약. 업데이트 전에 등록한 약이다. 홈에서 고르게 한다.
  List<Medication> get untyped => [
    for (final m in medications)
      if (m.kind == null) m,
  ];

  /// 오늘 일정도 기록도 없다.
  bool get isEmpty => summary.slots.isEmpty && summary.unscheduled.isEmpty;

  /// [time] 회차를 놓쳤다: 다 먹지 않았고 회차 시간에서 [rewardWindowMinutes]가 지났다.
  bool isMissed(int time, List<DoseSlot> slots) =>
      slots.any((s) => !s.isDone) && isMissedTime(time);

  /// [time] 회차 시간에서 [rewardWindowMinutes]가 지났다.
  bool isMissedTime(int time) =>
      minuteOfDay(_now()) - time > rewardWindowMinutes;

  /// 회차 몇 분 전부터 알림 카드를 보여 줄지.
  static const reminderLeadMinutes = 10;

  String nameOf(int medicationId) =>
      medications.where((m) => m.id == medicationId).firstOrNull?.name ??
      '알 수 없는 약';

  Future<void> load() async {
    final now = _now();
    final medications = await _medications.getAll();
    final records = await _intakes.recordsOn(now);
    final prescriptions = await _prescriptions.scheduledOn(now);
    final rewards = await _rewards.current();
    final equipment = await _collection.equipment();
    final petMonster = rewards.monsters
        .where(
          (m) =>
              m.isDefeated && m.prescription.id == equipment.petPrescriptionId,
        )
        .firstOrNull;
    final looks = await _rewards.monsterLooks([
      for (final m in rewards.monsters)
        if (m.isActive) m.prescription,
      ?petMonster?.prescription,
    ]);
    final spent = await _collection.spentTickets();
    if (_disposed) return;
    today = now;
    this.medications = medications;
    this.rewards = rewards;
    monsterLooks = looks;
    this.equipment = equipment;
    pet = petMonster == null
        ? null
        : (petMonster.prescription.id, looks[petMonster.prescription.id]);
    tickets = max(0, rewards.earnedTickets - spent);
    summary = summarizeDay(medications, records, prescriptions: prescriptions);
    loading = false;
    notifyListeners();
  }

  /// 종류를 고르지 않은 약의 종류를 정한다.
  Future<void> setKind(Medication medication, MedicationKind kind) =>
      _medications.setKind(
        [medication.id],
        kind,
        dailyLimit: medication.dosePerTake * max(1, medication.times.length),
      );

  /// 남은 개수만큼 직접 복용 기록을 남긴다.
  Future<void> markTaken(DoseSlot slot) => _intakes.addManualIntake(
    medicationId: slot.medication.id,
    count: slot.remaining,
  );

  /// 약·기록을 엑셀로 내보낸다. 저장했으면 true.
  Future<bool> exportExcel() async => _backupFiles.save(
    '알약몬-${dateKey(_now())}.xlsx',
    await _backup.exportExcel(),
  );

  /// 엑셀 파일을 골라 지금 데이터에 합친다. 고르지 않으면 null, 이 앱이 내보낸 형식이 아니면 [FormatException].
  Future<ImportSummary?> importExcel() async {
    final bytes = await _backupFiles.pick();
    return bytes == null ? null : _backup.importExcel(bytes);
  }

  @override
  void dispose() {
    _disposed = true;
    _intakes.removeListener(load);
    _medications.removeListener(load);
    _prescriptions.removeListener(load);
    _collection.removeListener(load);
    super.dispose();
  }
}

/// 홈 위에 띄우는 복용 알림 카드의 내용. 약 이름은 넣지 않는다.
class DoseReminder {
  const DoseReminder({
    required this.time,
    required this.kinds,
    this.dose,
    this.monsterHp,
  });

  /// 회차 시각. 자정부터 센 분.
  final int time;

  /// 아직 먹지 않은 약 가짓수.
  final int kinds;

  /// 약마다 먹을 알 수가 같으면 그 수.
  final int? dose;

  /// 이 회차의 처방 몬스터 남은 체력. 처방약이 없으면 null.
  final int? monsterHp;

  /// 아침·점심·저녁·밤.
  String get meal => switch (time) {
    < 11 * 60 => '아침',
    < 16 * 60 => '점심',
    < 21 * 60 => '저녁',
    _ => '밤',
  };

  String get title => '$meal 약 먹을 시간이에요';

  String get detail => [
    if (monsterHp != null) '몬스터 체력 $monsterHp칸 남음',
    dose == null ? '$kinds종' : '$kinds종 $dose정씩',
  ].join(' · ');
}
