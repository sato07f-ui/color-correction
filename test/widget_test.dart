import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:color_correction/app.dart';

void main() {
  testWidgets('起動するとリアルタイムカメラ画面が開く', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    expect(find.text('リアルタイムカメラ'), findsOneWidget);
  });
}
