// 色名判定API（F-05）。
//
// 使い方:
//   await ColorNames.load();                 // アプリ起動時に1回だけ
//   final r = findColorName(180, 90, 70);    // 補正前の色（0〜255）を渡す
//   r.basic   // 基本色名（必ず入る）
//   r.common  // 慣用色名（遠いときは null。そのときは basic だけ表示する）
//
// assets/data/jis269.json は読み込むだけで、書き換えない（CC BY-SA 4.0）。
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'basic_color.dart';
import 'color_math.dart';

/// これ以下の ΔE00 なら「小豆色」とそのまま言う。
const double nearEnough = 6;

/// これ以下なら「小豆色に近い色」と言う。これより遠ければ null。
const double roughlyNear = 15;

class ColorNameResult {
  final String basic;
  final String? common;
  const ColorNameResult(this.basic, this.common);

  @override
  String toString() => 'ColorNameResult($basic, $common)';
}

class JisColor {
  final String name;
  final String munsell;
  final int r;
  final int g;
  final int b;
  final Lab lab;

  JisColor(this.name, this.munsell, this.r, this.g, this.b)
      : lab = rgbToLab(r, g, b);

  factory JisColor.fromJson(Map<String, dynamic> json) {
    final hex = (json['hex'] as String).substring(1); // 先頭の # を除く
    final v = int.parse(hex, radix: 16);
    return JisColor(
      json['jis'] as String,
      json['munsell'] as String,
      (v >> 16) & 0xFF,
      (v >> 8) & 0xFF,
      v & 0xFF,
    );
  }
}

/// JSON の文字列から色の一覧を作る（Flutter なしでテストできる）。
List<JisColor> parseJisColors(String text) {
  final list = jsonDecode(text) as List<dynamic>;
  return list
      .map((e) => JisColor.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

class ColorNames {
  ColorNames._();

  static List<JisColor> _colors = const [];

  static bool get isLoaded => _colors.isNotEmpty;
  static List<JisColor> get colors => _colors;

  /// アプリ起動時に1回呼ぶ。
  static Future<void> load() async {
    final text = await rootBundle.loadString('assets/data/jis269.json');
    loadFromString(text);
  }

  /// テスト用。文字列から直接読み込む。
  static void loadFromString(String text) {
    _colors = parseJisColors(text);
  }
}

/// 色（補正前の赤・緑・青、各 0〜255）から色名を返す。
ColorNameResult findColorName(int r, int g, int b) {
  if (!ColorNames.isLoaded) {
    throw StateError('先に await ColorNames.load() を呼んでください');
  }
  final lab = rgbToLab(r, g, b);
  final basic = classifyBasicColor(lab);

  JisColor? best;
  var bestDistance = double.infinity;
  for (final c in ColorNames.colors) {
    final d = ciede2000(lab, c.lab);
    if (d < bestDistance) {
      bestDistance = d;
      best = c;
    }
  }

  String? common;
  if (best != null) {
    if (bestDistance <= nearEnough) {
      common = best.name;
    } else if (bestDistance <= roughlyNear) {
      common = '${best.name}に近い色';
    }
  }
  return ColorNameResult(basic, common);
}
