import 'package:flutter/material.dart';

import '../../data/models/cosmetic.dart';
import '../../utils/character.dart';
import 'creature_art.dart';
import 'theme.dart';

Color gradeColor(Grade grade) => switch (grade) {
  Grade.common => AppColors.inkMuted,
  Grade.rare => AppColors.primary,
  Grade.unique => const Color(0xFFD08A00),
};

/// "희귀"처럼 등급을 작게.
class GradeBadge extends StatelessWidget {
  const GradeBadge(this.grade, {super.key});

  final Grade grade;

  @override
  Widget build(BuildContext context) {
    final color = gradeColor(grade);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: color)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          grade.label,
          style: AppTypography.captionStrong.copyWith(color: color),
        ),
      ),
    );
  }
}

/// 아이템을 입은 캐릭터로 미리 보여 준다.
class CosmeticPreview extends StatelessWidget {
  const CosmeticPreview({
    super.key,
    required this.cosmetic,
    this.size = 64,
    this.stage = CharacterStage.grown,
  });

  final Cosmetic cosmetic;
  final double size;
  final CharacterStage stage;

  @override
  Widget build(BuildContext context) => CharacterArt(
    stage: stage,
    size: size,
    skinId: cosmetic.slot == CosmeticSlot.skin ? cosmetic.id : null,
    accessoryId: cosmetic.slot == CosmeticSlot.accessory ? cosmetic.id : null,
  );
}
