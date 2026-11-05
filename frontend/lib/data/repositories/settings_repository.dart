import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';

/// 기기 설정. 바뀌면 리스너에게 알린다 (화면 이동이 이것을 듣고 나이 확인으로 보낸다).
class SettingsRepository extends ChangeNotifier {
  SettingsRepository(this._db);

  final DatabaseService _db;

  static const _ageConfirmedKey = 'age_confirmed';
  static const _shareSavesKey = 'share_saves';

  /// 처음 불러오기 전에는 false.
  bool loaded = false;

  /// 만 14세 이상이라고 답했다 (docs/MVP.md 9.1). "아니요"는 남기지 않아 다음에 열면 다시 묻는다.
  bool ageConfirmed = false;

  Future<void> load() async {
    ageConfirmed = await _get(_ageConfirmedKey) == 'yes';
    loaded = true;
    notifyListeners();
  }

  Future<void> confirmAge() async {
    await _set(_ageConfirmedKey, 'yes');
    ageConfirmed = true;
    notifyListeners();
  }

  /// 공유 카드를 저장한 횟수. 4주 검증 지표에 쓴다 (docs/MVP.md 9.2).
  Future<int> shareSaves() async =>
      int.tryParse(await _get(_shareSavesKey) ?? '') ?? 0;

  Future<void> countShareSave() async =>
      _set(_shareSavesKey, '${await shareSaves() + 1}');

  Future<String?> _get(String key) async {
    final db = await _db.database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.single['value']! as String;
  }

  Future<void> _set(String key, String value) async {
    final db = await _db.database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
