import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const labels = [
    '咖啡',
    '奶茶',
    '果汁',
    '酒水',
    '工作日午餐',
    '交通通勤费用',
    '周末家庭聚餐与朋友生日及节假日外出餐饮费用',
    'Food & groceries'
  ];
  Finder chip(String name) =>
      find.widgetWithText(RecordingSubcategoryChip, name);
  Future<void> open(WidgetTester t, double width, double scale,
      {List<String> names = labels}) async {
    String? selected = names.first;
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(
            brightness: scale > 1 ? Brightness.dark : Brightness.light),
        home: Scaffold(
            body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                    width: width,
                    child: MediaQuery(
                        data: MediaQueryData(
                            textScaler: TextScaler.linear(scale)),
                        child: StatefulBuilder(
                            builder: (context, update) =>
                                RecordingSubcategoryGrid(
                                    items: names
                                        .map((name) => BeeCategoryChoice(
                                            id: name,
                                            label: name,
                                            enabled: name != '酒水',
                                            icon: const BeeLineIcon('Coffee',
                                                size: 16)))
                                        .toList(),
                                    selected: selected,
                                    onSelected: (id) =>
                                        update(() => selected = id)))))))));
    await t.pumpAndSettle();
  }

  for (final width in [244.0, 320.0]) {
    testWidgets('短名称四列，长名称占两列，保留原有次序 $width', (t) async {
      await open(t, width, 1);
      final cell = t.getSize(chip('咖啡')).width;
      for (final name in labels.take(4)) {
        expect(t.getSize(chip(name)).width, closeTo(cell, .1));
        expect(t.getTopLeft(chip(name)).dy, t.getTopLeft(chip('咖啡')).dy);
      }
      expect(t.getSize(chip('工作日午餐')).width, closeTo(cell * 2 + 5, .1));
      expect(t.getTopLeft(chip('工作日午餐')).dy,
          greaterThan(t.getTopLeft(chip('咖啡')).dy));
      expect(t.getTopLeft(chip('交通通勤费用')).dy, t.getTopLeft(chip('工作日午餐')).dy);
      expect(t.getTopLeft(chip('交通通勤费用')).dx,
          greaterThan(t.getTopLeft(chip('工作日午餐')).dx));
      expect(t.takeException(), isNull);
    });
    for (final scale in [1.0, 1.4]) {
      testWidgets('兼容历史导入超长名称：完整换行、选择不跳格、禁用与图标保留 $width/$scale', (t) async {
        await open(t, width, scale);
        final before = {for (final name in labels) name: t.getRect(chip(name))};
        await t.tap(chip('工作日午餐'));
        await t.pumpAndSettle();
        for (final name in labels) {
          expect(t.getRect(chip(name)), before[name]);
        }
        expect(
            t.widget<RecordingSubcategoryChip>(chip('工作日午餐')).selected, isTrue);
        expect(t.widget<RecordingSubcategoryChip>(chip('酒水')).onTap, isNull);
        final text = t.widget<Text>(find.descendant(
            of: chip(labels[6]), matching: find.text(labels[6])));
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(t.getSize(chip(labels[6])).height, greaterThan(44));
        expect(
            find.descendant(
                of: chip(labels[6]), matching: find.byType(BeeLineIcon)),
            findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
  for (final width in [244.0, 320.0]) {
    for (final scale in [1.0, 1.4]) {
      testWidgets('合法十字符分类占两格并完整可选 $width/$scale', (t) async {
        const maximum = '十字分类名称边界检查';
        expect(maximum.length, 10);
        await open(t, width, scale,
            names: const ['咖啡', '奶茶', '果汁', '酒水', maximum]);
        // 大字体时两字短名也可能占两格，按四列契约计算基准格宽。
        final cell = (width - 3 * RecordingSubcategoryGrid.spacing) / 4;
        expect(t.getSize(chip(maximum)).width,
            closeTo(cell * 2 + RecordingSubcategoryGrid.spacing, .1));
        final bounds = t.getRect(chip(maximum));
        await t.tap(chip(maximum));
        await t.pumpAndSettle();
        expect(
            t.widget<RecordingSubcategoryChip>(chip(maximum)).selected, isTrue);
        expect(t.getRect(chip(maximum)), bounds);
        final text = t.widget<Text>(
            find.descendant(of: chip(maximum), matching: find.text(maximum)));
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(t.takeException(), isNull);
      });
    }
  }
}
