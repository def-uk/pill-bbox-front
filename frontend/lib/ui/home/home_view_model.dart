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

  /// 종류를 아직 고르지 않은 약. 업데이트 전에 등록한 약이다. 홈에서 고르게 한다.
  List<Medication> get untyped => [
    for (final m in medications)
      if (m.kind == null) m,
  ];

  /// 오늘 일정도 기록도 없다.
  bool get isEmpty => summary.slots.isEmpty && summary.unscheduled.isEmpty;

  /// [time] 회차를 놓쳤다: 다 먹지 않았고 회차 시간에서 [rewardWindowMinutes]가 지났다.
  bool isMissed(int time, List<DoseSlot> slots) =>
      slots.any((s) => !s.isDone) &&
      minuteOfDay(_now()) - time > rewardWindowMinutes;

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
