import 'dart:async';
import 'dart:convert';

import 'package:beecount/ai/providers/ai_provider_config.dart';
import 'package:beecount/ai/providers/ai_provider_manager.dart';
import 'package:beecount/ai/providers/xiaomi_mimo_profile.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/ai/ai_provider_manage_page.dart';
import 'package:beecount/widgets/ai/provider_model_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) => ProviderScope(
    child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Xiaomi hides URL, uses dropdowns and auto-loads after key entry',
      (tester) async {
    final pending = Completer<XiaomiMiMoModels>();
    var calls = 0;
    await tester.pumpWidget(_host(AIProviderEditPage(
      provider: AIServiceProviderConfig.xiaomiDefault,
      modelLoader: (key) {
        calls++;
        expect(key, 'test');
        return pending.future;
      },
    )));
    expect(find.text('Base URL'), findsNothing);
    expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
        isTrue);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('输入 API Key 后自动获取可用模型'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(fields,
        findsNWidgets(2)); // name + key; model IDs are never text fields
    await tester.enterText(fields.last, 'test');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 599));
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.complete(XiaomiMiMoModels(['mimo-v2.6-flash', 'mimo-v2.5-asr']));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
      'Thinking switch saves and reloads; existing key loads without test click',
      (tester) async {
    final provider =
        AIServiceProviderConfig.xiaomiDefault.copyWith(apiKey: 'test');
    SharedPreferences.setMockInitialValues({
      'ai_providers_v2': jsonEncode([provider.toJson()]),
    });
    var calls = 0;
    Future<XiaomiMiMoModels> load(String key) async {
      calls++;
      return XiaomiMiMoModels(['mimo-v2.6-flash', 'mimo-v2.5-asr']);
    }

    await tester.pumpWidget(
        _host(AIProviderEditPage(provider: provider, modelLoader: load)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.ensureVisible(find.byType(SwitchListTile).first);
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pump();
    await tester.tap(find.text('保存').first);
    await tester.pumpAndSettle();
    final saved = await AIProviderManager.getProvider('xiaomi_mimo');
    expect(saved!.thinkingEnabled, isFalse);
    expect(saved.assistantThinkingEnabled, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(
        _host(AIProviderEditPage(provider: saved, modelLoader: load)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
        isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('custom provider retains URL and manual model inputs',
      (tester) async {
    await tester.pumpWidget(_host(const AIProviderEditPage()));
    expect(find.text('Base URL'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
      'failed refresh keeps saved models; retry replaces retired selection and clears empty list',
      (tester) async {
    var calls = 0;
    var text = 'retired';
    var vision = 'mimo-v2.6-pro';
    var audio = 'mimo-v2.5-asr';
    await tester.pumpWidget(
        _host(Scaffold(body: StatefulBuilder(builder: (context, update) {
      return ProviderModelSettings(
          apiKey: 'key',
          textModel: text,
          visionModel: vision,
          audioModel: audio,
          loadModels: (_) async {
            calls++;
            if (calls == 1) throw const XiaomiMiMoModelLoadException(true);
            return XiaomiMiMoModels(calls == 2
                ? [
                    'mimo-v2.6-flash',
                    'mimo-v2.6-pro',
                    'mimo-v2.5-asr',
                    'mimo-future'
                  ]
                : []);
          },
          onChanged: (t, v, a) => update(() {
                text = t;
                vision = v;
                audio = a;
              }));
    }))));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(text, 'retired');
    expect(find.text('API Key 无效或无权限；模型列表尚未刷新'), findsOneWidget);
    expect(find.text('retired'), findsOneWidget);
    await tester.tap(find.text('重新获取模型'));
    await tester.pumpAndSettle();
    expect(text, 'mimo-v2.6-flash');
    expect(vision, 'mimo-v2.6-pro');
    expect(find.textContaining('已保存的模型不可用'), findsOneWidget);
    await tester.tap(find.text('重新获取模型'));
    await tester.pumpAndSettle();
    expect(text, isEmpty);
    expect(vision, isEmpty);
    expect(audio, isEmpty);
    expect(find.text('获取成功，当前账号没有可用模型'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
