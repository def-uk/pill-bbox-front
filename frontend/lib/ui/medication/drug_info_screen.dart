import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/drug_info.dart';
import '../../utils/time_format.dart';
import '../common/drug_widgets.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import 'drug_info_view_model.dart';

class DrugInfoScreen extends StatelessWidget {
  const DrugInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DrugInfoViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('약 정보'),
        actionsPadding: EdgeInsets.only(right: gutterOf(context) - 12),
        actions: [
          if (vm.detail != null && vm.available && !vm.choosing)
            TextButton(
              onPressed: vm.startChoosing,
              child: const Text('다른 약으로'),
            ),
          if (vm.detail != null && vm.choosing)
            TextButton(onPressed: vm.cancelChoosing, child: const Text('취소')),
        ],
      ),
      body: switch (vm) {
        DrugInfoViewModel(loading: true) => const LoadingState(),
        DrugInfoViewModel(notFound: true) => const EmptyState(
          icon: Icons.medication_rounded,
          title: '지워진 약입니다',
        ),
        DrugInfoViewModel(linking: true) => const LoadingState(
          message: '약 정보를 받는 중',
        ),
        DrugInfoViewModel(choosing: true) => const _Chooser(),
        DrugInfoViewModel(:final detail?) => _Detail(detail: detail),
        _ => const EmptyState(
          icon: Icons.cloud_off_rounded,
          title: '약 정보를 쓸 수 없습니다',
          message: '이 앱은 약 정보 서버에 연결되어 있지 않습니다',
        ),
      },
    );
  }
}

/// 약 이름으로 식약처에서 찾은 약 중에서 고른다.
class _Chooser extends StatelessWidget {
  const _Chooser();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DrugInfoViewModel>();
    final textTheme = Theme.of(context).textTheme;
    final page = vm.candidates;
    return ListView(
      padding: pagePadding(context),
      children: [
        Text('어떤 약인가요?', style: textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '식약처 의약품에서 먹는 약을 고르면 효능과 주의사항을 볼 수 있습니다.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        SearchField(
          hintText: vm.medicationName,
          onChanged: (_) {},
          onSubmitted: vm.search,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (vm.searching)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (vm.error != null)
          ListTile(
            leading: const Icon(Icons.error_outline_rounded),
            title: Text(vm.error!),
          )
        else if (page != null && page.items.isEmpty)
          const ListTile(
            title: Text('찾는 약이 없습니다'),
            subtitle: Text('이름을 줄여서 다시 찾아보세요'),
          )
        else if (page != null)
          GroupCard(
            children: [
              for (final drug in page.items)
                DrugTile(
                  drug: drug,
                  imageUrl: vm.imageUrl,
                  onTap: () => vm.choose(drug),
                ),
            ],
          ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.detail});

  final DrugDetail detail;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<DrugInfoViewModel>();
    final textTheme = Theme.of(context).textTheme;
    final looks = [
      if (detail.chart != null) ('성상', detail.chart!),
      if (detail.shape != null) ('모양', detail.shape!),
      if (detail.colors.isNotEmpty) ('색', detail.colors.join(', ')),
      if (detail.printFront != null) ('앞면 표시', detail.printFront!),
      if (detail.printBack != null) ('뒷면 표시', detail.printBack!),
      if (detail.size != null) ('크기', detail.size!),
      if (detail.form != null) ('제형', detail.form!),
      if (detail.className != null) ('분류', detail.className!),
    ];
    final sections = detail.guide?.sections ?? const [];
    final fetchedAt = vm.fetchedAt;
    return ListView(
      padding: pagePadding(context),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DrugThumbnail(drug: detail, imageUrl: vm.imageUrl, size: 88),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detail.name, style: textTheme.titleLarge),
                  if (detail.company != null || detail.otc != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      [?detail.company, ?detail.otc].join(' · '),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (looks.isNotEmpty) ...[
          const SectionLabel('생김새'),
          GroupCard(
            children: [
              for (final (label, value) in looks)
                ListTile(
                  dense: true,
                  title: Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  trailing: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.55,
                    ),
                    child: Text(value, textAlign: TextAlign.right),
                  ),
                ),
            ],
          ),
        ],
        if (sections.isEmpty) ...[
          const SectionLabel('복약 정보'),
          GroupCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: Text(
                  '식약처 e약은요에 복약 정보가 없는 약입니다. 주로 전문의약품이 그렇습니다. '
                  '효능과 주의사항은 처방한 의사나 약사에게 물어보세요.',
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
        for (final (title, body) in sections) ...[
          SectionLabel(title),
          GroupCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: SelectableText(body, style: textTheme.bodyMedium),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          [
            '출처: 식품의약품안전처 공공데이터 (의약품 낱알식별 정보, e약은요)',
            if (detail.guide?.updatedOn case final updated?)
              '복약 정보 갱신 $updated',
            if (fetchedAt != null) '받은 날 ${dateKey(fetchedAt)}',
            '복용 전 의사·약사와 상의하세요.',
          ].join('\n'),
          style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}
