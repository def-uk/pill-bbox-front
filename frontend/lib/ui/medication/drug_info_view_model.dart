import 'package:flutter/foundation.dart';

import '../../data/models/drug_info.dart';
import '../../data/repositories/drug_info_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/services/drug_info_service.dart';

/// 약 하나의 식약처 의약품 정보.
///
/// 이어 둔 정보가 있으면 바로 보여 주고, 오래됐으면 다시 받는다.
/// 없으면 약 이름으로 식약처에서 찾아 사용자가 고르게 한다. 이름이 꼭 같은 약이 하나면 바로 잇는다.
class DrugInfoViewModel extends ChangeNotifier {
  DrugInfoViewModel({
    required this.medicationId,
    required this._medications,
    required this._drugs,
  });

  final int medicationId;
  final MedicationRepository _medications;
  final DrugInfoRepository _drugs;
  bool _disposed = false;

  bool loading = true;
  bool notFound = false;
  String medicationName = '';

  DrugDetail? detail;
  DateTime? fetchedAt;

  /// 식약처 약 중에서 고르는 중.
  bool choosing = false;
  bool searching = false;
  bool linking = false;
  DrugPage? candidates;
  String? error;

  bool get available => _drugs.available;

  String imageUrl(String itemSeq) => _drugs.imageUrl(itemSeq);

  Future<void> load() async {
    final medication = await _medications.getById(medicationId);
    if (medication == null) {
      notFound = true;
      loading = false;
      notifyListeners();
      return;
    }
    medicationName = medication.name;
    final cached = await _drugs.cached(medicationId);
    loading = false;
    if (cached != null) {
      detail = cached.detail;
      fetchedAt = cached.fetchedAt;
      notifyListeners();
      if (cached.stale && available) await _refresh(cached.detail.itemSeq);
      return;
    }
    if (!available) {
      notifyListeners();
      return;
    }
    choosing = true;
    notifyListeners();
    await search(medicationName);
    final exact = candidates?.items
        .where((d) => d.name == medicationName)
        .toList();
    if (exact != null && exact.length == 1) await choose(exact.single);
  }

  Future<void> _refresh(String itemSeq) async {
    try {
      final fresh = await _drugs.link(medicationId, itemSeq);
      if (fresh == null) return;
      detail = fresh;
      fetchedAt = DateTime.now();
      notifyListeners();
    } on DrugInfoException {
      // 받아 둔 정보를 그대로 보여 준다.
    }
  }

  Future<void> search(String query) async {
    final q = query.trim().isEmpty ? medicationName : query.trim();
    searching = true;
    error = null;
    notifyListeners();
    try {
      candidates = await _drugs.search(q);
    } on DrugInfoException catch (e) {
      candidates = null;
      error = e.message;
    }
    searching = false;
    notifyListeners();
  }

  Future<void> choose(DrugSummary drug) async {
    linking = true;
    error = null;
    notifyListeners();
    try {
      final linked = await _drugs.link(medicationId, drug.itemSeq);
      if (linked == null) {
        error = '식약처에 없는 약입니다';
      } else {
        detail = linked;
        fetchedAt = DateTime.now();
        choosing = false;
      }
    } on DrugInfoException catch (e) {
      error = e.message;
    }
    linking = false;
    notifyListeners();
  }

  /// 이어 둔 약이 틀렸을 때 다시 고른다.
  Future<void> startChoosing() async {
    choosing = true;
    notifyListeners();
    await search(medicationName);
  }

  void cancelChoosing() {
    if (detail == null) return;
    choosing = false;
    error = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
