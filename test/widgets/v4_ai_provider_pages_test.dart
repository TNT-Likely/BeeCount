import 'dart:async';
import 'dart:convert';
import 'package:agentcore/agentcore.dart';
import 'package:beecount/ai/providers/ai_provider_config.dart';
import 'package:beecount/ai/providers/ai_provider_manager.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/ai/ai_provider_manage_page.dart';
import 'package:beecount/pages/ai/providers/bindings/ai_provider_editor.dart';
import 'package:beecount/pages/ai/providers/controllers/ai_provider_editor_controller.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Tester implements AIProviderConnectionTester {
  Completer<(bool, String?)>? pending;
  @override
  Future<(bool, String?)> test(
          AIServiceProviderConfig config, ProviderTestCapability capability,
          {void Function(AgentModelCapabilities)? onCapabilities}) =>
      (pending = Completer<(bool, String?)>()).future;
}

void main() {
  late _Tester tester;
  late ProviderContainer container;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ai_providers_v2':
          jsonEncode([AIServiceProviderConfig.zhipuDefault.toJson()])
    });
    tester = _Tester();
    container = ProviderContainer(overrides: [
      aiProviderConnectionTesterProvider.overrideWithValue(tester)
    ]);
  });
  tearDown(() => container.dispose());
  Future<void> open(WidgetTester t, {bool narrow = false}) async {
    t.view.physicalSize = narrow ? const Size(320, 568) : const Size(398, 1000);
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
            builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx)
                    .copyWith(textScaler: TextScaler.linear(narrow ? 1.4 : 1)),
                child: child!),
            home: const AIProviderManagePage())));
    await t.pumpAndSettle();
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(AIProviderManagePage)));
  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(f);
    await t.pump(const Duration(milliseconds: 300));
  }

  Finder field(String label) =>
      find.byWidgetPredicate((w) => w is BeeField && w.label == label);
  Future<void> input(WidgetTester t, String label, String value) async {
    final f =
        find.descendant(of: field(label), matching: find.byType(TextField));
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.enterText(f, value);
    await t.pumpAndSettle();
  }

  Future<void> drain(WidgetTester t) async {
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
  }

  testWidgets('新增使用弹窗，原必填校验/空密钥保存/防重复与取消不写', (t) async {
    await open(t);
    final s = l(t);
    await tap(t, find.byTooltip(s.aiProviderAdd));
    expect(find.byType(BeeDialog), findsOneWidget);
    await tap(t, find.text(s.commonSave));
    expect(find.text(s.aiProviderNameRequired), findsOneWidget);
    await drain(t);
    await input(t, s.aiProviderName, ' QA服务 ');
    await tap(t, find.text(s.commonSave));
    expect(find.text(s.aiProviderBaseUrlRequired), findsOneWidget);
    await drain(t);
    await input(t, 'Base URL', ' https://qa.invalid/v1 ');
    final button = find.widgetWithText(FilledButton, s.commonSave);
    await t.ensureVisible(button);
    await t.pumpAndSettle();
    final point = t.getCenter(button);
    await t.tapAt(point);
    await t.tapAt(point);
    await t.pumpAndSettle();
    await drain(t);
    final ps = await AIProviderManager.getProviders();
    expect(ps.length, 2);
    expect(ps.last.name, 'QA服务');
    expect(ps.last.apiKey, '');
    expect(ps.last.baseUrl, 'https://qa.invalid/v1');
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getString('ai_providers_v2');
    await tap(t, find.text('QA服务'));
    await input(t, s.aiProviderName, '不应保存');
    await tap(t, find.text(s.commonCancel));
    expect(prefs.getString('ai_providers_v2'), before);
    expect(t.takeException(), isNull);
  });
  testWidgets('内置姓名与URL禁用/密钥默认隐藏/眼睛与测试状态/保存禁用', (t) async {
    await open(t);
    final s = l(t);
    await tap(t, find.text('智谱GLM'));
    expect(t.widget<BeeField>(field(s.aiProviderName)).enabled, isFalse);
    expect(t.widget<BeeField>(field('Base URL')).enabled, isFalse);
    await input(t, 'API Key', 'qa-only-key');
    expect(t.widget<BeeField>(field('API Key')).obscure, isTrue);
    await tap(t, find.byTooltip(s.aiProviderShowKey));
    expect(t.widget<BeeField>(field('API Key')).obscure, isFalse);
    await tap(t, find.byTooltip(s.aiProviderHideKey));
    final keyBlock = find.byWidgetPredicate(
        (w) => w is BeeAIModelTestField && w.title == 'API Key');
    final test = find.descendant(
        of: keyBlock,
        matching: find.text(s.aiCloudApiTestKey));
    await tap(t, test);
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, s.commonSave))
            .onPressed,
        isNull);
    tester.pending!.complete((false, '合成连接失败'));
    await t.pumpAndSettle();
    expect(find.text('合成连接失败'), findsWidgets);
    final retry = find.descendant(
        of: keyBlock,
        matching: find.text(s.aiProviderTestFailed));
    await tap(t, retry);
    tester.pending!.complete((true, '文本与工具调用可用'));
    await t.pumpAndSettle();
    expect(find.text('文本与工具调用可用'), findsWidgets);
    await tap(t, find.text(s.commonCancel));
    expect((await AIProviderManager.getProviders()).first.apiKey, '');
    await drain(t);
    expect(t.takeException(), isNull);
  });
  testWidgets('关闭正在测试的弹窗，完成请求不操作已销毁UI', (t) async {
    await open(t);
    final s = l(t);
    await tap(t, find.text('智谱GLM'));
    await input(t, 'API Key', 'qa-only-key');
    final block = find.byWidgetPredicate(
        (w) => w is BeeAIModelTestField && w.title == 'API Key');
    await tap(
        t,
        find.descendant(
            of: block,
            matching: find.text(s.aiCloudApiTestKey)));
    await tap(t, find.byType(CloseButton));
    tester.pending!.complete((true, null));
    await t.pumpAndSettle();
    await drain(t);
    expect(find.byType(BeeDialog), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('自定义服务删除取消保持，确认删除恢复原能力绑定', (t) async {
    final custom = await AIProviderManager.addProvider(
        name: 'QA删除',
        apiKey: '',
        baseUrl: 'https://qa.invalid',
        textModel: 'qa-text');
    await AIProviderManager.setCapabilityProvider(
        AICapabilityType.text, custom.id);
    await open(t);
    final s = l(t);
    final del = find.byTooltip(s.commonDelete);
    await tap(t, del);
    expect(find.text(s.aiProviderDeleteConfirm(custom.name)), findsOneWidget);
    await tap(t, find.text(s.commonCancel));
    expect(await AIProviderManager.getProvider(custom.id), isNotNull);
    await tap(t, del);
    await tap(t, find.text(s.commonDelete));
    await drain(t);
    expect(await AIProviderManager.getProvider(custom.id), isNull);
    expect((await AIProviderManager.getCapabilityBinding()).textProviderId,
        'zhipu_glm');
    expect(find.byTooltip(s.commonDelete), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('320英文深色140%长字段、完整编辑弹窗和键盘不溢出', (t) async {
    await open(t, narrow: true);
    final s = l(t);
    await tap(t, find.text('智谱GLM'));
    expect(t.takeException(), isNull);
    await input(t, 'API Key', 'qa-only-key');
    await input(t, s.aiTextModelTitle, 'long-model-name-for-small-screen');
    expect(t.takeException(), isNull);
    await tap(t, find.text(s.commonCancel));
    await tap(t, find.byTooltip(s.aiProviderAdd));
    expect(t.takeException(), isNull);
    await tap(t, find.text(s.commonCancel));
    await drain(t);
  });
}
