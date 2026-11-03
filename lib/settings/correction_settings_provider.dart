flimport 'package:flutter_riverpod/flutter_riverpod.dart';

/// 補正タイプの定義
enum CorrectionType {
  protan('P型（1型・赤）'),
  deutan('D型（2型・緑）'),
  tritan('T型（3型・青）');

  final String displayName;
  const CorrectionType(this.displayName);
}

/// 補正設定のデータモデル
class CorrectionSettings {
  final CorrectionType type;
  final double strength; // 0.0 〜 1.0

  const CorrectionSettings({
    this.type = CorrectionType.protan,
    this.strength = 1.0,
  });

  CorrectionSettings copyWith({
    CorrectionType? type,
    double? strength,
  }) {
    return CorrectionSettings(
      type: type ?? this.type,
      strength: strength ?? this.strength,
    );
  }
}

/// 補正設定を管理する Notifier
class CorrectionSettingsNotifier extends StateNotifier<CorrectionSettings> {
  CorrectionSettingsNotifier() : super(const CorrectionSettings());

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