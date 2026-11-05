import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/cosmetic.dart';
import '../services/database_service.dart';
import 'reward_repository.dart';

/// 갖고 있는 스킨·액세서리 한 종류.
typedef OwnedCosmetic = ({
  Cosmetic cosmetic,
  int count,
  DateTime firstObtained,
});

/// 캐릭터에 장착한 것. 칸마다 하나 (docs/MVP.md 7.1).
class Equipment {
  const Equipment({this.skin, this.accessory, this.petPrescriptionId});

  static const none = Equipment();

  final Cosmetic? skin;
  final Cosmetic? accessory;

  /// 펫으로 데리고 다니는 퇴치한 몬스터(처방 id).
  final int? petPrescriptionId;
}

class NoTicketException implements Exception {
  const NoTicketException();

  @override
  String toString() => '뽑기권이 없습니다';
}

/// 뽑기, 컬렉션, 장착. 바뀌면 리스너에게 알린다.
///
/// 얻은 뽑기권은 기록에서 센다([RewardState.earnedTickets]). 뽑을 때마다 한 행을 남기므로 쓴 뽑기권은 행 수다.
class CollectionRepository extends ChangeNotifier {
  CollectionRepository(
    this._db,
    this._rewards, {
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random();

  final DatabaseService _db;
  final RewardRepository _rewards;
  final DateTime Function() _now;
  final Random _random;

  /// 갖고 있는 스킨·액세서리. 뽑기 풀 순서.
  Future<List<OwnedCosmetic>> owned() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT item, COUNT(*) AS n, MIN(obtained_at) AS first '
      'FROM collection GROUP BY item',
    );
    final byId = {for (final r in rows) r['item']! as String: r};
    return [
      for (final c in cosmetics)
        if (byId[c.id] case final r?)
          (
            cosmetic: c,
            count: r['n']! as int,
            firstObtained: DateTime.fromMillisecondsSinceEpoch(
              r['first']! as int,
            ),
          ),
    ];
  }

  /// 뽑기 기록 전부: (아이템 id, 얻은 시각). 오래된 것부터. 백업에 쓴다.
  Future<List<(String, DateTime)>> draws() async {
    final db = await _db.database;
    return [
      for (final r in await db.query('collection', orderBy: 'obtained_at, id'))
        (
          r['item']! as String,
          DateTime.fromMillisecondsSinceEpoch(r['obtained_at']! as int),
        ),
    ];
  }

  Future<int> spentTickets() async {
    final db = await _db.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM collection');
    return rows.single['n']! as int;
  }

  /// 지금 쓸 수 있는 뽑기권. 기록을 지워 얻은 것이 쓴 것보다 적어지면 0.
  Future<int> availableTickets() async =>
      max(0, (await _rewards.current()).earnedTickets - await spentTickets());

  /// 뽑기권 1장으로 뽑는다. 뽑기권이 없으면 [NoTicketException].
  Future<Cosmetic> draw() async {
    if (await availableTickets() <= 0) throw const NoTicketException();
    final cosmetic = drawCosmetic(_random);
    final db = await _db.database;
    await db.insert('collection', {
      'item': cosmetic.id,
      'obtained_at': _now().millisecondsSinceEpoch,
    });
    notifyListeners();
    return cosmetic;
  }

  /// 가져오기에서 뽑기 기록을 합친다. 같은 아이템·시각이면 건너뛴다. 더한 수를 돌려준다.
  Future<int> importDraws(List<(String, DateTime)> draws) async {
    final known = {
      for (final (id, at) in await this.draws())
        (id, at.millisecondsSinceEpoch),
    };
    final db = await _db.database;
    var added = 0;
    for (final (id, at) in draws) {
      if (Cosmetic.byId(id) == null) continue;
      if (!known.add((id, at.millisecondsSinceEpoch))) continue;
      await db.insert('collection', {
        'item': id,
        'obtained_at': at.millisecondsSinceEpoch,
      });
      added++;
    }
    if (added > 0) notifyListeners();
    return added;
  }

  Future<Equipment> equipment() async {
    final db = await _db.database;
    final rows = await db.query('character', where: 'id = 1');
    if (rows.isEmpty) return Equipment.none;
    final row = rows.single;
    return Equipment(
      skin: Cosmetic.byId(row['skin'] as String?),
      accessory: Cosmetic.byId(row['accessory'] as String?),
      petPrescriptionId: row['pet_prescription_id'] as int?,
    );
  }

  /// [cosmetic]을 그 칸에 장착한다. 갖고 있지 않으면 [StateError].
  Future<void> equip(Cosmetic cosmetic) async {
    if (!(await owned()).any((o) => o.cosmetic.id == cosmetic.id)) {
      throw StateError('갖고 있지 않은 아이템: ${cosmetic.id}');
    }
    await _setColumn(
      cosmetic.slot == CosmeticSlot.skin ? 'skin' : 'accessory',
      cosmetic.id,
    );
  }

  Future<void> unequip(CosmeticSlot slot) =>
      _setColumn(slot == CosmeticSlot.skin ? 'skin' : 'accessory', null);

  /// 퇴치한 몬스터를 펫으로 데리고 다닌다. null이면 뺀다. 퇴치하지 않은 몬스터면 [StateError].
  Future<void> setPet(int? prescriptionId) async {
    if (prescriptionId != null) {
      final monster = (await _rewards.current()).monsterOf(prescriptionId);
      if (monster == null || !monster.isDefeated) {
        throw StateError('퇴치하지 않은 몬스터: $prescriptionId');
      }
    }
    await _setColumn('pet_prescription_id', prescriptionId);
  }

  /// 가져오기에서 비어 있는 칸만 채운다.
  Future<void> importEquipment(Equipment equipment) async {
    final current = await this.equipment();
    final db = await _db.database;
    await db.insert('character', {
      'id': 1,
      'skin': (current.skin ?? equipment.skin)?.id,
      'accessory': (current.accessory ?? equipment.accessory)?.id,
      'pet_prescription_id':
          current.petPrescriptionId ?? equipment.petPrescriptionId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  Future<void> _setColumn(String column, Object? value) async {
    final db = await _db.database;
    await db.rawInsert(
      'INSERT INTO character (id, $column) VALUES (1, ?) '
      'ON CONFLICT(id) DO UPDATE SET $column = excluded.$column',
      [value],
    );
    notifyListeners();
  }
}
