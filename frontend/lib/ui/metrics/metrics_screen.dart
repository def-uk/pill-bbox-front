import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/time_format.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import 'metrics_view_model.dart';

/// 테스터가 캡처해 보내는 지표 (docs/MVP.md 9.2). 약 이름, 병명, 날짜별 기록은 보여 주지 않는다.
class MetricsScreen extends StatelessWidget {
  const MetricsScreen({super.key});

  static String _ratio(int part, int whole) =>
      whole == 0 ? '-' : '${(part * 100 / whole).round()}%';

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MetricsViewModel>();
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('테스트 지표')),
      body: switch (vm.metrics) {
        null => const LoadingState(),
        final m => ListView(
          padding: pagePadding(context, top: AppSpacing.md),
          children: [
            Text(
              m.start == null
                  ? '아직 기록이 없어요'
                  : '${formatDate(m.start!)} ~ ${formatDate(m.end)} · ${m.days}일',
              style: textTheme.titleMedium?.copyWith(
                fontFeatures: AppTypography.tabular,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '첫 기록 날부터 최근 28일까지 세요.',
              style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            GroupCard(
              children: [
                for (final (title, detail, value) in [
                  (
                    '기록한 날',
                    '${m.recordedDays} / ${m.days}일',
                    _ratio(m.recordedDays, m.days),
                  ),
                  (
                    '일정 완료율',
                    '일정을 다 지킨 날 ${m.completedDays} / 일정이 있던 날 ${m.scheduledDays}',
                    _ratio(m.completedDays, m.scheduledDays),
                  ),
                  (
                    '처방 완주율',
                    '퇴치한 몬스터 ${m.defeated} / 등록한 처방 ${m.prescriptions}',
                    _ratio(m.defeated, m.prescriptions),
                  ),
                  (
                    '사진 기록 비율',
                    '사진 기록 ${m.cameraRecords} / 전체 기록 ${m.records}',
                    _ratio(m.cameraRecords, m.records),
                  ),
                  ('공유 카드 저장', '저장한 횟수', '${m.shareSaves}번'),
                ])
                  ListTile(
                    title: Text(title),
                    subtitle: Text(
                      detail,
                      style: const TextStyle(
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                    trailing: Text(
                      value,
                      style: AppTypography.headline.copyWith(
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '이 화면을 캡처해서 보내 주세요. 약 이름, 병명, 날짜별 기록은 들어 있지 않아요.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      },
    );
  }
}
