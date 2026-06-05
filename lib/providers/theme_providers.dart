import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/system/logger_service.dart';
import '../theme.dart';
import '../widget/widget_manager.dart';
import '../providers.dart';

// 主题模式Provider（默认跟随系统）
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// 主题模式持久化初始化
final themeModeInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('themeMode');
  if (saved != null) {
    switch (saved) {
      case 'light':
        ref.read(themeModeProvider.notifier).state = ThemeMode.light;
        break;
      case 'dark':
        ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
        break;
      default:
        ref.read(themeModeProvider.notifier).state = ThemeMode.system;
    }
  }
  ref.listen<ThemeMode>(themeModeProvider, (prev, next) async {
    String value;
    switch (next) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      default:
        value = 'system';
    }
    await prefs.setString('themeMode', value);
  });
});

// 暗黑模式下头部图案样式Provider
// 可选值：'none'（无图案）、'icons'（图标平铺）、'particles'（粒子星星）、'honeycomb'（蜂巢六边形）
final darkModePatternStyleProvider = StateProvider<String>((ref) => 'icons');

// 暗黑模式图案样式持久化初始化
final darkModePatternStyleInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('darkModePatternStyle');
  if (saved != null) {
    ref.read(darkModePatternStyleProvider.notifier).state = saved;
  }
  ref.listen<String>(darkModePatternStyleProvider, (prev, next) async {
    await prefs.setString('darkModePatternStyle', next);
  });
});

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
    // Update widget with new theme color
    try {
      final repository = ref.read(repositoryProvider);
      final currentLedgerId = ref.read(currentLedgerIdProvider);
      final redForIncome = ref.read(incomeExpenseColorSchemeProvider);
      final widgetManager = WidgetManager();
      await widgetManager.updateWidget(
        repository,
        currentLedgerId,
        next,
        redForIncome: redForIncome,
      );
    } catch (e) {
      // Silently fail
    }

    // 推送主题色到 server，让 web 端通过 WS profile_change 自动跟随。
    // 同步方向单向：mobile → server → web；web 本地改色不回推。
    unawaited(() async {
      try {
        final cloudProvider =
            await ref.read(beecountCloudProviderInstance.future);
        if (cloudProvider == null) return;
        final hex = _colorToHex(next);
        await cloudProvider.updateMyProfileThemeColor(hex: hex);
        logger.info(
            'theme_providers', 'primary color pushed to server: $hex');
      } catch (e) {
        logger.warning(
            'theme_providers', 'push primary color failed (non-blocking): $e');
      }
    }());
  });
});

/// Flutter [Color] → `#RRGGBB`。忽略 alpha，server 只存 6 位 hex。
String _colorToHex(Color color) {
  final r = (color.r * 255).toInt() & 0xff;
  final g = (color.g * 255).toInt() & 0xff;
  final b = (color.b * 255).toInt() & 0xff;
  return '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

// 隐私模式持久化初始化：
// - 启动时加载保存的隐私模式状态
// - 监听隐私模式变化并写入本地
final hideAmountsInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('hideAmounts');
  if (saved != null) {
    ref.read(hideAmountsProvider.notifier).state = saved;
  }
  ref.listen<bool>(hideAmountsProvider, (prev, next) async {
    await prefs.setBool('hideAmounts', next);
  });
});

// 字体持久化初始化 - 已移除，仅使用系统默认字体

// Header装饰样式Provider
// 可选值：'icons'（图标平铺）、'particles'（粒子星星）、'honeycomb'（蜂巢六边形）
final headerDecorationStyleProvider = StateProvider<String>((ref) => 'icons');

// 金额显示格式Provider（默认显示完整金额）
// false = 完整金额（如 123,456.78）
// true = 简洁显示（如 12.3万）
final compactAmountProvider = StateProvider<bool>((ref) => false);

// 金额显示格式持久化初始化
final compactAmountInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('compactAmount');
  if (saved != null) {
    ref.read(compactAmountProvider.notifier).state = saved;
  }
  ref.listen<bool>(compactAmountProvider, (prev, next) async {
    await prefs.setBool('compactAmount', next);
    _pushAppearanceToCloud(ref);
  });
});

// 显示交易时间Provider（默认不显示）
// false = 只显示日期
// true = 显示日期和时间（时:分）
final showTransactionTimeProvider = StateProvider<bool>((ref) => false);

// 显示交易时间持久化初始化
final showTransactionTimeInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('showTransactionTime');
  if (saved != null) {
    ref.read(showTransactionTimeProvider.notifier).state = saved;
  }
  ref.listen<bool>(showTransactionTimeProvider, (prev, next) async {
    await prefs.setBool('showTransactionTime', next);
    _pushAppearanceToCloud(ref);
  });
});

