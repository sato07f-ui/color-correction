import 'dart:ui' as ui;

class SampledColor {
  const SampledColor(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;
}

/// カメラ画像の中央にある照準領域の平均色を取得する。
class ColorSampler {
  const ColorSampler();

  Future<SampledColor?> sampleCenter(
    ui.Image image, {
    double regionFraction = 0.12,
  }) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;

    final width = image.width;
    final height = image.height;
    final regionWidth = (width * regionFraction)
        .round()
        .clamp(1, width)
        .toInt();
    final regionHeight = (height * regionFraction)
        .round()
        .clamp(1, height)
        .toInt();
    final left = (width - regionWidth) ~/ 2;
    final top = (height - regionHeight) ~/ 2;
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    var red = 0;
    var green = 0;
    var blue = 0;
    var count = 0;
    for (var y = top; y < top + regionHeight; y++) {
      for (var x = left; x < left + regionWidth; x++) {
        final offset = (y * width + x) * 4;
        red += bytes[offset];
        green += bytes[offset + 1];
        blue += bytes[offset + 2];
        count++;
      }
    }

    if (count == 0) return null;
    return SampledColor(red ~/ count, green ~/ count, blue ~/ count);
  }
}
