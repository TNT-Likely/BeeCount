import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/dev/component_gallery/ai_settings_sample.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('55组可选择长服务商/完整授权取消同意保持样例局部', (t) async {
    t.view.physicalSize = const Size(398, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
            body: SingleChildScrollView(child: AISettingsSample()))));
    await t.pumpAndSettle();
    final l = AppLocalizations.of(t.element(find.byType(AISettingsSample)));
    await t.tap(find.text(l.aiCapabilityTextChat));
    await t.pumpAndSettle();
    await t.tap(find.text('用于检查大字换行的长服务商名称'));
    await t.pumpAndSettle();
    expect(
        t
            .widget<BeeAICapabilityRow>(find.byType(BeeAICapabilityRow))
            .providerName,
        '用于检查大字换行的长服务商名称');
    await t.tap(find.text('预览完整AI授权'));
    await t.pumpAndSettle();
    expect(find.text(l.aiConsentBody), findsOneWidget);
    await t.tap(find.text(l.commonCancel));
    await t.pumpAndSettle();
    expect(find.text('示例同意，不写真实授权'), findsNothing);
    await t.tap(find.text('预览完整AI授权'));
    await t.pumpAndSettle();
    await t.tap(find.text(l.aiConsentAgree));
    await t.pumpAndSettle();
    expect(find.text('示例同意，不写真实授权'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
