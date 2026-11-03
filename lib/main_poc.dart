import 'package:flutter/material.dart';

import 'poc/camera_stream_poc_page.dart';

/// issue #3 PoC の起動ファイル。`flutter run -t lib/main_poc.dart` で起動する。
/// アプリ本体（main.dart）には影響しない。
void main() {
  runApp(
    const MaterialApp(
      title: 'カラコレ PoC',
      debugShowCheckedModeBanner: false,
      home: CameraStreamPocPage(),
    ),
  );
}
