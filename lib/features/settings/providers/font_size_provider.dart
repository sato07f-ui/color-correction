// StateNotifier は Riverpod 3 で legacy.dart に移った
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/font_size_option.dart';

/// 文字サイズの設定を管理する Notifier
class FontSizeNotifier extends StateNotifier<FontSizeOption> {
  /// [initial] は起動時に端末から読み込んだ設定。省略すると「中」で始まる
  FontSizeNotifier([super.initial = FontSizeOption.medium]);

  void setFontSize(FontSizeOption fontSize) {
    state = fontSize;
  }
}

/// 全体で共有する Provider。app.dart でアプリ全体の文字の倍率に使う
final fontSizeProvider =
    StateNotifierProvider<FontSizeNotifier, FontSizeOption>((ref) {
      return FontSizeNotifier();
    });
