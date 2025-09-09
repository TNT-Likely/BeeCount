import 'package:flutter/material.dart';

class BeeTheme {
  // Brand colors
  static const Color honeyGold = Color(0xFFF8C91C); // 主色
  static const Color hiveBrown = Color(0xFF8D6E63); // 辅助色
  static const Color energyOrange = Color(0xFFEF6C00); // 点缀色
  static const Color paperIvory = Color(0xFFFFF8E1); // 背景
  static const Color textDark = Color(0xFF333333); // 文字

  static ThemeData lightTheme() {
    final base = ThemeData.light();
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
      textTheme: base.textTheme.apply(
        bodyColor: textDark,
        displayColor: textDark,
        fontFamily: 'NotoSans',
      ),
    );
  }

  static ThemeData darkTheme() {
    final base = ThemeData.dark();
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
    );
  }
}
