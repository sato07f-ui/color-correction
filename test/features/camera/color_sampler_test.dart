import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_correction/features/camera/services/color_sampler.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decodeImage(Uint8List pixels, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

void main() {
  test('中央領域の平均RGBを取得する', () async {
    final image = await _decodeImage(
      Uint8List.fromList([
        255,
        0,
        0,
        255,
        0,
        255,
        0,
        255,
        0,
        0,
        255,
        255,
        255,
        255,
        255,
        255,
      ]),
      2,
      2,
    );

    final sampled = await const ColorSampler().sampleCenter(
      image,
      regionFraction: 1,
    );

    expect(sampled?.r, 127);
    expect(sampled?.g, 127);
    expect(sampled?.b, 127);
    image.dispose();
  });
}
