import 'package:color_correction/core/constants/app_constants.dart';
import 'package:color_correction/core/models/correction_settings.dart';
import 'package:color_correction/core/models/font_size_option.dart';
import 'package:color_correction/core/providers/correction_settings_provider.dart';
import 'package:color_correction/features/settings/providers/font_size_provider.dart';
import 'package:color_correction/features/settings/providers/settings_persistence.dart';
import 'package:color_correction/features/settings/providers/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('保存された設定がないときは、初期値（P型・100%）で始まる', () async {
    SharedPreferences.setMockInitialValues({});

    final container = await createPersistentContainer();
    addTearDown(container.dispose);

    final settings = container.read(correctionSettingsProvider);
    expect(settings.type, CorrectionType.protan);
    expect(settings.strength, 1.0);
  });

  test('前回保存した設定を読み込んで始まる', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyCorrectionType: CorrectionType.deutan.index,
      AppConstants.keyCorrectionStrength: 0.4,
    });

    final container = await createPersistentContainer();
    addTearDown(container.dispose);

    final settings = container.read(correctionSettingsProvider);
    expect(settings.type, CorrectionType.deutan);
    expect(settings.strength, 0.4);
  });

  test('タイプと強度を変えると保存され、開き直すと復元される', () async {
    SharedPreferences.setMockInitialValues({});

    // 1回目の起動：設定を変える
    final first = await createPersistentContainer();
    first.read(correctionSettingsProvider.notifier)
      ..setType(CorrectionType.tritan)
      ..setStrength(0.25);
    await pumpEventQueue(); // 保存（非同期）が終わるのを待つ
    first.dispose();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(AppConstants.keyCorrectionType),
      CorrectionType.tritan.index,
    );
    expect(prefs.getDouble(AppConstants.keyCorrectionStrength), 0.25);

    // 2回目の起動：変えた設定で始まる
    final second = await createPersistentContainer();
    addTearDown(second.dispose);

    final settings = second.read(correctionSettingsProvider);
    expect(settings.type, CorrectionType.tritan);
    expect(settings.strength, 0.25);
  });

  test('リセットすると、初期値が保存される', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyCorrectionType: CorrectionType.deutan.index,
      AppConstants.keyCorrectionStrength: 0.4,
    });

    final container = await createPersistentContainer();
    addTearDown(container.dispose);
    container.read(correctionSettingsProvider.notifier).reset();
    await pumpEventQueue();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(AppConstants.keyCorrectionType),
      CorrectionType.protan.index,
    );
    expect(prefs.getDouble(AppConstants.keyCorrectionStrength), 1.0);
  });

  test('文字サイズは、保存がなければ「中」で始まり、変えると保存・復元される', () async {
    SharedPreferences.setMockInitialValues({});

    final first = await createPersistentContainer();
    expect(first.read(fontSizeProvider), FontSizeOption.medium);
    first.read(fontSizeProvider.notifier).setFontSize(FontSizeOption.large);
    await pumpEventQueue();
    first.dispose();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AppConstants.keyFontSize), FontSizeOption.large.index);

    final second = await createPersistentContainer();
    addTearDown(second.dispose);
    expect(second.read(fontSizeProvider), FontSizeOption.large);
  });
  test('テーマは、保存がなければ端末の設定に合わせ、変えると保存・復元される', () async {
    SharedPreferences.setMockInitialValues({});

    final first = await createPersistentContainer();
    expect(first.read(themeModeProvider), ThemeMode.system);
    first.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
    await pumpEventQueue();
    first.dispose();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AppConstants.keyThemeMode), ThemeMode.dark.index);

    final second = await createPersistentContainer();
    addTearDown(second.dispose);
    expect(second.read(themeModeProvider), ThemeMode.dark);
  });
}
