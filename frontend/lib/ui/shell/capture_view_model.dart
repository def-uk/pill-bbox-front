import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/services/photo_picker_service.dart';

/// 아래 바 가운데 "기록하기"가 쓰는 사진 고르기. 어느 탭에서든 같은 것을 쓴다.
class CaptureViewModel extends ChangeNotifier {
  CaptureViewModel({required this._picker});

  final PhotoPickerService _picker;
  bool _disposed = false;

  /// 알약 사진이 없을 때 해 보는 샘플 사진을 두는 곳.
  static const sampleDirectory = 'assets/images/test_images/';

  /// 카메라나 사진 선택 창이 열려 있는 동안 true.
  bool picking = false;

  /// 사진을 찍거나 골라 돌려준다. 그냥 닫았거나 이미 여는 중이면 null.
  Future<Uint8List?> pickPhoto(PhotoSource source) async {
    if (picking) return null;
    _setPicking(true);
    try {
      return await _picker.pick(source);
    } finally {
      _setPicking(false);
    }
  }

  final _random = Random();
  String? _lastSample;

  /// 샘플 사진 중 하나를 고른다. 연달아 같은 사진은 고르지 않는다. 샘플이 없으면 null.
  Future<Uint8List?> loadSamplePhoto() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final samples = [
      for (final a in manifest.listAssets())
        if (a.startsWith(sampleDirectory) && a != _lastSample) a,
    ];
    if (samples.isEmpty) return null;
    final asset = _lastSample = samples[_random.nextInt(samples.length)];
    return (await rootBundle.load(asset)).buffer.asUint8List();
  }

  void _setPicking(bool value) {
    if (_disposed) return;
    picking = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
