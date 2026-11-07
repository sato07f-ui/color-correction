import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/correction_settings.dart';
import '../../../core/models/font_size_option.dart';

class SettingsStorageService {
  Future<CorrectionSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final typeIndex = prefs.getInt(AppConstants.keyCorrectionType);
    final strength = prefs.getDouble(AppConstants.keyCorrectionStrength);

    return CorrectionSettings(
      type: typeIndex != null && typeIndex < CorrectionType.values.length
          ? CorrectionType.values[typeIndex]
          : CorrectionType.protan,
      strength: strength ?? 1.0,
    );
  }

  Future<void> saveSettings(CorrectionSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyCorrectionType, settings.type.index);
    await prefs.setDouble(
      AppConstants.keyCorrectionStrength,
      settings.strength,
    );
  }

  Future<FontSizeOption> loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(AppConstants.keyFontSize);
    return index != null && index >= 0 && index < FontSizeOption.values.length
        ? FontSizeOption.values[index]
        : FontSizeOption.medium;
  }

  Future<void> saveFontSize(FontSizeOption fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyFontSize, fontSize.index);
  }

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(AppConstants.keyThemeMode);
    return index != null && index >= 0 && index < ThemeMode.values.length
        ? ThemeMode.values[index]
        : ThemeMode.system;
  }

  Future<void> saveThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyThemeMode, themeMode.index);
  }

  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyCorrectionType);
    await prefs.remove(AppConstants.keyCorrectionStrength);
    await prefs.remove(AppConstants.keyFontSize);
    await prefs.remove(AppConstants.keyThemeMode);
  }
}
