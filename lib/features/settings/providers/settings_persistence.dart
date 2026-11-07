import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/correction_settings.dart';
import '../../../core/models/font_size_option.dart';
import '../../../core/providers/correction_settings_provider.dart';
import '../services/settings_storage_service.dart';
import 'font_size_provider.dart';

/// 設定を端末に保存する ProviderContainer を作る。
///
/// 対象は補正タイプと強度（F-06）、文字サイズ。
/// - 起動時に、前回保存した値を読み込んで Provider の初期値にする
/// - 以後、Provider の値が変わるたびに保存する
///
/// main.dart で `UncontrolledProviderScope` に渡して使う。
Future<ProviderContainer> createPersistentContainer({
  SettingsStorageService? storage,
}) async {
  final service = storage ?? SettingsStorageService();

  var initial = const CorrectionSettings();
  var initialFontSize = FontSizeOption.medium;
  try {
    initial = await service.loadSettings();
    initialFontSize = await service.loadFontSize();
  } catch (error) {
    // 読み込めなくてもアプリは初期値で起動する
    debugPrint('設定の読み込みに失敗しました: $error');
  }

  final container = ProviderContainer(
    overrides: [
      correctionSettingsProvider.overrideWith(
        (ref) => CorrectionSettingsNotifier(initial),
      ),
      fontSizeProvider.overrideWith((ref) => FontSizeNotifier(initialFontSize)),
    ],
  );

  container.listen<CorrectionSettings>(correctionSettingsProvider, (
    previous,
    next,
  ) {
    service.saveSettings(next).catchError((Object error) {
      debugPrint('補正設定の保存に失敗しました: $error');
    });
  });

  container.listen<FontSizeOption>(fontSizeProvider, (previous, next) {
    service.saveFontSize(next).catchError((Object error) {
      debugPrint('文字サイズの保存に失敗しました: $error');
    });
  });

  return container;
}
