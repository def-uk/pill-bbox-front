import 'package:flutter/material.dart';

import '../../data/models/drug_info.dart';
import '../../data/models/medication.dart';
import '../../data/models/pill_label.dart';
import 'drug_widgets.dart';
import 'theme.dart';
import 'widgets.dart';

/// 직접 넣은 약 이름. [DrugSearchSheet]에서 목록에 없는 이름을 골랐을 때 돌려준다.
extension type const CustomDrugName(String name) {}

/// 모델이 아는 약에서 고르고, 없으면 식약처 의약품에서 찾는다.
/// [Medication], [PillLabel], [DrugSummary], [CustomDrugName] 중 하나를 돌려준다.
class DrugSearchSheet extends StatefulWidget {
  const DrugSearchSheet({
    super.key,
    this.medications = const [],
    required this.labels,
    required this.searchDrugs,
    required this.drugImageUrl,
    this.allowCustom = false,
  });

  /// 이미 등록한 약. 맨 위에 둔다.
  final List<Medication> medications;
  final List<PillLabel> labels;

  /// 찾은 이름 그대로 직접 입력할 수 있다.
  final bool allowCustom;

  /// null이면 식약처에서 찾지 않는다 (서버 없는 빌드).
  final Future<DrugPage> Function(String query)? searchDrugs;
  final String Function(String itemSeq) drugImageUrl;

  @override
  State<DrugSearchSheet> createState() => DrugSearchSheetState();
}

class DrugSearchSheetState extends State<DrugSearchSheet> {
  String _query = '';

  /// 식약처에서 찾은 이름과 결과. 이름을 바꾸면 다시 찾을 때까지 숨긴다.
  String? _drugQuery;
  Future<DrugPage>? _drugResults;

  /// 식약처는 두 글자부터 찾는다. 한 글자는 결과가 너무 많다.
  bool get _canSearchDrugs =>
      widget.searchDrugs != null && _query.characters.length >= 2;

  void _searchDrugs() {
    if (!_canSearchDrugs) return;
    setState(() {
      _drugQuery = _query;
      _drugResults = widget.searchDrugs!(_query);
    });
  }

  @override
  Widget build(BuildContext context) {
    bool matchesQuery(String name) =>
        name.toLowerCase().contains(_query.toLowerCase());
    final registered = [
      for (final m in widget.medications)
        if (matchesQuery(m.name)) m,
    ];
    final matches = [
      for (final l in widget.labels)
        if (matchesQuery(l.name)) l,
    ];
    final showCustom = widget.allowCustom && _query.isNotEmpty;
    final searching = widget.searchDrugs != null;
    final showDrugs = _drugResults != null && _drugQuery == _query;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('약 고르기'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: SearchField(
                autofocus: true,
                hintText: '약 이름 검색',
                onChanged: (value) => setState(() => _query = value.trim()),
                onSubmitted: searching ? (_) => _searchDrugs() : null,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child:
                  registered.isEmpty &&
                      matches.isEmpty &&
                      !searching &&
                      !showCustom
                  ? const Center(child: Text('찾는 약이 없습니다'))
                  : ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      children: [
                        if (registered.isNotEmpty) ...[
                          const SheetSectionLabel('등록한 약'),
                          for (final m in registered)
                            ListTile(
                              title: Text(m.name),
                              onTap: () => Navigator.pop(context, m),
                            ),
                        ],
                        if ((searching || registered.isNotEmpty) &&
                            matches.isNotEmpty)
                          const SheetSectionLabel('사진으로 인식되는 약'),
                        for (final l in matches)
                          ListTile(
                            title: Text(l.name),
                            onTap: () => Navigator.pop(context, l),
                          ),
                        if (showCustom)
                          ListTile(
                            leading: const Icon(Icons.edit_rounded),
                            title: Text('\'$_query\' 직접 입력'),
                            subtitle: const Text('사진으로 인식되지 않아 직접 기록만 됩니다'),
                            onTap: () =>
                                Navigator.pop(context, CustomDrugName(_query)),
                          ),
                        if (searching) ...[
                          const SheetSectionLabel('식약처 의약품'),
                          if (showDrugs)
                            _DrugResults(
                              results: _drugResults!,
                              imageUrl: widget.drugImageUrl,
                              onRetry: _searchDrugs,
                            )
                          else
                            ListTile(
                              leading: const Icon(Icons.travel_explore_rounded),
                              title: Text(
                                _canSearchDrugs
                                    ? '식약처에서 \'$_query\' 찾기'
                                    : '식약처에서 찾기',
                              ),
                              subtitle: _canSearchDrugs
                                  ? null
                                  : const Text('이름을 두 글자 넘게 넣어 주세요'),
                              enabled: _canSearchDrugs,
                              onTap: _searchDrugs,
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrugResults extends StatelessWidget {
  const _DrugResults({
    required this.results,
    required this.imageUrl,
    required this.onRetry,
  });

  final Future<DrugPage> results;
  final String Function(String itemSeq) imageUrl;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: results,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            leading: const Icon(Icons.error_outline_rounded),
            title: Text('${snapshot.error}'),
            trailing: TextButton(onPressed: onRetry, child: const Text('다시')),
          );
        }
        final page = snapshot.data;
        if (page == null) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (page.items.isEmpty) {
          return const ListTile(title: Text('식약처에도 없는 약입니다'));
        }
        return Column(
          children: [
            for (final drug in page.items)
              DrugTile(
                drug: drug,
                imageUrl: imageUrl,
                onTap: () => Navigator.pop(context, drug),
              ),
            if (page.total > page.items.length)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  '${page.total}개 중 ${page.items.length}개. 이름을 더 자세히 넣어 보세요',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ),
          ],
        );
      },
    );
  }
}
