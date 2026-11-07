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

// sRGB（画面に出す色）と線形RGB（光の強さに比例する色）の変換
vec3 toLinear(vec3 c) {
  return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

vec3 toSrgb(vec3 c) {
  c = clamp(c, 0.0, 1.0);
  return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}

// 行列は「1行目が R、2行目が G、3行目が B の計算式」になるよう行ごとに書き、
// `rgb * M` の形で掛ける（GLSL の mat3 は列ごとに値を並べるため、この形で行列×ベクトルになる）。

// 色覚の見え方のシミュレーション（線形RGB）。
// Machado, Oliveira & Fernandes (2009) "A Physiologically-based Model for
// Simulation of Color Vision Deficiency" の重さ 1.0 の行列。
mat3 simulationMatrix(int type) {
  if (type == 0) {  // P型
    return mat3(
       0.152286,  1.052583, -0.204868,
       0.114503,  0.786281,  0.099216,
      -0.003882, -0.048116,  1.051998);
  } else if (type == 1) {  // D型
    return mat3(
       0.367322,  0.860646, -0.227968,
       0.280085,  0.672501,  0.047413,
      -0.011820,  0.042940,  0.968881);
  }
  return mat3(  // T型
     1.255528, -0.076749, -0.178779,
    -0.078411,  0.930809,  0.147602,
     0.004733,  0.691367,  0.303900);
}

// 見えなくなった差分（誤差）を、見える成分に振り直す行列。
// Fidaner et al. (2005) の誤差の振り直しをもとに、係数は docs/shader.md の方法で決めた。
// - P型・D型：赤の誤差を「緑を足し、青を引く」方向に移す（赤緑の違い → 黄青の違い）
// - T型：青の誤差を「赤を引き、緑を足す」方向に移す（黄青の違い → 赤緑の違い）
mat3 shiftMatrix(int type) {
  if (type == 0) {  // P型
    return mat3(
       0.0, 0.0, 0.0,
       0.5, 1.0, 0.0,
      -0.5, 0.0, 1.0);
  } else if (type == 1) {  // D型
    return mat3(
       0.0, 0.0, 0.0,
       0.6, 1.0, 0.0,
      -0.9, 0.0, 1.0);
  }
  return mat3(  // T型
    1.0, 0.0, -0.9,
    0.0, 1.0,  0.8,
    0.0, 0.0,  0.0);
}

// 色覚補正（ダルトニゼーション）。
// 1. 線形RGBにする
// 2. その色覚での見え方をシミュレーションし、元の色との差（見えなくなった差分）を求める
// 3. 差分を見える成分に振り直して元の色に足す
// 4. 強度に応じて、元の色と補正後の色を混ぜる
vec3 correct(vec3 rgb, int type, float strength) {
  if (strength <= 0.0) {
    return rgb;  // 強度 0 は元の色のまま（変換の誤差も出さない）
  }
  vec3 lin = toLinear(rgb);
  vec3 lost = lin - lin * simulationMatrix(type);
  vec3 corrected = toSrgb(lin + lost * shiftMatrix(type));
  return mix(rgb, corrected, strength);
}

void main() {
  vec2 uv = toTextureCoord(FlutterFragCoord().xy / uSize);
  vec3 rgb = texture(uTexture, uv).rgb;

  fragColor = vec4(correct(rgb, int(uType + 0.5), uStrength), 1.0);
}
