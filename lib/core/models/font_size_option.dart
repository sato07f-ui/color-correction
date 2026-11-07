/// 文字サイズの設定。
///
/// [scale] は端末の文字サイズ設定に掛ける倍率。アプリ全体の文字に反映する
enum FontSizeOption {
  small('小', 0.85),
  medium('中', 1.0),
  large('大', 1.2);

  final String displayName;
  final double scale;
  const FontSizeOption(this.displayName, this.scale);
}
