import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/services/model_bundle.dart';

/// 지정한 파일만 있는 에셋 묶음.
class FakeAssetBundle extends CachingAssetBundle {
  FakeAssetBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        for (final path in files.keys)
          path: [
            {'asset': path},
          ],
      })!;
    }
    final file = files[key];
    if (file == null) throw StateError('없는 에셋: $key');
    return ByteData.sublistView(utf8.encode(file));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const version = {'assets/models/VERSION': 'model-v1\n'};
  const labels = {'assets/models/pillbox-model-v1.labels.json': '[]'};

  test('VERSION에 적힌 버전의 플랫폼 모델과 labels를 찾는다', () async {
    final bundle = FakeAssetBundle({
      ...version,
      ...labels,
      'assets/models/pillbox-model-v1.tflite': '',
      'assets/models/pillbox-model-v1.mlpackage.zip': '',
      'assets/models/pillbox-model-v1.onnx': '',
    });

    final android = await ModelBundle.find(bundle, extension: 'tflite');
    expect(android?.version, 'model-v1');
    expect(android?.modelAsset, 'assets/models/pillbox-model-v1.tflite');
    expect(android?.labelsAsset, 'assets/models/pillbox-model-v1.labels.json');

    final ios = await ModelBundle.find(bundle, extension: 'mlpackage.zip');
    expect(ios?.modelAsset, 'assets/models/pillbox-model-v1.mlpackage.zip');

    final web = await ModelBundle.find(bundle, extension: 'onnx');
    expect(web?.modelAsset, 'assets/models/pillbox-model-v1.onnx');
  });

  test('모델을 받지 않았거나 다른 버전이면 null', () async {
    expect(
      await ModelBundle.find(FakeAssetBundle(version), extension: 'tflite'),
      isNull,
    );
    expect(
      await ModelBundle.find(
        FakeAssetBundle({
          ...version,
          ...labels,
          'assets/models/pillbox-model-v0.tflite': '',
        }),
        extension: 'tflite',
      ),
      isNull,
    );
    expect(await ModelBundle.find(FakeAssetBundle({}), extension: 'tflite'), isNull);
  });
}
