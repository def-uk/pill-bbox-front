import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/services/camera_service.dart';

enum CaptureStatus { opening, ready, unavailable, capturing }

class CaptureViewModel extends ChangeNotifier {
  CaptureViewModel({required this._camera});

  static const samplePhotoAsset = 'assets/images/sample_pills.png';

  final CameraService _camera;
  bool _disposed = false;

  CaptureStatus status = CaptureStatus.opening;

  CameraController? get cameraController => _camera.controller;

  Future<void> open() async {
    final opened = await _camera.open();
    _setStatus(opened ? CaptureStatus.ready : CaptureStatus.unavailable);
  }

  /// 사진을 찍어 돌려준다. 찍는 중이면 null.
  Future<Uint8List?> takePicture() async {
    if (status != CaptureStatus.ready) return null;
    _setStatus(CaptureStatus.capturing);
    try {
      return await _camera.takePicture();
    } finally {
      _setStatus(CaptureStatus.ready);
    }
  }

  /// 카메라가 없는 시뮬레이터에서 흐름을 확인할 때 쓰는 사진.
  Future<Uint8List> loadSamplePhoto() async =>
      (await rootBundle.load(samplePhotoAsset)).buffer.asUint8List();

  void _setStatus(CaptureStatus value) {
    if (_disposed) return;
    status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _camera.close();
    super.dispose();
  }
}
