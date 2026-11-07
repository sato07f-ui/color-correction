import 'package:color_correction/app.dart';
import 'package:color_correction/core/models/font_size_option.dart';
import 'package:color_correction/features/settings/providers/font_size_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('文字サイズの設定が、アプリ全体の文字の倍率に反映される', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );

    double scaleOfNavigationLabel() =>
        MediaQuery.textScalerOf(tester.element(find.text('リアルタイム'))).scale(1);

    expect(scaleOfNavigationLabel(), 1.0);

    container.read(fontSizeProvider.notifier).setFontSize(FontSizeOption.large);
    await tester.pump();
    expect(scaleOfNavigationLabel(), FontSizeOption.large.scale);

    container.read(fontSizeProvider.notifier).setFontSize(FontSizeOption.small);
    await tester.pump();
    expect(scaleOfNavigationLabel(), FontSizeOption.small.scale);
  });
}
