import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../core/models/correction_settings.dart';
import 'correction_shader.dart';

/// 入力画像に色覚補正をかけて、描画先いっぱいに描く CustomPainter。
///
/// カメラ画面でも静止画画面でも、これを `CustomPaint` に渡せば補正後の画像が出る。
/// ```dart
/// CustomPaint(
///   painter: CorrectionPainter(
///     shader: correctionShader,
///     image: frame,
///     settings: ref.watch(correctionSettingsProvider),
///     quarterTurns: camera.sensorOrientation ~/ 90,
///   ),
/// )
/// ```
class CorrectionPainter extends CustomPainter {
  CorrectionPainter({
    required this.shader,
    required this.image,
    required this.settings,
    this.quarterTurns = 0,
  });

  final CorrectionShader shader;
  final ui.Image image;
  final CorrectionSettings settings;
  final int quarterTurns;

  @override
  void paint(Canvas canvas, Size size) {
    shader.apply(
      size: size,
      image: image,
      settings: settings,
      quarterTurns: quarterTurns,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader.shader);
  }

  @override
  bool shouldRepaint(CorrectionPainter old) =>
      old.image != image ||
      old.settings.type != settings.type ||
      old.settings.strength != settings.strength ||
      old.quarterTurns != quarterTurns;
}
