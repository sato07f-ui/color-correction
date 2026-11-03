# シェーダーの仕様（uniform の並びと使い方）

色覚補正シェーダー `correction.frag` の仕組みと、Dart から使う方法をまとめた資料です。
シェーダーを書く人（担当B）だけでなく、カメラ（担当A）や画面（担当D）からシェーダーを呼ぶ人も読んでください。

関連する issue：#7（この資料）、#3（方式を決めた PoC）、#13（カメラのフレームを渡す）、#20〜#22（補正の中身）

---

## 1. まず知っておくこと

### シェーダーとは

シェーダーは、**GPU（画像処理が得意なチップ）の上で動く小さなプログラム**です。
このアプリでは「フラグメントシェーダー」という種類を使います。これは**画面の1画素ごとに「この画素は何色にするか」を計算するプログラム**です。

スマホの画面は数百万画素あります。CPU で1画素ずつ計算すると間に合いませんが、GPU はたくさんの画素を同時に計算できます。
そのため、カメラ映像に毎秒30回補正をかけるような処理は、シェーダーで行います。

シェーダーは Dart ではなく **GLSL** という C 言語に似た言語で書きます。拡張子は `.frag` です。

### このアプリでの処理の流れ

```
カメラ（YUV420形式のフレーム）
   │  startImageStream で受け取る（担当A）
   ▼
yuv_to_rgba.dart … CPU で RGBA 形式に変換する（担当A）
   │
   ▼
ui.Image … Flutter で扱える画像にする（担当A）
   │
   ▼
CorrectionPainter … シェーダーに画像と設定を渡して描く（担当B が用意、A・D が使う）
   │
   ▼
correction.frag … GPU で1画素ずつ補正する（担当B）
   │
   ▼
画面に表示
```

静止画モードでは、カメラの代わりに写真を `ui.Image` にして、同じ `CorrectionPainter` に渡します。

この方式は issue #3 の PoC で決めました（方式1。medium の解像度で 30fps 前後）。

---

## 2. uniform とは

シェーダーは GPU の上で動くので、Dart の変数を直接読めません。
そこで、Dart から「補正タイプ」や「強度」などの値をシェーダーに渡すための入り口を用意します。これを **uniform** と呼びます。

シェーダー側では次のように宣言します。

```glsl
uniform float uStrength;  // 補正強度
```

Dart 側からは、**名前ではなく番号（index）で**値を設定します。

```dart
shader.setFloat(6, 0.8);  // 6番目の float（= uStrength）に 0.8 を入れる
```

### 番号の数え方

- 番号は、シェーダーで宣言した**順番**で決まります。
- `float` は1つ、`vec2`（float が2つの組）は2つ番号を使います。
- 画像を受け取る `sampler2D` は、float とは**別に** 0 から数えます。設定には `setImageSampler` を使います。

例：

```glsl
uniform vec2 uSize;        // 番号 0 と 1（x と y）
uniform float uType;       // 番号 2
uniform sampler2D uImage;  // sampler の番号 0
```

### なぜ並びが大事なのか

番号は宣言の順番で決まるので、**シェーダーの宣言の順番を入れ替えたり、途中に新しい uniform を挟んだりすると、番号がずれます**。
番号がずれても、エラーにはなりません。**値が別の uniform に入り、見た目がおかしくなるだけ**なので、原因に気づきにくいです。

このため、次のルールを守ります。

> **uniform は必ず一番後ろに足す。途中に挟まない。並びを入れ替えない。**

---

## 3. uniform の一覧

### 今あるもの（MVP）

| 番号 | 名前 | 型 | 入れる値 | 意味 |
| ---- | ---- | -- | -------- | ---- |
| 0, 1 | `uSize` | vec2 | 描画先の幅・高さ（論理ピクセル） | 画面のどこを描いているか計算するのに使う |
| 2, 3 | `uImageSize` | vec2 | **回転した後の**画像の幅・高さ | 画面いっぱいに表示するための切り抜き計算に使う |
| 4 | `uQuarterTurns` | float | 0〜3 | 画像を時計回りに何回90度回して表示するか |
| 5 | `uType` | float | 0 = P型、1 = D型、2 = T型 | 補正タイプ。`CorrectionType.index` と同じ並び |
| 6 | `uStrength` | float | 0.0〜1.0 | 補正強度。0.0 で補正なし、1.0 で最大 |
| sampler 0 | `uTexture` | sampler2D | 入力画像 | カメラのフレーム、または写真 |

