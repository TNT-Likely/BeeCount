import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/dev/component_gallery/ai_provider_sample.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('56组服务商卡/测试中成功失败与纯本地事件', (t) async {
    t.view.physicalSize = const Size(398, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
            body: SingleChildScrollView(child: AIProviderSample()))));
    await t.pumpAndSettle();
    await t.tap(find.text('QA兼容服务'));
    await t.pumpAndSettle();
    expect(find.text('示例编辑入口'), findsOneWidget);
    await t.tap(find.text('测试中'));
    await t.pump();
    expect(t.widget<BeeAIModelTestField>(find.byType(BeeAIModelTestField)).busy,
        isTrue);
    await t.tap(find.text('失败'));
    await t.pumpAndSettle();
    expect(find.text('合成连接失败，请检查配置'), findsOneWidget);
    await t.tap(find.text('成功'));
    await t.pumpAndSettle();
    expect(find.text('文本与工具调用可用'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
