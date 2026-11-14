import 'dart:ui' show SemanticsAction;
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [398.0, 320.0]) {
    testWidgets('分类迁移选择卡$width：66高/40图标槽/24原色图片与独立按钮语义', (t) async {
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final semantics = t.ensureSemantics();
      try {
        var taps = 0;
        await t.pumpWidget(MaterialApp(
            theme: beeTheme(),
            home: Scaffold(
                body: Padding(
                    padding: const EdgeInsets.all(17),
                    child: BeeCategoryMigrationPair(
                        fromLabel: '迁出分类',
                        toLabel: '迁入分类',
                        fromHint: '选择要迁出的分类',
                        toHint: '请先选择迁出分类',
                        fromName: '自定义咖啡',
                        fromIcon: Image.asset(
                            'assets/v4_gallery/category-coffee.png',
                            width: 24,
                            height: 24),
                        onFrom: () => taps++)))));
        await t.pumpAndSettle();
        final source = find.bySemanticsLabel('迁出分类 · 自定义咖啡');
        expect(t.getSize(source), Size(width - 34, 66));
        expect(t.getSize(find.byType(Image)), const Size(24, 24));
        expect(t.widget<Image>(find.byType(Image)).color, isNull);
        expect(
            t
                .getSemantics(source)
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            true);
        final target = find.bySemanticsLabel('迁入分类 · 请先选择迁出分类');
        expect(
            t
                .getSemantics(target)
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            false);
        await t.tap(source);
        await t.pump();
        expect(taps, 1);
        expect(t.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    });
  }
  testWidgets('只读长名称完整语义与大字深色不溢出', (t) async {
    const name = '这是一条完整且很长的自定义二级分类名称，需要可访问性保留全文';
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 286,
                    child: MediaQuery(
                        data: const MediaQueryData(
                            textScaler: TextScaler.linear(1.4)),
                        child: const BeeCategoryMigrationPair(
                            fromLabel: '来源',
                            toLabel: '目标',
                            fromHint: '选择',
                            toHint: '选择',
                            fromName: name,
                            toName: '目标分类')))))));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('来源 · $name'), findsOneWidget);
    expect(find.byTooltip(name), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
