import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/base_repository.dart';
import '../services/system/logger_service.dart';
import '../skins/premium_skins.dart';
import '../widget/widget_manager.dart';
import '../providers.dart';

final widgetManagerProvider = Provider<WidgetManager>((ref) => WidgetManager());

typedef _WidgetSettings = ({
  BaseRepository repository,
  int ledgerId,
  String baseCurrency,
  Locale? locale,
  ThemeMode theme,
  Color lightColor,
  Color darkColor,
  bool redForIncome,
});

final _widgetSettings = Provider<_WidgetSettings>((ref) {
  final color = ref.watch(primaryColorProvider);
  final skin = ref.watch(headerSkinsEnabledProvider)
      ? ref.watch(premiumSkinsProvider).selectedSkin
      : null;
  return (
    repository: ref.watch(repositoryProvider),
    ledgerId: ref.watch(currentLedgerIdProvider),
    baseCurrency: ref.watch(baseCurrencyProvider),
    locale: ref.watch(languageProvider),
    theme: ref.watch(themeModeProvider),
    lightColor: skin?.colors(Brightness.light).accent ?? color,
    darkColor: skin?.colors(Brightness.dark).accent ?? color,
    redForIncome: ref.watch(incomeExpenseColorSchemeProvider),
  );
});

final _readyWidgetSettings = Provider<_WidgetSettings?>((ref) =>
    ref.watch(appInitStateProvider) == AppInitState.ready
        ? ref.watch(_widgetSettings)
        : null);

/// Start after startup preferences and the active ledger are restored. The root
/// subscription also sees language choices made in onboarding or settings that
/// immediately rebuild/dispose the page making the change.
void listenForAppWidgetUpdates(ProviderContainer container) {
  container.listen(
      _readyWidgetSettings,
      (previous, next) {
        if (next != null && next != previous) {
          unawaited(_update(container.read(widgetManagerProvider), next,
              warmUp: true));
        }
      },
      fireImmediately: true,
      onError: (error, stack) {
        logger.error('WidgetManager', '读取小组件设置失败', error, stack);
      });
}

Future<void> updateAppWidget(WidgetRef ref) async {
  try {
    await _update(ref.read(widgetManagerProvider), ref.read(_widgetSettings));
  } catch (e, st) {
    logger.error('WidgetManager', '刷新桌面小组件失败', e, st);
  }
}

Future<void> _update(WidgetManager manager, _WidgetSettings settings,
        {bool warmUp = false}) =>
    manager.updateAllWidgetsLocalized(
      settings.repository,
      settings.ledgerId,
      settings.lightColor,
      darkThemeColor: settings.darkColor,
      explicitLocale: settings.locale,
      themeMode: settings.theme,
      redForIncome: settings.redForIncome,
      baseCurrency: settings.baseCurrency,
      warmUpAllSpecs: warmUp,
    );
