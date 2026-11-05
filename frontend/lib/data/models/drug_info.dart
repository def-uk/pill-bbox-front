/// 식약처 의약품 정보. 백엔드 `/v1/drugs`의 응답 (backend/README.md 3.5).
class DrugSummary {
  const DrugSummary({
    required this.itemSeq,
    required this.name,
    this.company,
    this.otc,
    this.shape,
    this.colors = const [],
    this.printFront,
    this.printBack,
    this.hasImage = false,
  });

  factory DrugSummary.fromJson(Map<String, Object?> json) => DrugSummary(
    itemSeq: json['item_seq']! as String,
    name: json['name']! as String,
    company: json['company'] as String?,
    otc: json['otc'] as String?,
    shape: json['shape'] as String?,
    colors: [for (final c in json['colors'] as List? ?? const []) c as String],
    printFront: json['print_front'] as String?,
    printBack: json['print_back'] as String?,
    hasImage: json['has_image'] as bool? ?? false,
  );

  /// 품목기준코드.
  final String itemSeq;
  final String name;
  final String? company;

  /// 전문의약품 / 일반의약품.
  final String? otc;
  final String? shape;
  final List<String> colors;
  final String? printFront;
  final String? printBack;
  final bool hasImage;

  /// "원형 · 초록 · IDG"처럼 생김새를 한 줄로.
  String get looks => [
    ?shape,
    if (colors.isNotEmpty) colors.join('/'),
    if (printFront != null || printBack != null)
      [?printFront, ?printBack].join(' | '),
  ].join(' · ');

  Map<String, Object?> toJson() => {
    'item_seq': itemSeq,
    'name': name,
    'company': company,
    'otc': otc,
    'shape': shape,
    'colors': colors,
    'print_front': printFront,
    'print_back': printBack,
    'has_image': hasImage,
  };
}

class DrugPage {
  const DrugPage({required this.total, required this.items});

  factory DrugPage.fromJson(Map<String, Object?> json) => DrugPage(
    total: json['total']! as int,
    items: [
      for (final item in json['items']! as List)
        DrugSummary.fromJson(item as Map<String, Object?>),
    ],
  );

  final int total;
  final List<DrugSummary> items;
}

/// e약은요의 복약 정보. 주로 일반의약품에만 있다.
class DrugGuide {
  const DrugGuide({
    this.efficacy,
    this.usage,
    this.warning,
    this.caution,
    this.interaction,
    this.sideEffect,
    this.storage,
    this.updatedOn,
  });

  factory DrugGuide.fromJson(Map<String, Object?> json) => DrugGuide(
    efficacy: json['efficacy'] as String?,
    usage: json['usage'] as String?,
    warning: json['warning'] as String?,
    caution: json['caution'] as String?,
    interaction: json['interaction'] as String?,
    sideEffect: json['side_effect'] as String?,
    storage: json['storage'] as String?,
    updatedOn: json['updated_on'] as String?,
  );

  final String? efficacy;
  final String? usage;
  final String? warning;
  final String? caution;
  final String? interaction;
  final String? sideEffect;
  final String? storage;
  final String? updatedOn;

  /// (제목, 내용). 내용이 없는 항목은 뺀다.
  List<(String, String)> get sections => [
    if (efficacy != null) ('효능', efficacy!),
    if (usage != null) ('사용법', usage!),
    if (warning != null) ('먹기 전에 꼭 알아야 할 것', warning!),
    if (caution != null) ('주의사항', caution!),
    if (interaction != null) ('함께 먹으면 안 되는 약·음식', interaction!),
    if (sideEffect != null) ('부작용', sideEffect!),
    if (storage != null) ('보관법', storage!),
  ];

  Map<String, Object?> toJson() => {
    'efficacy': efficacy,
    'usage': usage,
    'warning': warning,
    'caution': caution,
    'interaction': interaction,
    'side_effect': sideEffect,
    'storage': storage,
    'updated_on': updatedOn,
  };
}

class DrugDetail extends DrugSummary {
  const DrugDetail({
    required super.itemSeq,
    required super.name,
    super.company,
    super.otc,
    super.shape,
    super.colors,
    super.printFront,
    super.printBack,
    super.hasImage,
    this.chart,
    this.form,
    this.className,
    this.lengthLong,
    this.lengthShort,
    this.thickness,
    this.guide,
  });

  factory DrugDetail.fromJson(Map<String, Object?> json) {
    final summary = DrugSummary.fromJson(json);
    final guide = json['guide'] as Map<String, Object?>?;
    return DrugDetail(
      itemSeq: summary.itemSeq,
      name: summary.name,
      company: summary.company,
      otc: summary.otc,
      shape: summary.shape,
      colors: summary.colors,
      printFront: summary.printFront,
      printBack: summary.printBack,
      hasImage: summary.hasImage,
      chart: json['chart'] as String?,
      form: json['form'] as String?,
      className: json['class_name'] as String?,
      lengthLong: (json['length_long'] as num?)?.toDouble(),
      lengthShort: (json['length_short'] as num?)?.toDouble(),
      thickness: (json['thickness'] as num?)?.toDouble(),
      guide: guide == null ? null : DrugGuide.fromJson(guide),
    );
  }

  /// 성상. "녹색의 원형 필름코팅정"
  final String? chart;

  /// 제형.
  final String? form;
  final String? className;

  /// mm.
  final double? lengthLong;
  final double? lengthShort;
  final double? thickness;
  final DrugGuide? guide;

  /// "7.6 × 7.6 × 3.5mm". 하나도 없으면 null.
  String? get size {
    final parts = [
      for (final v in [lengthLong, lengthShort, thickness])
        if (v != null) _mm(v),
    ];
    return parts.isEmpty ? null : '${parts.join(' × ')}mm';
  }

  static String _mm(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    'chart': chart,
    'form': form,
    'class_name': className,
    'length_long': lengthLong,
    'length_short': lengthShort,
    'thickness': thickness,
    'guide': guide?.toJson(),
  };
}
