import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // アプリ共通カラー
  static const Color primary = Color(0xFF386493);
  static const Color background = Color(0xFFEDF1FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF252A32);

  // ライトテーマ
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );

    return _buildTheme(colorScheme);
  }

  // ダークテーマ
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    );

    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // 日本語フォント。文字色はテーマの明るさに合わせる
      // （ダークテーマで ThemeData.light() の文字を使うと、暗い背景に暗い文字になる）
      textTheme:
          (colorScheme.brightness == Brightness.dark
                  ? ThemeData.dark()
                  : ThemeData.light())
              .textTheme
              .apply(fontFamily: GoogleFonts.notoSansJp().fontFamily),

      // 背景
      scaffoldBackgroundColor: colorScheme.brightness == Brightness.light
          ? background
          : colorScheme.surface,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),

      // カード
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ボタン
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // ナビゲーションバー
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.primaryContainer,
      ),
    );
  }
}

// 共通の余白
class AppSpacing {
  static const double small = 8;
  static const double medium = 16;
  static const double large = 24;
}

// 共通の角丸
class AppRadius {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 20;
}
