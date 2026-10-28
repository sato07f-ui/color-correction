# カラコレ

色覚に特性のある人が、身の回りの色をリアルタイムで見分けやすくする Android アプリです。
技育CAMP2026ハッカソン vol.6 にチーム「31日こぶしでremember」で出場します。

機能の範囲と優先度は [要件定義書.md](要件定義書.md) を参照してください。

## 必要なもの

| ツール | 用途 | 備考 |
| --- | --- | --- |
| Git | ソース管理 | |
| Flutter SDK 3.47 系（stable） | アプリ開発 | Dart 3.13 以上。`flutter --version` で確認 |
| Android Studio | Android SDK、エミュレータ | 初回起動時のセットアップで SDK を入れる |
| VS Code ＋ Flutter 拡張機能 | エディタ | Android Studio で開発してもよい |
| cloudflared | スマホのブラウザで Web 版を確認する | Web 確認をする人だけ必要 |

## セットアップ

```powershell
git clone <このリポジトリのURL>
cd color-correction
flutter pub get
flutter doctor
```

`flutter doctor` で Flutter と Android toolchain に ✓ が付けば準備完了です。
✗ が出たら、表示されたメッセージに従って直してください（Android ライセンスの同意は `flutter doctor --android-licenses`）。

## 動作確認の方法

確認方法は3つあり、それぞれ確認できる範囲が違います。
**本番は Android アプリなので、最終確認は必ず Android 実機で行ってください。**

| 方法 | 向いている確認 | できないこと |
| --- | --- | --- |
| Android 実機 | すべて（本番と同じ環境） | 実機がないメンバーは使えない |
| Android エミュレータ | 画面遷移、ロジック、PC の Web カメラを使ったカメラ動作 | 実機と同じ性能・色の確認 |
| Web ＋ Cloudflare Tunnel | スマホ画面でのレイアウトや UI の見た目、操作感 | リアルタイム補正（カメラ映像のフレーム取得）、振動、性能の確認 |

### 1. Android 実機で確認する

1. スマホで開発者向けオプションを有効にします（設定 → デバイス情報 → ビルド番号を7回タップ）。
2. 開発者向けオプションで **USB デバッグ** をオンにします。
3. USB ケーブルで PC につなぎ、スマホに出る許可ダイアログで「許可」を押します。
4. 認識されたか確認して、起動します。

   ```powershell
   flutter devices
   flutter run
   ```

   複数の端末がつながっている場合は `flutter run -d <デバイスID>` で指定します。

起動中のターミナルで `r` を押すとホットリロード（コードの変更をすぐ反映）、`R` でホットリスタート、`q` で終了です。

ケーブルなしで接続したい場合は、Android 11 以上なら「ワイヤレス デバッグ」が使えます。
Android Studio の Device Manager から QR コードでペアリングするのが簡単です。

### 2. Android エミュレータで確認する

1. Android Studio の **Device Manager** で仮想デバイスを作成します。
2. カメラを試す場合は、仮想デバイスの設定（Advanced Settings）で Back camera を **Webcam0** にします。PC の Web カメラが背面カメラとして使えます。
3. エミュレータを起動してから `flutter run` を実行します。

### 3. Web 版をスマホのブラウザで確認する（Cloudflare Tunnel）

PC で動かした Web 版を、Cloudflare Tunnel で一時的にインターネットに公開し、スマホのブラウザで開きます。
同じ Wi-Fi にいなくても確認でき、HTTPS で開けるのでブラウザからカメラも使えます。

#### 初回だけ：cloudflared のインストール

```powershell
winget install --id Cloudflare.cloudflared
```

インストール後にターミナルを開き直し、`cloudflared --version` で確認します。Cloudflare のアカウントは不要です。

#### 毎回の手順

ターミナルを2つ使います。

**ターミナル1：Web 版を起動する**

```powershell
flutter run -d web-server
```

[web_dev_config.yaml](web_dev_config.yaml) の設定で、`http://localhost:8080` で起動します。
`[WebDevServer] Loaded configuration from web_dev_config.yaml` と表示されれば設定が読み込まれています。

**ターミナル2：トンネルを開く**

```powershell
cloudflared tunnel --url http://localhost:8080
```

しばらくすると `https://xxxx-xxxx.trycloudflare.com` という URL が表示されます。この URL をスマホのブラウザ（Chrome）で開いてください。

コードを変更したら、ターミナル1で `r` を押します。スマホに反映されない場合は、ブラウザでページを再読み込みしてください。

#### 注意

- **URL を知っている人は誰でもアクセスできます。** URL はチーム内だけで共有し、SNS などに貼らないでください。
- 確認が終わったら、両方のターミナルで `Ctrl + C` を押して止めてください。
- URL は起動するたびに変わります。
- ポート 8080 がほかのアプリで使われている場合は、[web_dev_config.yaml](web_dev_config.yaml) の `port` を変え、cloudflared の URL も同じ番号にしてください。
- Web 版では動かない機能があります（カメラ映像のフレーム取得によるリアルタイム補正、振動など）。これらは Android 実機かエミュレータで確認してください。

## APK を作って配る

実機をつなげないメンバーに試してもらうときは、APK を作って渡します。

```powershell
flutter build apk
```

`build/app/outputs/flutter-apk/app-release.apk` ができるので、スマホに転送してインストールします。
スマホ側で「提供元不明のアプリ」のインストールを許可する必要があります。

## よく使うコマンド

| コマンド | 内容 |
| --- | --- |
| `flutter pub get` | 依存パッケージを取得する |
| `flutter pub add <パッケージ名>` | パッケージを追加する |
| `flutter devices` | 接続中の端末を一覧表示する |
| `flutter run` | アプリを起動する |
| `flutter analyze` | 静的解析（Lint）をかける |
| `flutter test` | テストを実行する |
| `dart format .` | コードを整形する |

## ディレクトリ構成

```
color-correction/
├── lib/                  アプリ本体（Dart コード）
├── test/                 テストコード
├── android/              Android 向けの設定（権限、アプリ ID など）
├── web/                  Web 版の設定
├── pubspec.yaml          依存パッケージとアセットの設定
├── web_dev_config.yaml   Web 開発サーバーの設定（Cloudflare Tunnel 用にポートを固定）
└── 要件定義書.md          要件定義書
```

`ios/`、`macos/`、`linux/`、`windows/` は今回の対象外です。
