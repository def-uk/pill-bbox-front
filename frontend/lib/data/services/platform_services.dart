import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../utils/object_finder.dart';
import 'file_photo_storage_service.dart';
import 'model_bundle.dart';
import 'photo_storage_service.dart';
import 'pill_detector.dart';
import 'pill_label_service.dart';
import 'yolo_pill_detector.dart';

// 기기(Android, iOS)에서 쓰는 서비스. 웹은 platform_services_web.dart이고, main.dart와 결과 화면 ViewModel이
// 조건부 import로 고른다.

DatabaseFactory get platformDatabaseFactory => databaseFactory;

PhotoStorageService createPhotoStorage() => FilePhotoStorageService();

PillDetector createModelDetector(ModelBundle model, PillLabelService labels) =>
    YoloPillDetector(modelAsset: model.modelAsset, labels: labels);

/// 사진 속 물체를 찾는다. 무거운 계산이라 다른 isolate에서 돌린다.
Future<List<FoundObject>> findPhotoObjects(Uint8List photo) =>
    compute(findObjects, photo);
