import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/medication.dart';
import 'package:pillbbox/data/repositories/backup_repository.dart';
import 'package:pillbbox/data/repositories/collection_repository.dart';
import 'package:pillbbox/data/repositories/drug_info_repository.dart';
import 'package:pillbbox/data/repositories/intake_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/repositories/prescription_repository.dart';
import 'package:pillbbox/data/repositories/reward_repository.dart';
import 'package:pillbbox/data/services/backup_file_service.dart';
import 'package:pillbbox/data/services/drug_info_service.dart';
import 'package:pillbbox/ui/home/home_view_model.dart';
import 'package:pillbbox/utils/intake_matcher.dart';

import '../helpers.dart';

void main() {
  test('회차 시간에서 3시간이 지났는데 다 먹지 않았으면 놓친 회차다', () {
    final db = createTestDatabase();
    addTearDown(db.close);
    final photos = FakePhotoStorageService();
    final medications = MedicationRepository(db, photos);
    final intakes = IntakeRepository(db, photos);
    final prescriptions = PrescriptionRepository(db, medications);
    final rewards = RewardRepository(
      medications,
      intakes,
      prescriptions,
      DrugInfoRepository(db, DrugInfoService(baseUrl: '')),
    );
    final collection = CollectionRepository(db, rewards);
    var now = DateTime(2026, 11, 5, 11);
    final vm = HomeViewModel(
      intakes: intakes,
      medications: medications,
      prescriptions: prescriptions,
      rewards: rewards,
      collection: collection,
      picker: SamplePhotoPickerService(),
      backup: BackupRepository(medications, intakes, prescriptions, collection),
      backupFiles: BackupFileService(),
      now: () => now,
    );
    addTearDown(vm.dispose);

    const m = Medication(id: 1, categoryId: null, name: 'A', dosePerTake: 1);
    final open = [const DoseSlot(medication: m, time: 480, dose: 1, taken: 0)];
    final done = [const DoseSlot(medication: m, time: 480, dose: 1, taken: 1)];

    // 08:00 회차, 지금 11:00: 아직 인정 범위 안.
    expect(vm.isMissed(480, open), isFalse);
    now = DateTime(2026, 11, 5, 11, 1);
    expect(vm.isMissed(480, open), isTrue);
    expect(vm.isMissed(480, done), isFalse);
  });
}
