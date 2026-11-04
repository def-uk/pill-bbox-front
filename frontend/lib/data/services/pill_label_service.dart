import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/pill_label.dart';

/// 탐지 모델이 아는 약 목록을 읽는다.
class PillLabelService {
  PillLabelService({this.asset = sampleLabelsAsset, AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  /// 모델을 받지 않았을 때 FakePillDetector와 짝을 이루는 샘플 목록.
  static const sampleLabelsAsset = 'assets/labels/sample_labels.json';

  final String asset;
  final AssetBundle _bundle;
  Future<List<PillLabel>>? _labels;

  Future<List<PillLabel>> load() => _labels ??= _read();

  Future<List<PillLabel>> _read() async {
    final json = jsonDecode(await _bundle.loadString(asset)) as List<Object?>;
    return [
      for (final item in json)
        PillLabel.fromJson(item! as Map<String, Object?>),
    ];
  }
}
