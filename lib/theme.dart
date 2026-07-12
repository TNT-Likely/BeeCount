import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'styles/tokens.dart';

class BeeTheme {
  // Brand colors - Light Mode
  static const Color honeyGold = Color(0xFFF8C91C); // 主色（亮色模式）
  static const Color hiveBrown = Color(0xFF8D6E63); // 辅助色
  static const Color energyOrange = Color(0xFFEF6C00); // 点缀色
  static const Color paperIvory = Color(0xFFFFF8E1); // 背景
  static const Color textDark = Color(0xFF333333); // 文字

  // Brand colors - Dark Mode ⭐ 改为与亮色模式相同（不减弱）
  static const Color honeyGoldDark = honeyGold; // 主色（暗黑模式 - 使用亮色）
  static const Color hiveBrownDark = hiveBrown; // 辅助色（暗黑模式 - 使用亮色）
  static const Color energyOrangeDark = energyOrange; // 点缀色（暗黑模式 - 使用亮色）

  static ThemeData lightTheme({TargetPlatform? platform}) {
    final base = ThemeData.light();
    final pf = platform ?? defaultTargetPlatform;
    final isIOS = pf == TargetPlatform.iOS || pf == TargetPlatform.macOS;
    final adjustedTextTheme =
        BeeTypography.buildBase(base.textTheme, isIOS: isIOS)
            .apply(bodyColor: textDark, displayColor: textDark);

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: honeyGold,
        secondary: energyOrange,
        surface: Colors.white,
      ),
      primaryColor: honeyGold,
      scaffoldBackgroundColor: paperIvory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0.0,
        centerTitle: true,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: honeyGold,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: energyOrange,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        backgroundColor: Colors.transparent, // 悬浮胶囊样式，外层透明
        elevation: 0,
      ),
      textTheme: adjustedTextTheme,
    );
  }

  static ThemeData darkTheme({TargetPlatform? platform}) {
    final base = ThemeData.dark();
    final pf = platform ?? defaultTargetPlatform;
    final isIOS = pf == TargetPlatform.iOS || pf == TargetPlatform.macOS;
    final adjusted = BeeTypography.buildBase(base.textTheme, isIOS: isIOS)
        .apply(bodyColor: Colors.white, displayColor: Colors.white);

    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: honeyGoldDark, // ⭐ 主色
        onPrimary: Colors.black, // ⭐ 主色上的前景色
        primaryContainer: honeyGoldDark, // ⭐ Switch thumb 等组件使用
        onPrimaryContainer: Colors.black, // ⭐ primaryContainer 上的前景色
        secondary: energyOrangeDark, // ⭐ 辅助色
        surface: Colors.black, // ⭐ 改为纯黑
        onSurface: Colors.white,
      ),
      primaryColor: honeyGoldDark, // ⭐ 主题色
      scaffoldBackgroundColor: Colors.black, // ⭐ 纯黑背景（OLED 友好）
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black, // ⭐ 改为纯黑
        foregroundColor: Colors.white,
        elevation: 0.0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: honeyGoldDark, // ⭐ 深金色
        foregroundColor: Colors.black, // 黑色文字（对比度更好）
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: honeyGoldDark, // ⭐ 深金色
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        backgroundColor: Colors.transparent, // 悬浮胶囊样式，外层透明
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: Colors.black, // ⭐ 改为纯黑卡片
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.1), // ⭐ 白色边框
            width: 1,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.12), // ⭐ 白色分割线
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
      textTheme: adjusted,
    );
  }
}
