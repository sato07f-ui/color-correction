// StateNotifier は Riverpod 3 で legacy.dart に移った
import 'package:flutter_riverpod/legacy.dart';

import '../models/correction_settings.dart';

/// 補正設定を管理する Notifier
class CorrectionSettingsNotifier extends StateNotifier<CorrectionSettings> {
  /// [initial] は起動時に端末から読み込んだ設定（F-06）。省略すると初期値で始まる
  CorrectionSettingsNotifier([super.initial = const CorrectionSettings()]);

  /// 補正タイプの変更
  void setType(CorrectionType type) {
    state = state.copyWith(type: type);
  }

  /// 補正強度の変更 (0.0 〜 1.0 にクランプ)
  void setStrength(double strength) {
    state = state.copyWith(strength: strength.clamp(0.0, 1.0));
  }

  /// 設定のリセット
  void reset() {
    state = const CorrectionSettings();
  }
}

/// 全体で共有する Provider
final correctionSettingsProvider =
    StateNotifierProvider<CorrectionSettingsNotifier, CorrectionSettings>((ref) {
  return CorrectionSettingsNotifier();
});
