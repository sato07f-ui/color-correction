import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/correction_settings.dart';

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
    await prefs.setDouble(AppConstants.keyCorrectionStrength, settings.strength);
  }

  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyCorrectionType);
    await prefs.remove(AppConstants.keyCorrectionStrength);
  }
}