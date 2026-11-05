import 'package:flutter/material.dart';

import '../../data/models/cosmetic.dart';
import '../../utils/character.dart';
import '../../utils/monster_look.dart';
import '../common/creature_art.dart';
import '../common/theme.dart';

/// 공유 카드에 넣는 것: 장착한 캐릭터와 펫뿐이다. 약 이름, 병명, 복용 기록, 날짜는 넣지 않는다 (docs/MVP.md 8장).
class ShareCardData {
  const ShareCardData({required this.exp, this.skin, this.accessory, this.pet});

  /// 단계를 정하는 데만 쓰고 카드에 숫자로 쓰지 않는다.
  final int exp;
  final Cosmetic? skin;
  final Cosmetic? accessory;

  /// (처방 id, 생김새). 펫이 없으면 null.
  final (int, MonsterLook?)? pet;
}

/// 4:5 공유 카드. 저장할 때 1080×1350으로 그린다.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.data});

  final ShareCardData data;

  /// 카드 폭에 대한 높이.
  static const aspectRatio = 4 / 5;

  @override
  Widget build(BuildContext context) {
    final stage = CharacterStage.of(data.exp);
    final pet = data.pet;
    final items = [
      ?data.skin?.name,
      ?data.accessory?.name,
      if (pet != null) '펫 · ${monsterName(pet.$2)}',
    ];
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4B1EFF), Color(0xFF7A5CFF)],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(w * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '알약몬',
                    style: TextStyle(
                      color: CreatureColors.lime,
                      fontSize: w * 0.075,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: w * 0.04),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(w * 0.06),
                      ),
                      child: Center(
                        child: FittedBox(
                          child: Padding(
                            padding: EdgeInsets.all(w * 0.04),
                            child: CharacterWithPet(
                              stageExp: data.exp,
                              skinId: data.skin?.id,
                              accessoryId: data.accessory?.id,
                              pet: pet,
                              size: w * 0.55,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: w * 0.04),
                  Text(
                    '내 캐릭터 · ${stage.label}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: w * 0.06,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (items.isNotEmpty)
                    Text(
                      items.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: w * 0.04,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