### 追加機能のために予約しているもの

追加機能（Should）を作るときは、次の番号で**後ろに**足します。番号を先に決めておくことで、複数の人が同時に作業しても番号がぶつかりません。

| 番号 | 名前 | 型 | 入れる値 | 機能 | issue |
| ---- | ---- | -- | -------- | ---- | ----- |
| 7 | `uMode` | float | 0 = 補正、1 = 見え方体験 | F-11 見え方体験フィルター | #25 |
| 8 | `uSplit` | float | 0.0〜1.0 の境界の位置。負の値なら分割しない | F-10 Before/After スプリット | #24 |
| 9 | `uEdge` | float | 0 = オフ、1 = オン | F-13 輪郭強調 | #26 |
| 10 | `uMeat` | float | 0 = オフ、1 = オン | F-12 肉の焼き加減チェッカー | #27 |

> 予約した番号の機能を作らなかった場合でも、後ろの番号は変えません。
> 例えば `uMode` を作らずに `uSplit` を作るときは、`uMode` も宣言だけしておきます（番号 7 を空けたままにしない）。

---

## 4. Dart から使う

### 基本：`CorrectionPainter` を使う

ほとんどの場合、[`CorrectionPainter`](../lib/features/shader/services/correction_painter.dart) を `CustomPaint` に渡すだけで済みます。
uniform の番号を自分で書く必要はありません。

```dart
import 'package:color_correction/features/shader/services/correction_painter.dart';
import 'package:color_correction/features/shader/services/correction_shader.dart';
import 'package:color_correction/core/providers/correction_settings_provider.dart';

// 1. 起動時などに1回だけ、シェーダーを読み込む（時間がかかるので毎フレームはやらない）
final correctionShader = await CorrectionShader.load();

// 2. build の中で、画像と設定を渡して描く
CustomPaint(
  painter: CorrectionPainter(
    shader: correctionShader,
    image: frame,                                    // ui.Image
    settings: ref.watch(correctionSettingsProvider), // 補正タイプと強度
    quarterTurns: camera.sensorOrientation ~/ 90,    // 静止画なら 0（省略可）
  ),
)
```

- `image` が変わる（新しいフレームが来る）たびに、Flutter が描き直します。
- 補正タイプや強度を変えると、`ref.watch` によって build が呼ばれ、すぐに反映されます。

### `quarterTurns` に入れる値

カメラのセンサーは、スマホを縦に持っていても横向きの画像を出すことがほとんどです。
そのままでは横に倒れた映像になるので、シェーダーの中で回して正しい向きにします。

| 入力 | `quarterTurns` |
| ---- | -------------- |
| カメラのフレーム | `camera.sensorOrientation ~/ 90`（多くの Android の背面カメラは 90 なので 1） |
| 写真（向きを直した後） | `0` |

> アプリは縦持ちに固定する前提です。横持ちに対応する場合は、端末の向きも加味した計算が必要になります。

### 細かく制御したいとき：`CorrectionShader.apply`

`CustomPainter` を自分で書きたい場合や、`ImageFilter.shader` で使いたい場合は、[`CorrectionShader`](../lib/features/shader/services/correction_shader.dart) の `apply` を直接呼びます。

```dart
correctionShader.apply(
  size: size,
  image: frame,
  settings: settings,
  quarterTurns: 1,
);
canvas.drawRect(Offset.zero & size, Paint()..shader = correctionShader.shader);
```

uniform の番号は `CorrectionShader` の中の `_Uniform` クラスにまとめてあり、**外からは見えないようにしています**。
番号を知っているのはこのクラスだけなので、uniform を増やしても、使う側のコードを直す必要はありません。

---

## 5. シェーダーの中身

ファイル：[`lib/features/shader/shaders/correction.frag`](../lib/features/shader/shaders/correction.frag)

```
main()
 ├─ toTextureCoord() … 画面の座標を、入力画像のどこを読むかに変換する（切り抜きと回転）
 ├─ texture()        … 入力画像からその位置の色を読む
 ├─ correct()        … 色覚補正をかける（下の「色覚補正の仕組み」を参照）
 └─ fragColor        … 結果の色を出力する
```

### 画面いっぱいに表示する仕組み（切り抜き）

