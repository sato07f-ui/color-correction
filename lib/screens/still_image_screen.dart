import 'package:flutter/material.dart';

class StillImageScreen extends StatefulWidget {
  const StillImageScreen({super.key});

  @override
  State<StillImageScreen> createState() => _StillImageScreenState();
}

class _StillImageScreenState extends State<StillImageScreen> {
  bool _hasImage = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 写真選択エリア
        Expanded(
          flex: 4,
          child: Container(
            width: double.infinity,
            color: Colors.grey.shade200,
            child: Center(
              child: _hasImage
                  ? const Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.image, size: 120, color: Colors.blueGrey),
                        Text('選択された写真', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _hasImage = true;
                        });
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text('写真フォルダから選択'),
                    ),
            ),
          ),
        ),

        // 下部: カメラ画面と同様の色補正・調整パネルエリア
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '写真補正パネル',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text('カメラ画面と同じ色調整（RGB・HSL・FRAME）をここに適用します。', style: TextStyle(color: Colors.black54)),
                const Spacer(),
                if (_hasImage)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _hasImage = false),
                    icon: const Icon(Icons.refresh),
                    label: const Text('別の写真を選ぶ'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}