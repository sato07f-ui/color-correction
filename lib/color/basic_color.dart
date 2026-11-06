// 基本色名（赤、黄赤、…、白、灰色、黒）をLab値から決める、チーム独自の規則。
// JIS Z 8102 の系統色名のデータは使っていない（外部データなし）。
// JISの分類とは一致しないので、境目は後から調整できるよう定数にしてある。
import 'dart:math' as math;

import 'color_math.dart';

/// 彩度がこれ未満なら無彩色（白・灰色・黒）として扱う。
const double achromaticChroma = 10;

/// 無彩色のとき、明るさがこれ以上なら「白」。
const double whiteMinL = 85;

/// 無彩色のとき、明るさがこれ以下なら「黒」。
const double blackMaxL = 25;

/// Lab の色相角（度）の区切り。[開始, 終了) の範囲で名前を決める。
/// 範囲外（335〜365度、つまり赤紫の帯）は最後の else で「赤紫」にする。
const List<(double, String)> _hueUpperBounds = [
  (55, '赤'),
  (85, '黄赤'),
  (112, '黄'),
  (130, '黄緑'),
  (185, '緑'),
  (240, '青緑'),
  (290, '青'),
  (315, '青紫'),
  (335, '紫'),
];

/// 赤の帯の開始。これ未満（と335以上）は赤紫。
const double _redStart = 5;

String classifyBasicColor(Lab lab) {
  final chroma = math.sqrt(lab.a * lab.a + lab.b * lab.b);
  if (chroma < achromaticChroma) {
    if (lab.l >= whiteMinL) return '白';
    if (lab.l <= blackMaxL) return '黒';
    return '灰色';
  }
  var hue = math.atan2(lab.b, lab.a) * 180 / math.pi;
  if (hue < 0) hue += 360;

  if (hue < _redStart) return '赤紫';
  for (final (upper, name) in _hueUpperBounds) {
    if (hue < upper) return name;
  }
  return '赤紫';
}
