import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/font_size_option.dart';
import '../../settings/providers/font_size_provider.dart';

class SettingsScreen extends ConsumerWidget {
  final ValueChanged<ThemeMode> onThemeChanged;

  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = Theme.of(context).brightness == Brightness.light
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
              onThemeChanged(
                val.first == 'ライト' ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('文字サイズ'),
          trailing: SegmentedButton<FontSizeOption>(
            segments: [
              for (final option in FontSizeOption.values)
                ButtonSegment(value: option, label: Text(option.displayName)),
            ],
            selected: {ref.watch(fontSizeProvider)},
            onSelectionChanged: (val) =>
                ref.read(fontSizeProvider.notifier).setFontSize(val.first),
          ),
        ),
      ],
    );
  }
}
