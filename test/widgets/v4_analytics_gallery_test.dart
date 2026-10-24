import 'package:beecount/presentation/v4/gallery/analytics_sample.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('内嵌53组受控视角/分类展开/环图选择', (t) async {
    t.view.physicalSize = const Size(398, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: const Scaffold(
            body: SingleChildScrollView(child: AnalyticsSample()))));
    expect(find.text('¥3,286.5'), findsOneWidget);
    await t.tap(find.text('结余'));
    await t.pumpAndSettle();
    expect(find.text('¥8,713.5'), findsOneWidget);
    expect(find.byType(BeeCategoryRanking), findsNothing);
    await t.tap(find.text('支出'));
    await t.pumpAndSettle();
    await t.tap(find.text('餐饮'));
    await t.pump();
    expect(find.text('午餐'), findsOneWidget);
    await t.tap(find.byTooltip('显示分类环图'));
    await t.pump();
    expect(find.byType(BeeDonutChart), findsOneWidget);
    await t.tap(find.byType(ActionChip).first);
    await t.pump();
    expect(t.widget<BeeDonutChart>(find.byType(BeeDonutChart)).selected, 0);
    expect(t.takeException(), isNull);
  });
}
