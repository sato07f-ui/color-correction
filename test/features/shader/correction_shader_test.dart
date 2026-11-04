import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_correction/core/models/correction_settings.dart';
import 'package:color_correction/features/shader/services/correction_painter.dart';
import 'package:color_correction/features/shader/services/correction_shader.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// 左半分が [left]、右半分が [right] の 4x2 の画像を作る。
Future<ui.Image> makeTwoColorImage(Color left, Color right) {
  List<int> rgba(Color c) => [
    (c.r * 255).round(),
    (c.g * 255).round(),
    (c.b * 255).round(),
    255,
  ];
  final row = [...rgba(left), ...rgba(left), ...rgba(right), ...rgba(right)];
  final pixels = Uint8List.fromList([...row, ...row]);
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    4,
    2,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// 画像に補正をかけて size の大きさに描き、RGBA のバイト列を返す。
Future<ByteData> render(
  CorrectionShader shader,
  ui.Image image,
  CorrectionSettings settings,
  Size size, {
  int quarterTurns = 0,
}) async {
  final recorder = ui.PictureRecorder();
  CorrectionPainter(
    shader: shader,
    image: image,
    settings: settings,
    quarterTurns: quarterTurns,
  ).paint(Canvas(recorder), size);
  final result = await recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  return (await result.toByteData())!;
}

List<int> pixelAt(ByteData bytes, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return [for (var c = 0; c < 4; c++) bytes.getUint8(i + c)];
}

// ---- 補正の効果を測るための参照実装（シェーダーと同じ Machado 2009 の行列） ----

const _simulation = {
  CorrectionType.protan: [
    [0.152286, 1.052583, -0.204868],
    [0.114503, 0.786281, 0.099216],
    [-0.003882, -0.048116, 1.051998],
  ],
  CorrectionType.deutan: [
    [0.367322, 0.860646, -0.227968],
    [0.280085, 0.672501, 0.047413],
    [-0.011820, 0.042940, 0.968881],
  ],
  CorrectionType.tritan: [
    [1.255528, -0.076749, -0.178779],
    [-0.078411, 0.930809, 0.147602],
    [0.004733, 0.691367, 0.303900],
  ],
};

double _toLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// sRGB（0〜255）を、その色覚で見たときの線形RGBにする。
List<double> simulate(List<int> rgb, CorrectionType type) {
  final lin = [for (final c in rgb.take(3)) _toLinear(c / 255)];
  return [
    for (final row in _simulation[type]!)
      (row[0] * lin[0] + row[1] * lin[1] + row[2] * lin[2]).clamp(0.0, 1.0),
  ];
}

/// 線形RGBを CIE L*a*b* にする（D65）。
List<double> toLab(List<double> lin) {
  final x = 0.4124 * lin[0] + 0.3576 * lin[1] + 0.1805 * lin[2];
  final y = 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
  final z = 0.0193 * lin[0] + 0.1192 * lin[1] + 0.9505 * lin[2];
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final fx = f(x / 0.95047), fy = f(y), fz = f(z / 1.08883);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// その色覚で見たときの、2色の色差（ΔE76）。
double perceivedDifference(List<int> a, List<int> b, CorrectionType type) {
  final la = toLab(simulate(a, type));
  final lb = toLab(simulate(b, type));
  return math.sqrt(
    math.pow(la[0] - lb[0], 2) +
        math.pow(la[1] - lb[1], 2) +
        math.pow(la[2] - lb[2], 2),
  );
}

void main() {
  const red = Color(0xFFFF0000);
  const blue = Color(0xFF0000FF);

  testWidgets('強度 0 では、入力画像をそのまま描く', (tester) async {
    await tester.runAsync(() async {
      final shader = await CorrectionShader.load();
      final image = await makeTwoColorImage(red, blue);

      final bytes = await render(
        shader,
        image,
        const CorrectionSettings(strength: 0),
        const Size(40, 20),
      );

      expect(pixelAt(bytes, 40, 5, 10), [255, 0, 0, 255]); // 左は赤
      expect(pixelAt(bytes, 40, 35, 10), [0, 0, 255, 255]); // 右は青
    });
  });

  testWidgets('quarterTurns = 1 で時計回りに90度回して描く', (tester) async {
    await tester.runAsync(() async {
      final shader = await CorrectionShader.load();
      final image = await makeTwoColorImage(red, blue);

      // 4x2 の画像を回すと 2x4 になる。左が赤だったので、回した後は上が赤になる
      final bytes = await render(
        shader,
        image,
        const CorrectionSettings(strength: 0),
        const Size(20, 40),
        quarterTurns: 1,
      );

      expect(pixelAt(bytes, 20, 10, 5), [255, 0, 0, 255]); // 上は赤
      expect(pixelAt(bytes, 20, 10, 35), [0, 0, 255, 255]); // 下は青
    });
  });

  // 補正前はその色覚でほぼ同じ色に見える（色差 10 未満）2色が、
  // 補正後は見分けられる（色差 15 以上）ようになることを確かめる。
  // 色の組は docs/shader.md の「係数の決め方」で使った、典型的な混同の組。
  final confusionPairs = {
    CorrectionType.protan: (Color(0xFF527906), Color(0xFFB45813)), // 緑と橙茶
    CorrectionType.deutan: (Color(0xFF376C07), Color(0xFF8D1213)), // 緑と赤
    CorrectionType.tritan: (Color(0xFF34AC6E), Color(0xFF2ABA0A)), // 青緑と緑
  };

  for (final MapEntry(key: type, value: (left, right))
      in confusionPairs.entries) {
    testWidgets('${type.displayName}：見分けにくい2色の差が広がる', (tester) async {
      await tester.runAsync(() async {
        final shader = await CorrectionShader.load();
        final image = await makeTwoColorImage(left, right);

        final before = await render(
          shader,
          image,
          CorrectionSettings(type: type, strength: 0),
          const Size(40, 20),
        );
        final after = await render(
          shader,
          image,
          CorrectionSettings(type: type, strength: 1),
          const Size(40, 20),
        );

        final diffBefore = perceivedDifference(
          pixelAt(before, 40, 5, 10),
          pixelAt(before, 40, 35, 10),
          type,
        );
        final diffAfter = perceivedDifference(
          pixelAt(after, 40, 5, 10),
          pixelAt(after, 40, 35, 10),
          type,
        );

        expect(diffBefore, lessThan(10));
        expect(diffAfter, greaterThan(15));
      });
    });
  }

  testWidgets('P型：ペルソナが見分けにくい赤茶色と青紫の差が広がる', (tester) async {
    await tester.runAsync(() async {
      final shader = await CorrectionShader.load();
      // JIS 慣用色名の「赤茶」と、青紫系の色
      final image = await makeTwoColorImage(
        const Color(0xFFB15237),
        const Color(0xFF704CBC),
      );

      Future<double> differenceAt(double strength) async {
        final bytes = await render(
          shader,
          image,
          CorrectionSettings(type: CorrectionType.protan, strength: strength),
          const Size(40, 20),
        );
        return perceivedDifference(
          pixelAt(bytes, 40, 5, 10),
          pixelAt(bytes, 40, 35, 10),
          CorrectionType.protan,
        );
      }

      expect(await differenceAt(1), greaterThan(await differenceAt(0)));
    });
  });

  testWidgets('強度 0.5 では、元の色と強度 1 の色の間になる', (tester) async {
    await tester.runAsync(() async {
      final shader = await CorrectionShader.load();
      final image = await makeTwoColorImage(
        const Color(0xFFB45813),
        const Color(0xFFB45813),
      );

      Future<List<int>> colorAt(double strength) async => pixelAt(
        await render(
          shader,
          image,
          CorrectionSettings(strength: strength),
          const Size(4, 2),
        ),
        4,
        0,
        0,
      );

      final none = await colorAt(0);
      final half = await colorAt(0.5);
      final full = await colorAt(1);
      for (var c = 0; c < 3; c++) {
        expect(half[c], closeTo((none[c] + full[c]) / 2, 2));
      }
    });
  });
}
