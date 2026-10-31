import 'dart:io';

import 'package:flutter/services.dart';

/// 앱에 넣은 탐지 모델 파일들. scripts/fetch_model.sh가 assets/models/에 받아 둔다.
///
/// 파일 이름에 버전을 넣는다. 탐지 플러그인이 모델을 기기에 파일 이름으로 캐시하므로,
/// 이름이 같으면 앱을 업데이트해도 예전 모델이 계속 쓰인다.
class ModelBundle {
  const ModelBundle({
    required this.version,
    required this.modelAsset,
    required this.labelsAsset,
  });

  static const versionAsset = 'assets/models/VERSION';

  final String version;

  /// Android는 TFLite, iOS는 Core ML(.mlpackage.zip).
  final String modelAsset;
  final String labelsAsset;

  /// 지금 플랫폼에 맞는 모델 파일이 앱에 있으면 돌려준다. 받지 않았으면 null.
  static Future<ModelBundle?> find(AssetBundle bundle, {bool? ios}) async {
    final assets = (await AssetManifest.loadFromAssetBundle(
      bundle,
    )).listAssets().toSet();
    if (!assets.contains(versionAsset)) return null;
    final version = (await bundle.loadString(versionAsset)).trim();
    final extension = (ios ?? Platform.isIOS) ? 'mlpackage.zip' : 'tflite';
    final candidate = ModelBundle(
      version: version,
      modelAsset: 'assets/models/pillbox-$version.$extension',
      labelsAsset: 'assets/models/pillbox-$version.labels.json',
    );
    return assets.contains(candidate.modelAsset) &&
            assets.contains(candidate.labelsAsset)
        ? candidate
        : null;
  }
}
