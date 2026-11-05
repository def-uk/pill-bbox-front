import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/drug_info.dart';

/// 맥미니 백엔드를 거쳐 식약처 의약품 정보를 받는다 (backend/README.md 3.5).
///
/// 서버 주소는 빌드할 때 `--dart-define=API_BASE_URL=https://api.<도메인>`으로 넣는다.
/// 비어 있으면 [available]이 false이고 앱은 약 찾기·약 정보를 숨긴다.
class DrugInfoService {
  DrugInfoService({String? baseUrl, http.Client? client})
    : baseUrl = _trimSlash(
        baseUrl ?? const String.fromEnvironment('API_BASE_URL'),
      ),
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  bool get available => baseUrl.isNotEmpty;

  /// 이름 일부로 찾는다. 한 쪽에 20개.
  Future<DrugPage> search(String query, {int page = 1}) async {
    final json = await _get(
      Uri.parse(
        '$baseUrl/v1/drugs',
      ).replace(queryParameters: {'q': query.trim(), 'page': '$page'}),
    );
    return DrugPage.fromJson(json!);
  }

  /// 식약처에 없는 약이면 null.
  Future<DrugDetail?> detail(String itemSeq) async {
    final json = await _get(
      Uri.parse('$baseUrl/v1/drugs/${Uri.encodeComponent(itemSeq)}'),
      allowNotFound: true,
    );
    return json == null ? null : DrugDetail.fromJson(json);
  }

  /// 낱알 사진 주소. 서버가 대신 받아 준다(웹의 교차 출처 격리 때문).
  String imageUrl(String itemSeq) =>
      '$baseUrl/v1/drugs/${Uri.encodeComponent(itemSeq)}/image';

  Future<Map<String, Object?>?> _get(
    Uri uri, {
    bool allowNotFound = false,
  }) async {
    if (!available) throw const DrugInfoException('약 정보 서버가 없습니다');
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on Exception {
      throw const DrugInfoException('약 정보 서버에 연결하지 못했습니다');
    }
    if (allowNotFound && response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw DrugInfoException(switch (response.statusCode) {
        429 => '잠시 뒤에 다시 시도해 주세요',
        502 => '식약처에서 답을 받지 못했습니다',
        503 => '약 정보 서비스를 쓸 수 없습니다',
        _ => '약 정보를 받지 못했습니다 (${response.statusCode})',
      });
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
  }

  static String _trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

class DrugInfoException implements Exception {
  const DrugInfoException(this.message);

  final String message;

  @override
  String toString() => message;
}
