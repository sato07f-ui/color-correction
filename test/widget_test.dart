import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:color_correction/app.dart';
import 'package:color_correction/features/presentation/screens/camera_screen.dart';

void main() {
  testWidgets('起動するとリアルタイムカメラ画面が開く', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // カメラ画面は AppBar を出さないので、画面そのものがあるかで確かめる
    expect(find.byType(CameraScreen), findsOneWidget);
  });
}
