import 'package:beecount/ai/core/prompt_builder.dart';
import 'package:beecount/ai/providers/ai_provider_manager.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/ai/ai_prompt_edit_page.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'ai_custom_prompt': '原草稿 {{OCR_TEXT}}'});
    AIProviderManager.onConfigChanged = null;
  });
  tearDown(() => AIProviderManager.onConfigChanged = null);
  Future<void> open(WidgetTester t, {bool narrow = false}) async {
    t.view.physicalSize = narrow ? const Size(320, 568) : const Size(398, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: beeTheme(
                brightness: narrow ? Brightness.dark : Brightness.light),
            locale: Locale(narrow ? 'en' : 'zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx)
                    .copyWith(textScaler: TextScaler.linear(narrow ? 1.4 : 1)),
                child: child!),
            home: const AIPromptEditPage())));
    await t.pumpAndSettle();
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(AIPromptEditPage)));
  Future<void> tap(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(f, 180,
          scrollable: find.byType(Scrollable).first);
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> drain(WidgetTester t) async {
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
  }

  testWidgets('缺失提示出现与消失时保留正在输入的焦点和光标', (t) async {
    SharedPreferences.setMockInitialValues(
        {'ai_custom_prompt': PromptBuilder.defaultTemplate});
    await open(t);
    await t.scrollUntilVisible(find.byType(TextField), 180,
        scrollable: find.byType(Scrollable).first);
    await t.showKeyboard(find.byType(TextField));
    expect(t.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
        isTrue);
    await t.enterText(find.byType(TextField), '');
    await t.pumpAndSettle();
    expect(t.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
        isTrue);
    await t.enterText(find.byType(TextField), 'Q');
    await t.pumpAndSettle();
    expect(
        t
            .widget<EditableText>(find.byType(EditableText))
            .controller
            .selection
            .baseOffset,
        1);
    expect(t.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
        isTrue);
    await t.enterText(find.byType(TextField), PromptBuilder.defaultTemplate);
    await t.pumpAndSettle();
    expect(t.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
        isTrue);
    expect(t.takeException(), isNull);
  });
  testWidgets('变量登记表全量展示、缺失能力只给安全补丁，保存走原通知', (t) async {
    var saves = 0;
    AIProviderManager.onConfigChanged = () => saves++;
    await open(t);
    final s = l(t);
    await tap(t, find.text(s.aiPromptVariables));
    for (final p in PromptBuilder.placeholders) {
      expect(find.text(p.token), findsOneWidget);
    }
    await tap(t, find.text(s.aiPromptVariables));
    final safe = PromptBuilder.placeholders
        .firstWhere((p) => p.token == '{{CURRENCIES}}');
    await tap(t, find.text(s.aiPromptInsertVarSection(safe.token)));
    expect(
        (await SharedPreferences.getInstance()).getString('ai_custom_prompt'),
        '原草稿 {{OCR_TEXT}}');
    await drain(t);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text,
        contains(safe.token));
    await tap(t, find.text(s.aiPromptSave));
    await drain(t);
    expect(saves, 1);
    expect(
        (await SharedPreferences.getInstance()).getString('ai_custom_prompt'),
        contains(safe.token));
    expect(find.text(s.aiPromptUnsaved), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('恢复默认为规范弹窗，取消不动，确认只改草稿直到保存', (t) async {
    await open(t);
    final s = l(t);
    final prefs = await SharedPreferences.getInstance();
    await tap(t, find.text(s.aiPromptResetDefault).last);
    expect(find.byType(BeeDialog), findsOneWidget);
    await tap(t, find.text(s.commonCancel));
    expect(prefs.getString('ai_custom_prompt'), '原草稿 {{OCR_TEXT}}');
    await tap(t, find.text(s.aiPromptResetDefault).last);
    await tap(t, find.text(s.commonConfirm));
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text,
        PromptBuilder.defaultTemplate);
    expect(prefs.getString('ai_custom_prompt'), '原草稿 {{OCR_TEXT}}');
    await tap(t, find.text(s.aiPromptSave));
    await drain(t);
    expect(prefs.getString('ai_custom_prompt'), PromptBuilder.defaultTemplate);
    expect(t.takeException(), isNull);
  });
  testWidgets('粘贴和预览沿原系统接口与示例，预览关闭不保存', (t) async {
    const pasted = '{{CURRENT_TIME}} {{ACCOUNTS}} {{CURRENCIES}}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async => call.method == 'Clipboard.getData'
                ? <String, Object>{'text': pasted}
                : null);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await open(t);
    final s = l(t);
    await tap(t, find.byTooltip(s.aiPromptPaste));
    await drain(t);
    expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text, pasted);
    await tap(t, find.text(s.aiPromptPreview));
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(find.byType(BeeCodeBlock), findsOneWidget);
    expect(t.widget<BeeCodeBlock>(find.byType(BeeCodeBlock)).text,
        contains('Chase(USD)'));
    await tap(t, find.text(s.commonClose));
    expect(
        (await SharedPreferences.getInstance()).getString('ai_custom_prompt'),
        '原草稿 {{OCR_TEXT}}');
    expect(t.takeException(), isNull);
  });
  testWidgets('320英文深色140%完整变量/警告/源编辑/预览弹窗无溢出', (t) async {
    await open(t, narrow: true);
    final s = l(t);
    await tap(t, find.text(s.aiPromptVariables));
    expect(find.byType(BeePromptVariables), findsOneWidget);
    expect(t.takeException(), isNull);
    await tap(t, find.text(s.aiPromptVariables));
    await t.scrollUntilVisible(find.byType(BeeCodeEditor), 180,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await tap(t, find.text(s.aiPromptPreview));
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(t.takeException(), isNull);
    await tap(t, find.text(s.commonClose));
  });
}
