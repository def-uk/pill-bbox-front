import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/appearance.dart';
import 'package:pillbbox/utils/monster_look.dart';

void main() {
  test('사진 색(CIELAB)을 색 이름으로 나눈다', () {
    // sRGB 기본색을 CIELAB으로 바꾼 값.
    expect(labColorName(95, 0, 5), '하양');
    expect(labColorName(55, 2, -3), '회색');
    expect(labColorName(20, 1, 1), '검정');
    expect(labColorName(54, 80, 67), '빨강');
    expect(labColorName(75, 24, 79), '주황');
    expect(labColorName(97, -16, 93), '노랑');
    expect(labColorName(46, -52, 50), '초록');
    expect(labColorName(32, 68, -112), '파랑');
    expect(labColorName(30, 58, -36), '보라');
    expect(labColorName(84, 25, 4), '분홍');
  });

  test('식약처 생김새를 먼저 쓰고, 색을 모르면 null', () {
    expect(lookFromDrug(['주황', '하양'], '장방형'), (color: '주황', shape: '길쭉'));
    expect(lookFromDrug(['하양'], '원형'), (color: '하양', shape: '동글'));
    expect(lookFromDrug(['분홍'], '경질캡슐'), (color: '분홍', shape: '캡슐'));
    expect(lookFromDrug(['초록'], '삼각형'), (color: '초록', shape: '각진'));
    expect(lookFromDrug(const [], '원형'), isNull);
  });

  test('사진으로 남긴 색·모양은 평균을 쓰고, 병명·약 이름 없이 이름을 짓는다', () {
    final look = lookFromAppearances(const [
      Appearance(l: 74, a: 22, b: 78, elongation: 2.0),
      Appearance(l: 76, a: 26, b: 80, elongation: 2.4),
    ]);
    expect(look, (color: '주황', shape: '길쭉'));
    expect(monsterName(look), '주황 길쭉 몬스터');
    expect(lookFromAppearances(const []), isNull);
    expect(monsterName(null), defaultMonsterName);
  });
}
