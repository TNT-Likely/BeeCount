import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/dev/component_gallery/ai_prompt_sample.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('57组提示词局部编辑保存/重置/预览，只读插槽与纯回调', (t) async {
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
            body: SingleChildScrollView(
                child: AIPromptSample(liveData: Text('真实只读插槽'))))));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'edited {{OCR_TEXT}}');
    await t.pumpAndSettle();
    expect(find.text('未保存'), findsOneWidget);
    await t.tap(find.text('保存'));
    await t.pumpAndSettle();
    expect(find.text('示例已保存，不写真实模板'), findsOneWidget);
    expect(find.text('未保存'), findsNothing);
    await t.tap(find.text('预览'));
    await t.pumpAndSettle();
    expect(t.widget<BeeCodeBlock>(find.byType(BeeCodeBlock)).text,
        'edited 合成账单文本');
    await t.tap(find.text('关闭'));
    await t.pumpAndSettle();
    await t.tap(find.text('恢复默认'));
    await t.pumpAndSettle();
    expect(find.text('未保存'), findsOneWidget);
    expect(find.text('真实只读插槽'), findsOneWidget);
    expect(find.byType(BeePromptDocument), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
