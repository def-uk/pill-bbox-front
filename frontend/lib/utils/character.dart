/// 내 캐릭터의 성장 단계. 누적 경험치로 정한다 (docs/MVP.md 6.1).
///
/// 경험치는 기록에서 매번 다시 세므로([calculateRewards]) 단계도 저장하지 않는다.
enum CharacterStage {
  egg('알', 0),
  baby('아기', 3),
  child('어린이', 7),
  grown('성장', 14),
  complete('완성', 30);

  const CharacterStage(this.label, this.minExp);

  final String label;

  /// 이 단계가 되는 누적 경험치.
  final int minExp;

  static CharacterStage of(int exp) =>
      values.lastWhere((s) => exp >= s.minExp, orElse: () => egg);

  /// 다음 단계. 완성이면 null.
  CharacterStage? get next =>
      index + 1 < values.length ? values[index + 1] : null;
}

/// 단계 안에서 얼마나 자랐는지.
class Growth {
  const Growth(this.exp);

  final int exp;

  CharacterStage get stage => CharacterStage.of(exp);

  /// 다음 단계까지 남은 경험치. 완성이면 0.
  int get toNext => stage.next == null ? 0 : stage.next!.minExp - exp;

  /// 이 단계에서 다음 단계까지 0~1. 완성이면 1.
  double get progress {
    final next = stage.next;
    if (next == null) return 1;
    return (exp - stage.minExp) / (next.minExp - stage.minExp);
  }
}