カメラ画像（例：縦長 480×720）と画面（例：縦長 1080×2400）は、縦横比が違います。
そのまま引き伸ばすと映像がゆがむので、**縦横比を保ったまま画面全体を覆うように拡大し、はみ出た部分を切ります**。
写真アプリの「画面いっぱいに表示」と同じ見え方です。

### 色覚補正（`correct()`）の仕組み

色覚補正には「**ダルトニゼーション**」という手法を使います。考え方は次の2段階です。

1. **シミュレーション**：その色が、P型・D型・T型の人にどう見えるかを計算する
2. **振り直し**：元の色とシミュレーション結果の差、つまり「**見えなくなった差分**」を、その人にも**見える成分**に足し直す

例えば P型の人は、赤と緑の違いが見えにくい一方で、黄と青の違いや明るさの違いは見えます。
そこで「赤と緑の違い」として失われた情報を、「黄と青の違い」に移し替えます。

`correct()` の中では、次の順に計算しています。

```
入力の色（sRGB）
 │ toLinear()            … 線形RGBにする（下の「sRGBと線形RGB」を参照）
 ▼
lin
 │ × simulationMatrix()  … その色覚での見え方を計算する
 ▼
lost = lin − 見え方       … 見えなくなった差分
 │ × shiftMatrix()       … 差分を、見える成分に振り直す
 ▼
lin + 振り直した差分
 │ toSrgb()              … sRGBに戻す
 ▼
補正後の色
 │ mix(入力の色, 補正後の色, 強度)  … 強度に応じて混ぜる
 ▼
出力
```

強度が 0 のときは、計算をせずに入力の色をそのまま返します。変換による小さな誤差も出ないので、「0% で元の映像と同じ」という要件（F-03）を確実に満たせます。

#### sRGB と線形RGB

画像の色の値（sRGB）は、人の目の感じ方に合わせて「暗い色ほど細かく」記録されていて、光の強さには比例していません。
色を足したり行列を掛けたりする計算は、光の強さに比例した値（**線形RGB**）で行う必要があります。
そのため、計算の前に `toLinear()` で変換し、最後に `toSrgb()` で戻しています。

#### シミュレーションの行列（`simulationMatrix`）

Machado, Oliveira & Fernandes (2009) "A Physiologically-based Model for Simulation of Color Vision Deficiency" の、**重さ 1.0**（最も強い）の行列を使っています。
P型・D型・T型の3種類がそろっていて、3×3 の行列を1回掛けるだけで済むので、GPU で軽く計算できます。

#### 振り直しの行列（`shiftMatrix`）と、係数の決め方

振り直しの考え方は、Fidaner et al. (2005) の「誤差の振り直し」をもとにしています。
ただし、元の論文の係数（赤の誤差を緑と青の**両方に足す**）を試したところ、**ペルソナが見分けにくい赤茶色と青紫の差が、補正するとむしろ縮みました**。
赤茶色も青紫も「赤の成分が見えなくなる」向きの誤差を持っているので、両方とも青寄りに動いて近づいてしまうためです。

そこで、係数を次の方法で決め直しました。

1. ランダムな色 600 色から、「普通に見ると違う色（色差 25 以上）なのに、その色覚ではほぼ同じに見える（色差 8 未満）」組を 300 組集める
2. 係数を −1.0〜1.0 の範囲で 0.1 ずつ変え、補正後にその色覚で見たときの色差がどれだけ広がるかを調べる
3. ペルソナの色の組が悪化しないこと、補正で色が変わりすぎないこと（色の変化量の平均が 35 以下）を条件に、最も差が広がる係数を選ぶ

結果は次のとおりです（色差は CIE L\*a\*b\* での距離 ΔE。数字が大きいほど見分けやすい）。

| 型 | 振り直し方 | 混同しやすい組の色差（平均） | ペルソナの赤茶色と青紫の色差 |
| -- | ---------- | ---------------------------- | ---------------------------- |
| P型 | 赤の誤差 → 緑に +0.5、青に −0.5 | 5.3 → 42.2 | 83.5 → 99.5 |
| D型 | 赤の誤差 → 緑に +0.6、青に −0.9 | 5.4 → 42.7 | 92.0 → 92.4 |
| T型 | 青の誤差 → 赤に −0.9、緑に +0.8 | 6.2 → 21.6 | （対象外） |
| （参考）P型・元の論文の係数 | 赤の誤差 → 緑に +0.7、青に +0.7 | 5.3 → 28.4 | 83.5 → 56.8（悪化） |

