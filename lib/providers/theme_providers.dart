import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

// 主题模式Provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// 可变主色（个性化换装使用）
final primaryColorProvider = StateProvider<Color>((ref) => BeeTheme.honeyGold);

// 是否隐藏金额显示
final hideAmountsProvider = StateProvider<bool>((ref) => false);

// 字体选择Provider - 已移除，仅使用系统默认字体

// 主题色持久化初始化：
// - 启动时加载保存的主色
// - 监听主色变化并写入本地
final primaryColorInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getInt('primaryColor');
  if (saved != null) {
    ref.read(primaryColorProvider.notifier).state = Color(saved);
  }
  ref.listen<Color>(primaryColorProvider, (prev, next) async {
    final colorValue = (next.a * 255).toInt() << 24 | (next.r * 255).toInt() << 16 | (next.g * 255).toInt() << 8 | (next.b * 255).toInt();
    await prefs.setInt('primaryColor', colorValue);
  });
});

// 字体持久化初始化 - 已移除，仅使用系统默认字体