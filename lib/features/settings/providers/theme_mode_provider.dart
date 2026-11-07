import 'package:flutter/material.dart';
// StateNotifier は Riverpod 3 で legacy.dart に移った
import 'package:flutter_riverpod/legacy.dart';

/// テーマ（ライト・ダーク）の設定を管理する Notifier
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  /// [initial] は起動時に端末から読み込んだ設定。省略すると端末の設定に合わせる
  ThemeModeNotifier([super.initial = ThemeMode.system]);

  void setThemeMode(ThemeMode themeMode) {
    state = themeMode;
  }
}

/// 全体で共有する Provider。app.dart で MaterialApp のテーマに使う
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});
