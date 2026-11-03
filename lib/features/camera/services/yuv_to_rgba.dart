import 'dart:typed_data';

/// YUV420（Android のカメラが出す形式）を RGBA8888 に変換する。
///
/// U・V の plane は、画素が詰まっている形式（pixelStride = 1）と、
/// U と V が交互に並ぶ形式（pixelStride = 2）のどちらにも対応する。
/// 色の変換式は JPEG と同じ BT.601 フルレンジ。
Uint8List yuv420ToRgba({
  required int width,
  required int height,
  required Uint8List yPlane,
  required int yRowStride,
  required Uint8List uPlane,
  required Uint8List vPlane,
  required int uvRowStride,
  required int uvPixelStride,
}) {
  final out = Uint8List(width * height * 4);
  // 1画素ずつ4バイト書くより速いので、32bit 単位で書く。
  // Android（ARM）はリトルエンディアンなので、0xAABBGGRR の順で RGBA になる。
  final pixels = out.buffer.asUint32List();

  var i = 0;
  for (var row = 0; row < height; row++) {
    final yRow = row * yRowStride;
    final uvRow = (row >> 1) * uvRowStride;
    for (var col = 0; col < width; col++) {
      final y = yPlane[yRow + col];
      final uvIndex = uvRow + (col >> 1) * uvPixelStride;
      final u = uPlane[uvIndex] - 128;
      final v = vPlane[uvIndex] - 128;

      // 係数は 1024 倍した整数（1.402, 0.344, 0.714, 1.772）
      final r = _clamp(y + ((1436 * v) >> 10));
      final g = _clamp(y - ((352 * u + 731 * v) >> 10));
      final b = _clamp(y + ((1815 * u) >> 10));

      pixels[i++] = 0xFF000000 | (b << 16) | (g << 8) | r;
    }
  }
  return out;
}

int _clamp(int x) => x < 0 ? 0 : (x > 255 ? 255 : x);
