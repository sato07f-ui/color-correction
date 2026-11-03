// issue #3 PoC：カメラのフレーム（ui.Image）にシェーダーをかけて全画面に描く。
// 補正の代わりに色の反転で、シェーダーが効いていることを目で確かめる。
#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;          // 描画先のサイズ（論理ピクセル）
uniform vec2 uImageSize;     // 回転後（画面の向き）の画像サイズ
uniform float uQuarterTurns; // 画像を時計回りに何回90度回すか（センサーの向き / 90）
uniform float uInvert;       // 1.0 で色を反転する
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy / uSize;

  // 縦横比を保ったまま画面全体を覆う（はみ出た部分は切る）
  float viewAspect = uSize.x / uSize.y;
  float imageAspect = uImageSize.x / uImageSize.y;
  p -= 0.5;
  if (viewAspect > imageAspect) {
    p.y *= imageAspect / viewAspect;
  } else {
    p.x *= viewAspect / imageAspect;
  }
  p += 0.5;

  // 画面の座標から、回転前の画像の座標に戻す
  int turns = int(uQuarterTurns + 0.5);
  vec2 uv = p;
  if (turns == 1) {
    uv = vec2(p.y, 1.0 - p.x);
  } else if (turns == 2) {
    uv = vec2(1.0 - p.x, 1.0 - p.y);
  } else if (turns == 3) {
    uv = vec2(1.0 - p.y, p.x);
  }

  vec4 color = texture(uTexture, uv);
  if (uInvert > 0.5) {
    color.rgb = 1.0 - color.rgb;
  }
  fragColor = vec4(color.rgb, 1.0);
}