// Header装饰样式持久化初始化
final headerDecorationStyleInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('headerDecorationStyle');
  if (saved != null) {
    ref.read(headerDecorationStyleProvider.notifier).state = saved;
  }
  ref.listen<String>(headerDecorationStyleProvider, (prev, next) async {
    await prefs.setString('headerDecorationStyle', next);
    _pushAppearanceToCloud(ref);
  });
});

/// 把 header_decoration_style / compact_amount / show_transaction_time
/// 的当前值打包推给 server 的 /profile/me。非 BeeCount Cloud 模式 provider
/// 返回 null 直接跳过。fire-and-forget,失败只打 warning。
///
/// 用整包 PATCH 是故意的:三者属于同一组"外观",任何一个改动都重发全量,server
/// 写入 appearance_json 整体替换,对端用 WS profile_change 事件拉 /profile/me
/// 拿到最新 dict 应用。
void _pushAppearanceToCloud(Ref ref) {
  unawaited(() async {
    try {
      final cloudProvider =
          await ref.read(beecountCloudProviderInstance.future);
      if (cloudProvider == null) return;
      final appearance = <String, dynamic>{
        'header_decoration_style': ref.read(headerDecorationStyleProvider),
        'compact_amount': ref.read(compactAmountProvider),
        'show_transaction_time': ref.read(showTransactionTimeProvider),
      };
      await cloudProvider.updateMyProfileAppearance(appearance: appearance);
      logger.info('theme_providers',
          'pushed appearance to server: $appearance');
    } catch (e, st) {
      logger.warning('theme_providers',
          'push appearance failed (non-blocking): $e', st);
    }
  }());
}

// 收支颜色方案Provider（默认红色收入、绿色支出）
// true = 红色收入、绿色支出
// false = 红色支出、绿色收入
final incomeExpenseColorSchemeProvider = StateProvider<bool>((ref) => true);

// 收支颜色方案持久化初始化
final incomeExpenseColorSchemeInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('incomeExpenseColorScheme');
  if (saved != null) {
    ref.read(incomeExpenseColorSchemeProvider.notifier).state = saved;
  }
  ref.listen<bool>(incomeExpenseColorSchemeProvider, (prev, next) async {
    await prefs.setBool('incomeExpenseColorScheme', next);
    try {
      final repository = ref.read(repositoryProvider);
      final currentLedgerId = ref.read(currentLedgerIdProvider);
      final primaryColor = ref.read(primaryColorProvider);
      final widgetManager = WidgetManager();
      await widgetManager.updateWidget(
        repository,
        currentLedgerId,
        primaryColor,
        redForIncome: next,
      );
    } catch (e) {
      // Silently fail
    }

    // BeeCount Cloud 模式下把配色偏好推给 server；web 端会通过 WS
    // profile_change 事件实时刷新。非 Cloud 模式 provider 返回 null，跳过。
    unawaited(() async {
      try {
        final cloudProvider =
            await ref.read(beecountCloudProviderInstance.future);
        if (cloudProvider == null) return;
        await cloudProvider.updateMyProfileIncomeColorScheme(
          incomeIsRed: next,
        );
        logger.info('theme_providers',
            'income color scheme pushed to server: incomeIsRed=$next');
      } catch (e) {
        logger.warning('theme_providers',
            'push income color scheme failed (non-blocking): $e');
      }
    }());
  });
});

// 用户显示名(昵称)。本地真值存 prefs 'displayName';BeeCount Cloud 模式下改动
// 会推到 server,其余云模式 / 纯本地只存本地。空串 = 未设置。v1 不支持"清空已设
// 昵称"——不会推空串给 server,因此无需改后端 / 包层(包层对空串本就 throw)。
final displayNameProvider = StateProvider<String>((ref) => '');

// 显示名持久化初始化:启动加载 prefs + 监听变化写回本地,并在 cloud 模式下推送。
// 完全照搬 themeMode / compactAmount 的写法。
final displayNameInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('displayName');
  if (saved != null) {
    ref.read(displayNameProvider.notifier).state = saved;
  }
  ref.listen<String>(displayNameProvider, (prev, next) async {
    await prefs.setString('displayName', next);
    _pushDisplayNameToCloud(ref, next);
  });
});

/// 把显示名推给 server 的 /profile/me(仅 BeeCount Cloud 模式)。非 cloud 模式
/// provider 返回 null 直接跳过;空串不推(v1 不支持清空,且包层对空串会 throw)。
/// fire-and-forget,失败只打 warning。
void _pushDisplayNameToCloud(Ref ref, String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return;
  unawaited(() async {
    try {
      final cloudProvider =
          await ref.read(beecountCloudProviderInstance.future);
      if (cloudProvider == null) return;
      await cloudProvider.updateMyProfileDisplayName(displayName: trimmed);
      logger.info('theme_providers', 'display name pushed to server: $trimmed');
    } catch (e, st) {
      logger.warning('theme_providers',
          'push display name failed (non-blocking): $e', st);
    }
  }());
}