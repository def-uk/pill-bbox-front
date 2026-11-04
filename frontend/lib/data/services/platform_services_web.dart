import 'dart:js_interop';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../../utils/object_finder.dart';
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

@JS('pillbbox.pixels')
external JSPromise<_Pixels> _pixels(JSUint8Array image, JSNumber side);

/// web/pill_detector_worker.js가 돌려주는 줄인 사진. [data]는 RGBA다.
extension type _Pixels(JSObject _) implements JSObject {
  external int get width;
  external int get height;
  external int get sourceWidth;
  external JSUint8Array get data;
}

/// 사진 속 물체를 찾는다. 웹에는 isolate가 없어 compute도 메인 스레드에서 돈다. 원본 사진을 Dart로
/// 디코드하면 몇 초씩 화면이 멈추므로, 디코드와 축소는 브라우저(Worker)에 맡기고 줄인 픽셀만 Dart로 본다.
Future<List<FoundObject>> findPhotoObjects(Uint8List photo) async {
  final pixels = await _pixels(photo.toJS, objectFinderSide.toJS).toDart;
  final image = img.Image.fromBytes(
    width: pixels.width,
    height: pixels.height,
    bytes: pixels.data.toDart.buffer,
    numChannels: 4,
  );
  return findObjectsInImage(image, pixels.width / pixels.sourceWidth);
}
