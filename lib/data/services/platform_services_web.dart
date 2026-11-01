import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'db_photo_storage_service.dart';
import 'model_bundle.dart';
import 'onnx_pill_detector.dart';
import 'photo_storage_service.dart';
import 'pill_detector.dart';
import 'pill_label_service.dart';

// 웹에서 쓰는 서비스. SQLite(wasm)는 브라우저 IndexedDB에 저장한다.
// web/sqlite3.wasm, web/sqflite_sw.js가 있어야 한다 (dart run sqflite_common_ffi_web:setup).

DatabaseFactory get platformDatabaseFactory => databaseFactoryFfiWeb;

PhotoStorageService createPhotoStorage() =>
    DbPhotoStorageService(factory: databaseFactoryFfiWeb);

PillDetector createModelDetector(ModelBundle model, PillLabelService labels) =>
    OnnxPillDetector(modelAsset: model.modelAsset, labels: labels);
