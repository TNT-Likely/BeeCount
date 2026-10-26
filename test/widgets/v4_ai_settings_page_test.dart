import 'dart:convert';
import 'package:beecount/ai/privacy/ai_privacy_consent.dart';
import 'package:beecount/ai/providers/ai_constants.dart';
import 'package:beecount/ai/providers/ai_provider_config.dart';
import 'package:beecount/ai/providers/ai_provider_manager.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/ai/ai_settings_page.dart';
import 'package:beecount/providers/ai_config_providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;
  late SharedPreferences prefs;
  Future<void> initialize({bool enabled = false}) async {
    SharedPreferences.setMockInitialValues({
      AIConstants.keyAiBillExtractionEnabled: enabled,
      'ai_providers_v2': jsonEncode([
        AIServiceProviderConfig.zhipuDefault.toJson(),
        AIServiceProviderConfig(
                id: 'qa-text',
                name: '仅文本测试服务',
                textModel: 'test-model',
                createdAt: DateTime(2026))
            .toJson(),
        AIServiceProviderConfig(
                id: 'qa-vision',
                name: '仅图片测试服务',
                visionModel: 'test-vision',
                createdAt: DateTime(2026))
            .toJson(),
      ]),
    });
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer();
    await container.read(aiConfigProvider.notifier).ensureLoaded();
  }

  tearDown(() {
    container.dispose();
    AIProviderManager.onConfigChanged = null;
  });
  Future<void> open(WidgetTester t, {bool narrow = false}) async {
    t.view.physicalSize = narrow ? const Size(320, 568) : const Size(398, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(
                brightness: narrow ? Brightness.dark : Brightness.light),
            locale: narrow ? const Locale('en') : const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(narrow ? 1.4 : 1)),
                child: child!),
            home: const AISettingsPage())));
    await t.pumpAndSettle();
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(AISettingsPage)));
  Future<void> tap(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text).last);
    await t.pumpAndSettle();
    await t.tap(find.text(text).last);
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
  }

  testWidgets('原授权完整弹窗取消不启用/同意落库及重新加载', (t) async {
    await initialize();
    await open(t);
    final s = l(t);
    await tap(t, s.aiEnableTitle);
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(find.text(s.aiConsentBody), findsOneWidget);
    await tap(t, s.commonCancel);
    expect(container.read(aiConfigProvider).enabled, isFalse);
    expect(await AiPrivacyConsentStore.isConsented(), isFalse);
    await tap(t, s.aiEnableTitle);
    await tap(t, s.aiConsentAgree);
    expect(await AiPrivacyConsentStore.isConsented(), isTrue);
    expect(prefs.getBool(AIConstants.keyAiBillExtractionEnabled), isTrue);
    await tap(t, s.aiEnableTitle);
    final reopened = ProviderContainer();
    await reopened.read(aiConfigProvider.notifier).ensureLoaded();
    expect(reopened.read(aiConfigProvider).enabled, isFalse);
    reopened.dispose();
    expect(t.takeException(), isNull);
  });
  testWidgets('升级前已开启而未授权仍补弹，拒绝关闭', (t) async {
    await initialize(enabled: true);
    await open(t);
    final s = l(t);
    expect(find.text(s.aiConsentBody), findsOneWidget);
    await tap(t, s.commonCancel);
    expect(prefs.getBool(AIConstants.keyAiBillExtractionEnabled), isFalse);
  });
  testWidgets('三能力按原模型过滤，真实选择与取消保存原绑定', (t) async {
    await initialize();
    await open(t);
    final s = l(t);
    await tap(t, s.aiCapabilityTextChat);
    expect(find.text('仅文本测试服务'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(BeeDialog), matching: find.text('仅图片测试服务')),
        findsNothing);
    await tap(t, '仅文本测试服务');
    expect((await AIProviderManager.getCapabilityBinding()).textProviderId,
        'qa-text');
    await tap(t, s.aiCapabilityImageUnderstand);
    expect(
        find.descendant(
            of: find.byType(BeeDialog), matching: find.text('仅文本测试服务')),
        findsNothing);
    await tap(t, '仅图片测试服务');
    expect((await AIProviderManager.getCapabilityBinding()).visionProviderId,
        'qa-vision');
    final before = prefs.getString('ai_capability_binding_v2');
    await tap(t, s.aiCapabilitySpeechToText);
    expect(
        find.descendant(
            of: find.byType(BeeDialog), matching: find.text('仅文本测试服务')),
        findsNothing);
    expect(
        find.descendant(
            of: find.byType(BeeDialog), matching: find.text('仅图片测试服务')),
        findsNothing);
    expect(find.text(s.aiProviderNoApiKey), findsOneWidget);
    await tap(t, s.commonCancel);
    expect(prefs.getString('ai_capability_binding_v2'), before);
    expect(t.takeException(), isNull);
  });
  testWidgets('原高级策略可折叠，本地两项禁用，云端策略持久化', (t) async {
    await initialize();
    await open(t);
    final s = l(t);
    await tap(t, s.aiPromptAdvancedSettings);
    expect(
        t
            .widget<BeeRadioTile<AIStrategy>>(find.widgetWithText(
                BeeRadioTile<AIStrategy>, s.aiStrategyLocalOnly))
            .onChanged,
        isNull);
    await tap(t, s.aiStrategyCloudOnly);
    expect(prefs.getString(AIConstants.keyAiStrategy), 'cloud_only');
    await tap(t, s.aiStrategyCloudFirst);
    expect(prefs.getString(AIConstants.keyAiStrategy), 'cloud_first');
    expect(find.text(s.aiPromptEditEntry), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('320英文深色140%授权与长能力标签不溢出', (t) async {
    await initialize();
    await open(t, narrow: true);
    final s = l(t);
    await tap(t, s.aiEnableTitle);
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(t.takeException(), isNull);
    await tap(t, s.commonCancel);
    await tap(t, s.aiCapabilityTextChat);
    expect(t.takeException(), isNull);
    await tap(t, s.commonCancel);
    await tap(t, s.aiPromptAdvancedSettings);
    expect(t.takeException(), isNull);
  });
}
