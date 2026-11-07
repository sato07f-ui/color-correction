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
