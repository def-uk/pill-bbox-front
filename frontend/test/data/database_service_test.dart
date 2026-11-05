import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pillbbox/data/models/medication.dart';
import 'package:pillbbox/data/models/prescription.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/repositories/prescription_repository.dart';
import 'package:pillbbox/data/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers.dart';

void main() {
  test('버전 3 DB를 열면 약은 종류 없이 남고 처방 테이블이 생긴다', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('pillbbox_db_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'pillbbox.db');
    final factory = databaseFactoryFfiNoIsolate;

    // 버전 3까지의 medications·schedules (DatabaseService._create와 같은 모양).
    final v3 = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE medications (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              category_id INTEGER UNIQUE,
              name TEXT NOT NULL,
              dose_per_take INTEGER NOT NULL DEFAULT 1
            )''');
          await db.execute('''
            CREATE TABLE schedules (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              medication_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
              time TEXT NOT NULL
            )''');
          await db.insert('medications', {
            'category_id': 7,
            'name': '예전 약',
            'dose_per_take': 2,
          });
        },
      ),
    );
    await v3.close();

    final service = DatabaseService(factory: factory, path: path);
    addTearDown(service.close);
    final medications = MedicationRepository(
      service,
      FakePhotoStorageService(),
    );
    final old = (await medications.getAll()).single;
    expect((old.name, old.dosePerTake, old.kind), ('예전 약', 2, null));

    final prescriptions = PrescriptionRepository(service, medications);
    await prescriptions.save(
      startDate: DateTime(2026, 11, 5),
      days: 28,
      items: [
        PrescriptionItem(
          medicationId: old.id,
          dosePerTake: 1,
          times: const [480],
        ),
      ],
    );
    expect(
      (await medications.getAll()).single.kind,
      MedicationKind.prescription,
    );
  });

  test('버전 4 DB를 열면 처방에 끝낸 날 칸과 몬스터 테이블이 생긴다', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('pillbbox_db_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'pillbbox.db');
    final factory = databaseFactoryFfiNoIsolate;

    final v4 = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE prescriptions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              start_date TEXT NOT NULL,
              days INTEGER NOT NULL,
              status TEXT NOT NULL DEFAULT 'active',
              created_at INTEGER NOT NULL
            )''');
          await db.insert('prescriptions', {
            'start_date': '2026-11-05',
            'days': 28,
            'created_at': 0,
          });
        },
      ),
    );
    await v4.close();

    final service = DatabaseService(factory: factory, path: path);
    addTearDown(service.close);
    final db = await service.database;
    await db.update('prescriptions', {'ended_on': '2026-11-07'});
    await db.insert('monsters', {
      'prescription_id': 1,
      'color': '하양',
      'shape': '동글',
    });
    expect(await db.query('monsters'), hasLength(1));
  });
}
