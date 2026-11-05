import 'dart:convert';

import '../models/drug_info.dart';
import '../services/database_service.dart';
import '../services/drug_info_service.dart';

/// 약에 이어 둔 식약처 의약품 정보. 받은 정보는 기기에 두어 서버가 꺼져도 보인다.
class DrugInfoRepository {
  DrugInfoRepository(this._db, this._service);

  final DatabaseService _db;
  final DrugInfoService _service;

  /// 이보다 오래 전에 받은 정보는 화면을 열 때 다시 받는다.
  static const refreshAfter = Duration(days: 7);

  bool get available => _service.available;

  String imageUrl(String itemSeq) => _service.imageUrl(itemSeq);

  Future<DrugPage> search(String query, {int page = 1}) =>
      _service.search(query, page: page);

  /// [itemSeq] 약 정보를 받기만 한다. 고르기 전에 효능·주의·생김새를 보여 줄 때 쓴다. 없으면 null.
  Future<DrugDetail?> detail(String itemSeq) => _service.detail(itemSeq);

  /// 기기에 둔 정보. 이어 둔 약이 없으면 null.
  Future<CachedDrugInfo?> cached(int medicationId) async {
    final db = await _db.database;
    final rows = await db.query(
      'drug_infos',
      where: 'medication_id = ?',
      whereArgs: [medicationId],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return CachedDrugInfo(
      detail: DrugDetail.fromJson(
        jsonDecode(row['data']! as String) as Map<String, Object?>,
      ),
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(row['fetched_at']! as int),
    );
  }

  /// [itemSeq] 약 정보를 받아 [medicationId] 약에 잇는다. 식약처에 없는 약이면 null.
  Future<DrugDetail?> link(int medicationId, String itemSeq) async {
    final detail = await _service.detail(itemSeq);
    if (detail == null) return null;
    final db = await _db.database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO drug_infos (medication_id, item_seq, data, fetched_at) '
      'VALUES (?, ?, ?, ?)',
      [
        medicationId,
        itemSeq,
        jsonEncode(detail.toJson()),
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
    return detail;
  }

  Future<void> unlink(int medicationId) async {
    final db = await _db.database;
    await db.delete(
      'drug_infos',
      where: 'medication_id = ?',
      whereArgs: [medicationId],
    );
  }
}

class CachedDrugInfo {
  const CachedDrugInfo({required this.detail, required this.fetchedAt});

  final DrugDetail detail;
  final DateTime fetchedAt;

  bool get stale =>
      DateTime.now().difference(fetchedAt) > DrugInfoRepository.refreshAfter;
}
