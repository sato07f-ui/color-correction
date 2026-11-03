import 'dart:typed_data';

import 'package:color_correction/features/camera/services/yuv_to_rgba.dart';
import 'package:flutter_test/flutter_test.dart';

/// 全画素が同じ YUV の 2x2 画像を変換し、左上の RGBA を返す。
List<int> convertSolid(int y, int u, int v, {required int uvPixelStride}) {
  final uv = uvPixelStride == 1 ? [u] : [u, v];
  final vu = uvPixelStride == 1 ? [v] : [v, u];
  final rgba = yuv420ToRgba(
    width: 2,
    height: 2,
    yPlane: Uint8List.fromList([y, y, y, y]),
    yRowStride: 2,
    uPlane: Uint8List.fromList(uv),
    vPlane: Uint8List.fromList(vu),
    uvRowStride: uvPixelStride,
    uvPixelStride: uvPixelStride,
  );
  return rgba.sublist(0, 4);
}

void main() {
  for (final stride in [1, 2]) {
    group('pixelStride = $stride', () {
      test('白', () {
        expect(convertSolid(255, 128, 128, uvPixelStride: stride), [
          255,
          255,
          255,
          255,
        ]);
      });

      test('黒', () {
        expect(convertSolid(0, 128, 128, uvPixelStride: stride), [
          0,
          0,
          0,
          255,
        ]);
      });

      test('赤（JPEG の YCbCr で 76, 85, 255）', () {
        final rgba = convertSolid(76, 85, 255, uvPixelStride: stride);
        expect(rgba[0], closeTo(255, 2));
        expect(rgba[1], closeTo(0, 2));
        expect(rgba[2], closeTo(0, 2));
      });

      test('青（JPEG の YCbCr で 29, 255, 107）', () {
        final rgba = convertSolid(29, 255, 107, uvPixelStride: stride);
        expect(rgba[0], closeTo(0, 2));
        expect(rgba[1], closeTo(0, 2));
        expect(rgba[2], closeTo(255, 2));
      });
    });
  }

  test('行の末尾に余白（rowStride > width）があっても正しく読む', () {
    // 2x2 の画像。Y の各行の後ろに余白 2 バイト（99）が付いている
    final rgba = yuv420ToRgba(
      width: 2,
      height: 2,
      yPlane: Uint8List.fromList([10, 20, 99, 99, 30, 40, 99, 99]),
      yRowStride: 4,
      uPlane: Uint8List.fromList([128]),
      vPlane: Uint8List.fromList([128]),
      uvRowStride: 1,
      uvPixelStride: 1,
    );
    expect([rgba[0], rgba[4], rgba[8], rgba[12]], [10, 20, 30, 40]);
  });
}
