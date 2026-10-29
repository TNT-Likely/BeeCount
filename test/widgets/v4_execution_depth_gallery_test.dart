import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/dev/component_gallery/execution_depth_sample.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('58组四档受控选择保留只读数据插槽，不触发真实配置', (t) async {
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
            body: SingleChildScrollView(
                child: ExecutionDepthSample(liveData: Text('只读插槽保持原值4'))))));
    await t.pumpAndSettle();
    expect(
        t
            .widget<BeeExecutionDepthPicker>(
                find.byType(BeeExecutionDepthPicker))
            .selected,
        4);
    await t.tap(find.text('深入'));
    await t.pumpAndSettle();
    expect(
        t
            .widget<BeeExecutionDepthPicker>(
                find.byType(BeeExecutionDepthPicker))
            .selected,
        6);
    expect(find.text('示例选择 6 轮，不写真实执行配置'), findsOneWidget);
    expect(find.text('只读插槽保持原值4'), findsOneWidget);
    await t.tap(find.text('自定义'));
    await t.pumpAndSettle();
    expect(
        t
            .widget<BeeExecutionDepthPicker>(
                find.byType(BeeExecutionDepthPicker))
            .selected,
        8);
    expect(t.takeException(), isNull);
  });
}
