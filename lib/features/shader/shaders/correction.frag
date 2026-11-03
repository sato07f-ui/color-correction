// 色覚補正シェーダー（本番用）
//
// uniform の並びと意味は docs/shader.md にまとめている。
// 並びを変えると Dart 側（correction_shader.dart）と食い違うので、
// 新しい uniform は必ず一番後ろに足すこと。
#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

// ---- MVP（index 0〜6）----
uniform vec2 uSize;          // 0-1: 描画先のサイズ（論理ピクセル）
uniform vec2 uImageSize;     // 2-3: 回転後（画面の向き）の画像サイズ
uniform float uQuarterTurns; // 4:   画像を時計回りに何回90度回すか（0〜3）
uniform float uType;         // 5:   0=P型, 1=D型, 2=T型（CorrectionType.index）
uniform float uStrength;     // 6:   補正強度 0.0〜1.0

// ---- 追加機能（index 7〜）は docs/shader.md の予約に沿って、ここより後ろに足す ----

uniform sampler2D uTexture;  // sampler 0: 入力画像（カメラのフレーム、または写真）

out vec4 fragColor;

// 描画先の座標（0〜1）を、入力画像のテクスチャ座標（0〜1）に変換する。
// 縦横比を保ったまま画面全体を覆い（はみ出た部分は切る）、向きを直す。
vec2 toTextureCoord(vec2 p) {
  float viewAspect = uSize.x / uSize.y;
  float imageAspect = uImageSize.x / uImageSize.y;
  p -= 0.5;
  if (viewAspect > imageAspect) {
    p.y *= imageAspect / viewAspect;
  } else {
    p.x *= viewAspect / imageAspect;
  }
  p += 0.5;

  int turns = int(uQuarterTurns + 0.5);
  if (turns == 1) {
    return vec2(p.y, 1.0 - p.x);
  } else if (turns == 2) {
    return vec2(1.0 - p.x, 1.0 - p.y);
  } else if (turns == 3) {
    return vec2(1.0 - p.y, p.x);
  }
  return p;
}

// 色覚補正（ダルトニゼーション）。issue #20〜#22 で実装する。
// いまは入力の色をそのまま返す。
vec3 correct(vec3 rgb, int type, float strength) {
  return rgb;
}

void main() {
  vec2 uv = toTextureCoord(FlutterFragCoord().xy / uSize);
  vec3 rgb = texture(uTexture, uv).rgb;

  vec3 result = correct(rgb, int(uType + 0.5), uStrength);

  // 使われていない uniform はコンパイル時に消され、index がずれることがある。
  // 補正を実装するまでの間、uType と uStrength を確実に残すための処理（実際には実行されない）。
  if (uType < -1.0) {
    result = vec3(uStrength);
  }

  fragColor = vec4(result, 1.0);
}
