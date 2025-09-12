import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'styles/typography.dart';

class BeeTheme {
  // Brand colors
  static const Color honeyGold = Color(0xFFF8C91C); // 主色
  static const Color hiveBrown = Color(0xFF8D6E63); // 辅助色
  static const Color energyOrange = Color(0xFFEF6C00); // 点缀色
  static const Color paperIvory = Color(0xFFFFF8E1); // 背景
  static const Color textDark = Color(0xFF333333); // 文字

  static ThemeData lightTheme({TargetPlatform? platform}) {
    final base = ThemeData.light();
    final pf = platform ?? defaultTargetPlatform;
    final isIOS = pf == TargetPlatform.iOS || pf == TargetPlatform.macOS;
    final adjustedTextTheme =
        AppTypography.buildBase(base.textTheme, isIOS: isIOS)
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
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: energyOrange,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        backgroundColor: Colors.white,
        elevation: 8,
      ),
      textTheme: adjustedTextTheme,
    );
  }

  static ThemeData darkTheme({TargetPlatform? platform}) {
    final base = ThemeData.dark();
    final pf = platform ?? defaultTargetPlatform;
    final isIOS = pf == TargetPlatform.iOS || pf == TargetPlatform.macOS;
    final adjusted = AppTypography.buildBase(base.textTheme, isIOS: isIOS)
        .apply(bodyColor: Colors.white, displayColor: Colors.white);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: honeyGold,
        secondary: energyOrange,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: honeyGold,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: honeyGold,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
      textTheme: adjusted,
    );
  }
}
