import 'dart:typed_data';

import 'package:camera/camera.dart';

/// 후면 카메라를 열고 사진을 찍는다.
class CameraService {
  CameraController? _controller;

  /// 열린 카메라. 미리보기에 쓴다.
  CameraController? get controller => _controller;

  /// 카메라를 연다. 카메라가 없거나 권한이 없으면 false.
  Future<bool> open() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      _controller = controller;
      return true;
    } on CameraException {
      return false;
    }
  }

  Future<Uint8List> takePicture() async {
    final file = await _controller!.takePicture();
    return file.readAsBytes();
  }

  Future<void> close() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
