import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/settings/providers/font_size_provider.dart';
import 'features/settings/providers/theme_mode_provider.dart';
import 'theme/app_theme.dart';
import 'features/presentation/screens/camera_screen.dart';
import 'features/presentation/screens/settings_screen.dart';
import 'features/presentation/screens/still_image_screen.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Color Correction App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // テーマは Provider で持ち、端末に保存する
      themeMode: ref.watch(themeModeProvider),
      // 設定画面の文字サイズを、アプリ全体の文字に反映する
      builder: (context, child) => Consumer(
        builder: (context, ref, _) {
          final scale = ref.watch(fontSizeProvider).scale;
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              // 端末の文字サイズ設定に、アプリの倍率を掛ける
              textScaler: TextScaler.linear(
                mediaQuery.textScaler.scale(1) * scale,
              ),
            ),
            child: child!,
          );
        },
      ),
      home: MainNavigationScreen(
        onThemeChanged: ref.read(themeModeProvider.notifier).setThemeMode,
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;

  const MainNavigationScreen({super.key, required this.onThemeChanged});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<String> _titles = const ['リアルタイムカメラ', '静止画モード', '設定'];

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const CameraScreen(),
      const StillImageScreen(),
      SettingsScreen(onThemeChanged: widget.onThemeChanged),
    ];

    return Scaffold(
      // カメラ画面は映像を広く見せるため、AppBar を出さない
      appBar: _currentIndex == 0
          ? null
          : AppBar(title: Text(_titles[_currentIndex]), elevation: 1),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slideAnimation, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: screens[_currentIndex],
        ),
      ),
      // 手書き設計図の下部切り替えバー
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'リアルタイム',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_outlined),
            selectedIcon: Icon(Icons.photo),
            label: '静止画',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
