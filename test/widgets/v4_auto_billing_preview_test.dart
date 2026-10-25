import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/presentation/v4/bindings/auto_billing_actions.dart';
import 'package:beecount/presentation/v4/bindings/auto_billing_preview.dart';
import 'package:beecount/presentation/v4/bindings/ios_auto_billing_actions.dart';
import 'package:beecount_business_ui/auto_billing.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Android只读真实既有开关，不创建监听或请求权限/电池/外部动作', (t) async {
    SharedPreferences.setMockInitialValues(
        {'screenshot_monitor_enabled': true});
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getKeys().map((k) => (k, prefs.get(k))).toList();
    final calls = <String>[];
    const channel = MethodChannel('com.tntlikely.beecount/screenshot');
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call.method);
      return null;
    });
    await t.pumpWidget(ProviderScope(overrides: [
      autoBillingPlatformProvider.overrideWithValue(AutoBillingPlatform.android)
    ], child: app()));
    await t.pumpAndSettle();
    final card = t.widget<BeeAutoBillingMonitorCard>(
        find.byType(BeeAutoBillingMonitorCard));
    expect(card.enabled, isTrue);
    expect(card.onChanged, isNull);
    expect(calls, isEmpty);
    expect(prefs.getKeys().map((k) => (k, prefs.get(k))).toList(), before);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
  testWidgets('iOS旧系统只读支持性展示，不读取Android状态或打开快捷指令', (t) async {
    await t.pumpWidget(ProviderScope(overrides: [
      autoBillingPlatformProvider.overrideWithValue(AutoBillingPlatform.ios),
      iosAutoBillingSupportsAppIntentsProvider.overrideWithValue(false),
      autoBillingReadOnlyEnabledProvider.overrideWith(
          (ref) => throw StateError('must not read Android prefs'))
    ], child: app()));
    await t.pumpAndSettle();
    expect(find.byType(BeeAutoBillingVersionNotice), findsOneWidget);
    expect(find.byType(BeeAutoBillingMonitorCard), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
}

Widget app() => MaterialApp(
    theme: beeTheme(),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(
        body: SingleChildScrollView(child: LiveAutoBillingPreview())));
