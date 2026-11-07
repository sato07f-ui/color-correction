import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../core/models/correction_settings.dart';

/// 色覚補正シェーダー（correction.frag）を読み込み、uniform を設定するクラス。
///
/// uniform の番号（index）を知っているのはこのクラスだけにする。
/// 使う側は [apply] に値を渡すだけで、番号を意識しなくてよい。
/// 詳しくは docs/shader.md を参照。
class CorrectionShader {
  CorrectionShader._(this.shader);

  /// pubspec.yaml の `shaders:` に書いたパスと同じにする
  static const assetKey = 'lib/features/shader/shaders/correction.frag';

  /// 読み込み済みのシェーダー。`Paint().shader` などに渡して描画する。
  final ui.FragmentShader shader;

  /// シェーダーを読み込む。時間がかかるので、起動時などに1回だけ呼ぶ。
  static Future<CorrectionShader> load() async {
    final program = await ui.FragmentProgram.fromAsset(assetKey);
    return CorrectionShader._(program.fragmentShader());
  }

  /// 描画の直前に、uniform と入力画像を設定する。
  ///
  /// - [size]：描画先のサイズ（CustomPainter の `size`）
  /// - [image]：入力画像（カメラのフレーム、または写真）
  /// - [quarterTurns]：画像を時計回りに何回90度回して表示するか。
  ///   カメラは `sensorOrientation ~/ 90`、向きを直した写真は 0
  /// - [settings]：補正タイプと強度
  void apply({
    required Size size,
    required ui.Image image,
    required CorrectionSettings settings,
    int quarterTurns = 0,
  }) {
    final rotated = quarterTurns.isOdd;
    shader
      ..setFloat(_Uniform.width, size.width)
      ..setFloat(_Uniform.height, size.height)
      ..setFloat(
        _Uniform.imageWidth,
        (rotated ? image.height : image.width).toDouble(),
      )
      ..setFloat(
        _Uniform.imageHeight,
        (rotated ? image.width : image.height).toDouble(),
      )
      ..setFloat(_Uniform.quarterTurns, quarterTurns.toDouble())
      ..setFloat(_Uniform.type, settings.type.index.toDouble())
      ..setFloat(_Uniform.strength, settings.strength)
      ..setImageSampler(_Sampler.texture, image);
  }

  void dispose() => shader.dispose();
}

/// correction.frag の uniform の番号。シェーダーで宣言した順に、float 1つにつき1つ進む。
/// docs/shader.md の表と必ずそろえること。
abstract final class _Uniform {
  static const width = 0; // uSize.x
  static const height = 1; // uSize.y
  static const imageWidth = 2; // uImageSize.x
  static const imageHeight = 3; // uImageSize.y
  static const quarterTurns = 4; // uQuarterTurns
  static const type = 5; // uType
  static const strength = 6; // uStrength
}

/// correction.frag の sampler の番号。宣言した順に 0 から数える。
abstract final class _Sampler {
  static const texture = 0; // uTexture
}
