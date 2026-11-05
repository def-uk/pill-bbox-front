import 'package:flutter/material.dart';

import 'theme.dart';

/// 처음 열 때와 앱 안내에서 알리는 것 (docs/MVP.md 3장, 9.1).
class AppNotices extends StatelessWidget {
  const AppNotices({super.key});

  static const items = [
    (Icons.lock_rounded, '사진과 기록은 이 기기에만 저장돼요. 서버로 보내지 않아요.'),
    (
      Icons.photo_camera_rounded,
      '사진으로 알아보는 약은 의약품 96종뿐이에요. 영양제는 알아보지 못해서, 처음 한 번은 직접 골라 주세요. 그다음부터는 색·모양으로 추천해요.',
    ),
    (
      Icons.local_hospital_rounded,
      '알약몬은 의료 조언을 하지 않아요. 약을 놓쳤거나 궁금한 점은 의사·약사의 안내를 따르세요.',
    ),
    (Icons.casino_rounded, '뽑기는 무료이고 확률을 공개해요. 팔지 않아요.'),
    (Icons.ios_share_rounded, '공유 카드와 몬스터에는 약 이름과 병명이 나오지 않아요.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (icon, text) in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
