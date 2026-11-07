import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'color/color_names.dart';
import 'features/settings/providers/settings_persistence.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ColorNames.load();
  // 前回の補正タイプと強度を読み込み、変更のたびに保存する（F-06）
  final container = await createPersistentContainer();

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}
