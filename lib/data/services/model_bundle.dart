import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 플랫폼마다 읽는 모델 형식. 모델은 플랫폼별 폴더에 두고, pubspec.yaml에서 그 플랫폼 빌드에만 넣는다.
enum ModelFormat {
  tflite('android', 'tflite'),
  coreml('ios', 'mlpackage.zip'),
  onnx('web', 'onnx');

  const ModelFormat(this.directory, this.extension);

  final String directory;
  final String extension;

  /// 지금 플랫폼이 읽는 형식. Android는 TFLite, iOS는 Core ML, 웹은 ONNX.
  static ModelFormat get current => kIsWeb
      ? onnx
      : defaultTargetPlatform == TargetPlatform.iOS
      ? coreml
      : tflite;
}

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

  /// assets/models/<플랫폼>/ 아래의 모델 파일 ([ModelFormat]).
  final String modelAsset;
  final String labelsAsset;

  /// 지금 플랫폼에 맞는 모델 파일이 앱에 있으면 돌려준다. 받지 않았으면 null.
  static Future<ModelBundle?> find(
    AssetBundle bundle, {
    ModelFormat? format,
  }) async {
    format ??= ModelFormat.current;
    final assets = (await AssetManifest.loadFromAssetBundle(
      bundle,
    )).listAssets().toSet();
    if (!assets.contains(versionAsset)) return null;
    final version = (await bundle.loadString(versionAsset)).trim();
    final candidate = ModelBundle(
      version: version,
      modelAsset:
          'assets/models/${format.directory}/pillbox-$version.${format.extension}',
      labelsAsset: 'assets/models/pillbox-$version.labels.json',
    );
    return assets.contains(candidate.modelAsset) &&
            assets.contains(candidate.labelsAsset)
        ? candidate
        : null;
  }
}
