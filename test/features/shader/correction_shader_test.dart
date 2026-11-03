import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_correction/core/models/correction_settings.dart';
import 'package:color_correction/features/shader/services/correction_painter.dart';
import 'package:color_correction/features/shader/services/correction_shader.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// 左半分が赤、右半分が青の 4x2 の画像を作る。
Future<ui.Image> makeRedBlueImage() {
  const red = [255, 0, 0, 255];
  const blue = [0, 0, 255, 255];
  final row = [...red, ...red, ...blue, ...blue];
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

/// painter で size の大きさに描き、RGBA のバイト列を返す。
Future<ByteData> render(CorrectionPainter painter, Size size) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  return (await image.toByteData())!;
}

List<int> pixelAt(ByteData bytes, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return [for (var c = 0; c < 4; c++) bytes.getUint8(i + c)];
}

void main() {
  testWidgets('補正を実装するまでは、入力画像をそのまま描く', (tester) async {
    await tester.runAsync(() async {
      final shader = await CorrectionShader.load();
      final image = await makeRedBlueImage();

      final bytes = await render(
        CorrectionPainter(
          shader: shader,
          image: image,
          settings: const CorrectionSettings(),
        ),
        const Size(40, 20),
      );

      expect(pixelAt(bytes, 40, 5, 10), [255, 0, 0, 255]); // 左は赤
      expect(pixelAt(bytes, 40, 35, 10), [0, 0, 255, 255]); // 右は青
    });
  });

  testWidgets('quarterTurns = 1 で時計回りに90度回して描く', (tester) async {
    await tester.runAsync(() async {
      final shader = await CorrectionShader.load();
      final image = await makeRedBlueImage();

      // 4x2 の画像を回すと 2x4 になる。左が赤だったので、回した後は上が赤になる
      final bytes = await render(
        CorrectionPainter(
          shader: shader,
          image: image,
          settings: const CorrectionSettings(),
          quarterTurns: 1,
        ),
        const Size(20, 40),
      );

      expect(pixelAt(bytes, 20, 10, 5), [255, 0, 0, 255]); // 上は赤
      expect(pixelAt(bytes, 20, 10, 35), [0, 0, 255, 255]); // 下は青
    });
  });
}
