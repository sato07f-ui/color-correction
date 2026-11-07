import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'color/color_names.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ColorNames.load();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

