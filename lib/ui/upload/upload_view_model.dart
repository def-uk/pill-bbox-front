import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/services/photo_picker_service.dart';

class UploadViewModel extends ChangeNotifier {
  UploadViewModel({required this._picker});

  static const samplePhotoAsset = 'assets/images/sample_pills.png';

  final PhotoPickerService _picker;
  bool _disposed = false;

  /// 사진 선택 창이 열려 있는 동안 true.
  bool picking = false;

  /// 사진을 골라 돌려준다. 고르지 않았거나 이미 고르는 중이면 null.
  Future<Uint8List?> pickPhoto() async {
    if (picking) return null;
    _setPicking(true);
    try {
      return await _picker.pick();
    } finally {
      _setPicking(false);
    }
  }

  /// 찍어 둔 사진이 없을 때 흐름을 확인하는 사진.
  Future<Uint8List> loadSamplePhoto() async =>
      (await rootBundle.load(samplePhotoAsset)).buffer.asUint8List();

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
