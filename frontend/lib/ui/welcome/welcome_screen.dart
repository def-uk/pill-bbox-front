import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/settings_repository.dart';
import '../../utils/character.dart';
import '../common/app_notices.dart';
import '../common/creature_art.dart';
import '../common/theme.dart';
import '../common/widgets.dart';

/// 처음 열 때: 앱 안내와 나이 확인 (docs/MVP.md 9.1). 만 14세 미만은 법정대리인 동의가 필요해 쓸 수 없다.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _declined = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    final textTheme = Theme.of(context).textTheme;
    if (!settings.loaded || settings.ageConfirmed) {
      return const Scaffold(body: LoadingState());
    }
    if (_declined) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.lock_clock_rounded,
          title: '알약몬은 만 14세 이상만 쓸 수 있어요',
          message: '만 14세 미만은 개인정보를 처리할 때 보호자 동의가 필요해서, 지금은 쓸 수 없어요.',
          action: TextButton(
            onPressed: () => setState(() => _declined = false),
            child: const Text('처음으로'),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: pagePadding(context, top: AppSpacing.xl),
          children: [
            const Center(
              child: CharacterArt(stage: CharacterStage.grown, size: 120),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '알약몬에 오신 걸 환영해요',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '먹기 전에 알약 사진 한 장이면 기록이 남고,\n기록으로 캐릭터가 자라고 처방 몬스터를 물리쳐요.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Text('만 14세 이상인가요?', style: textTheme.titleLarge),
                    Text(
                      '만 14세 미만은 보호자 동의가 필요해서 지금은 쓸 수 없어요.',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppNotices(),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => setState(() => _declined = true),
              child: const Text('아니요'),
            ),
          ),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: settings.confirmAge,
              child: const Text('네, 만 14세 이상이에요'),
            ),
          ),
        ],
      ),
    );
  }
}
