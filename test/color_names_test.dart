import 'dart:io';

import 'package:color_correction/color/color_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String text;

  setUpAll(() {
    text = File('assets/data/jis269.json').readAsStringSync();
    ColorNames.loadFromString(text);
  });

  test('JIS慣用色名は269色そろっている', () {
    expect(parseJisColors(text).length, 269);
  });

  test('とき色が正しく読める', () {
    final toki = parseJisColors(text).first;
    expect(toki.name, 'とき色');
    expect([toki.r, toki.g, toki.b], [249, 161, 208]);
  });

  test('とき色そのものを渡すと「とき色」が返る', () {
    final r = findColorName(249, 161, 208);
    expect(r.common, 'とき色');
  });

  test('桜色そのものを渡すと「桜色」が返る', () {
    final r = findColorName(255, 219, 237);
    expect(r.common, '桜色');
  });

  test('赤茶色と青紫で別々の色名が返る（受け入れ基準）', () {
    final redBrown = findColorName(150, 60, 50);
    final bluePurple = findColorName(90, 70, 170);
    expect(redBrown.basic, isNot(bluePurple.basic));
    // 慣用色名も、両方に付いたときは別の名前になる
    if (redBrown.common != null && bluePurple.common != null) {
      expect(redBrown.common, isNot(bluePurple.common));
    }
  });

  test('読み込む前に呼ぶとエラー', () {
    ColorNames.loadFromString('[]');
    expect(() => findColorName(0, 0, 0), throwsStateError);
    ColorNames.loadFromString(text);
  });
}