P型・D型は「赤寄りの色は黄色寄りに、緑寄りの色は青寄りに」動きます。T型は「青寄りの色は赤寄りに」動きます。
これらは計算上の結果です。実際の見え方は、ペルソナに実機で確かめてもらって調整します（issue #23）。

#### 行列の書き方の注意

GLSL の `mat3(...)` は、値を**列ごとに**並べる決まりです。
このファイルでは、読みやすさのために「1行目が R、2行目が G、3行目が B の計算式」になるよう**行ごとに**書き、`rgb * M` の順で掛けています。
この順で掛けると、行ごとに書いた行列をそのまま掛けたのと同じ結果になります。行列を書き換えるときは、`M * rgb` にしないよう注意してください。

#### テスト

[`test/features/shader/correction_shader_test.dart`](../test/features/shader/correction_shader_test.dart) で、シェーダーで実際に描いた色を使って次を確かめています。

- 強度 0 で、入力の色がそのまま出る
- 型ごとに、補正前はほぼ同じに見える2色（色差 10 未満）が、補正後は見分けられる（色差 15 以上）
- ペルソナの赤茶色と青紫の差が、補正で広がる
- 強度 0.5 で、元の色と強度 1 の色のちょうど間になる

係数を変えたときは、必ずこのテストを実行してください。

## 6. uniform を追加する手順

例として、F-10 の `uSplit`（番号 8）を足す場合です。

**1. シェーダーに宣言を足す（一番後ろ、`uTexture` より前でよい）**

番号 7 の `uMode` がまだなければ、先に宣言だけしておきます。

```glsl
uniform float uStrength;     // 6
uniform float uMode;         // 7
uniform float uSplit;        // 8 ← 追加
```

> `sampler2D` は float と別に数えるので、`uTexture` の前に書いても後に書いても float の番号には影響しません。
> 見やすさのため、このファイルでは float を先に、sampler を最後に書いています。

**2. `CorrectionShader` の `_Uniform` に番号を足す**

```dart
static const mode = 7;  // uMode
static const split = 8; // uSplit
```

**3. `apply` に引数を足して、`setFloat` で値を入れる**

```dart
void apply({..., double split = -1}) {
  shader
    ...
    ..setFloat(_Uniform.mode, 0)
    ..setFloat(_Uniform.split, split);
}
```

引数に初期値を付けておけば、今 `apply` を呼んでいるコードは直さずに済みます。

**4. この資料の表を更新する**

「予約しているもの」の行を「今あるもの」に移します。

**5. テストを実行する**

```powershell
flutter test test/features/shader
```

---

## 7. 新しいシェーダーファイルを作るとき

シェーダーファイルは、`pubspec.yaml` に登録しないと読み込めません。

```yaml
flutter:
  shaders:
    - lib/features/shader/shaders/correction.frag
```

`FragmentProgram.fromAsset` に渡すパスは、ここに書いたパスと**完全に同じ**にします。

---

## 8. 困ったとき

| 症状 | よくある原因 |
| ---- | ------------ |
| 画面が真っ黒・真っ白になる | uniform の番号がずれている。シェーダーの宣言の順番と `_Uniform` の番号が合っているか確認する |
| `Exception: Asset not found` などのエラーになる | `pubspec.yaml` の `shaders:` に登録していない、またはパスが違う |
| シェーダーを直したのに反映されない | ホットリロード（`r`）では反映されないことがある。ホットリスタート（`R`）か、アプリを起動し直す |
| 映像が横に倒れている・上下が逆 | `quarterTurns` の値が合っていない。カメラは `sensorOrientation ~/ 90`、写真は `0` |
| 映像がゆがむ | `uImageSize` に**回転する前**のサイズを入れている。`apply` を使えば自動で正しく入る |
| シェーダーのコンパイルエラーが出る | `flutter run` のログに行番号が出る。GLSL は `float` と `int` を自動で変換しないので、`1` ではなく `1.0` と書く |

---

## 9. 補足：方式2への差し替え

性能が足りなくなったときは、`ImageFilter.shader` でカメラのプレビューに直接シェーダーをかける方式（方式2）に差し替えられるようにしています（issue #3 参照）。
方式2では、**最初の uniform が `vec2` の描画サイズ、最初の sampler が入力画像**でなければならない決まりがあります。
`correction.frag` はこの決まりに合わせているので、uniform の先頭（`uSize`）と `uTexture` の位置は変えないでください。
