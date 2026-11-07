import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/correction_settings.dart';
import '../../../core/providers/correction_settings_provider.dart';
import '../services/settings_storage_service.dart';

/// 補正設定を端末に保存する ProviderContainer を作る（F-06）。
///
/// - 起動時に、前回保存した補正タイプと強度を読み込んで Provider の初期値にする
/// - 以後、Provider の値が変わるたびに保存する
///
/// main.dart で `UncontrolledProviderScope` に渡して使う。
Future<ProviderContainer> createPersistentContainer({
  SettingsStorageService? storage,
}) async {
  final service = storage ?? SettingsStorageService();

  var initial = const CorrectionSettings();
  try {
    initial = await service.loadSettings();
  } catch (error) {
    // 読み込めなくてもアプリは初期値で起動する
    debugPrint('補正設定の読み込みに失敗しました: $error');
  }

  final container = ProviderContainer(
    overrides: [
      correctionSettingsProvider.overrideWith(
        (ref) => CorrectionSettingsNotifier(initial),
      ),
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

  return container;
}
