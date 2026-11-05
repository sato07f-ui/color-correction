
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _fontSize = '中';
  bool _animation = true;
  String _colorFormat = 'HEX';
  bool _colorPicker = true;
  bool _sound = false;

  @override
  Widget build(BuildContext context) {
    final currentTheme =
        Theme.of(context).brightness == Brightness.light
            ? 'ライト'
            : 'ダーク';

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          title: const Text('テーマ'),
          subtitle: Text(currentTheme),
          trailing: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ライト', label: Text('ライト')),
              ButtonSegment(value: 'ダーク', label: Text('ダーク')),
            ],
            selected: {currentTheme},
            onSelectionChanged: (val) {
              widget.onThemeChanged(
                val.first == 'ライト'
                    ? ThemeMode.light
                    : ThemeMode.dark,
              );
            },
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('文字サイズ'),
          trailing: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '小', label: Text('小')),
              ButtonSegment(value: '中', label: Text('中')),
              ButtonSegment(value: '大', label: Text('大')),
            ],
            selected: {_fontSize},
            onSelectionChanged: (val) =>
                setState(() => _fontSize = val.first),
          ),
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('アニメーション'),
          value: _animation,
          onChanged: (val) => setState(() => _animation = val),
        ),
        const Divider(),
        ListTile(
          title: const Text('色コード形式'),
          trailing: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'RGB', label: Text('RGB')),
              ButtonSegment(value: 'HEX', label: Text('HEX')),
            ],
            selected: {_colorFormat},
            onSelectionChanged: (val) =>
                setState(() => _colorFormat = val.first),
          ),
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('カラーピッカー'),
          value: _colorPicker,
          onChanged: (val) => setState(() => _colorPicker = val),
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('操作音'),
          value: _sound,
          onChanged: (val) => setState(() => _sound = val),
        ),
      ],
    );
  }
}
