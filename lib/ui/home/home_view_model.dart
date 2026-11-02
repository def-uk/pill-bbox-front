import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/models/medication.dart';
import '../../data/repositories/intake_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/services/photo_picker_service.dart';
import '../../utils/intake_matcher.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this._intakes,
    required this._medications,
    required this._picker,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _intakes.addListener(load);
    _medications.addListener(load);
  }

  final IntakeRepository _intakes;
  final MedicationRepository _medications;
  final PhotoPickerService _picker;
  final DateTime Function() _now;
  bool _disposed = false;

  /// 알약 사진이 없을 때 해 보는 샘플 사진을 두는 곳.
  static const sampleDirectory = 'assets/images/test_images/';

  bool loading = true;

  /// 카메라나 사진 선택 창이 열려 있는 동안 true.
  bool picking = false;
  DateTime today = DateTime.now();
  List<Medication> medications = const [];
  DaySummary summary = const DaySummary(slots: [], unscheduled: []);

  /// 시간대별 일정. 시간순.
  List<(int, List<DoseSlot>)> get slotsByTime {
    final groups = <int, List<DoseSlot>>{};
    for (final slot in summary.slots) {
      groups.putIfAbsent(slot.time, () => []).add(slot);
    }
    return [for (final e in groups.entries) (e.key, e.value)];
  }

  String nameOf(int medicationId) =>
      medications.where((m) => m.id == medicationId).firstOrNull?.name ??
      '알 수 없는 약';

  Future<void> load() async {
    final now = _now();
    final medications = await _medications.getAll();
    final records = await _intakes.recordsOn(now);
    if (_disposed) return;
    today = now;
    this.medications = medications;
    summary = summarizeDay(medications, records);
    loading = false;
    notifyListeners();
  }

  /// 남은 개수만큼 직접 복용 기록을 남긴다.
  Future<void> markTaken(DoseSlot slot) => _intakes.addManualIntake(
    medicationId: slot.medication.id,
    count: slot.remaining,
  );

  /// 사진을 찍거나 골라 돌려준다. 그냥 닫았거나 이미 여는 중이면 null.
  Future<Uint8List?> pickPhoto(PhotoSource source) async {
    if (picking) return null;
    _setPicking(true);
    try {
      return await _picker.pick(source);
    } finally {
      _setPicking(false);
    }
  }

  final _random = Random();
  String? _lastSample;

  /// 샘플 사진 중 하나를 고른다. 연달아 같은 사진은 고르지 않는다. 샘플이 없으면 null.
  Future<Uint8List?> loadSamplePhoto() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final samples = [
      for (final a in manifest.listAssets())
        if (a.startsWith(sampleDirectory) && a != _lastSample) a,
    ];
    if (samples.isEmpty) return null;
    final asset = _lastSample = samples[_random.nextInt(samples.length)];
    return (await rootBundle.load(asset)).buffer.asUint8List();
  }

  void _setPicking(bool value) {
    if (_disposed) return;
    picking = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _intakes.removeListener(load);
    _medications.removeListener(load);
    super.dispose();
  }
}
