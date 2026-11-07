import 'package:color_correction/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ダークテーマの文字は明るい色、ライトテーマの文字は暗い色になる', () {
    final darkText = AppTheme.dark.textTheme.bodyMedium!.color!;
    final lightText = AppTheme.light.textTheme.bodyMedium!.color!;

    expect(darkText.computeLuminance(), greaterThan(0.5));
    expect(lightText.computeLuminance(), lessThan(0.5));
  });
}
