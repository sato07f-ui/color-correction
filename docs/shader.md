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
 ├─ correct()        … 色覚補正をかける ← issue #20〜#22 で実装する
 └─ fragColor        … 結果の色を出力する
```

### 画面いっぱいに表示する仕組み（切り抜き）

カメラ画像（例：縦長 480×720）と画面（例：縦長 1080×2400）は、縦横比が違います。
そのまま引き伸ばすと映像がゆがむので、**縦横比を保ったまま画面全体を覆うように拡大し、はみ出た部分を切ります**。
写真アプリの「画面いっぱいに表示」と同じ見え方です。

### 今の `correct()` について

いまは**入力の色をそのまま返すだけ**です。補正の中身（ダルトニゼーション）は issue #20〜#22 で実装します。

また、`main()` の最後に次の処理があります。

```glsl
if (uType < -1.0) {
  result = vec3(uStrength);
}
```

`uType` は 0〜2 なので、この処理は**実際には実行されません**。
シェーダーのコンパイラは「使われていない uniform」を消してしまうことがあり、消されると番号がずれます。
補正を実装するまでの間、`uType` と `uStrength` が消されないようにするための処理です。`correct()` の中で両方を使うようになったら削除して構いません。

---

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
