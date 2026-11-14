import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('正负柱共享零轴、点柱受控、均线接收宿主口径', (t) async {
    int? selected;
    var averageOpened = 0;
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: SizedBox(
                width: 300,
                child: StatefulBuilder(
                    builder: (context, setState) => BeeColumnChart(
                        values: const [-10, 20, 0],
                        labels: const ['1日', '2日', '3日'],
                        valueLabels: const ['−10', '20', '0'],
                        average: 3.333,
                        averageLabel: '日均 3.33',
                        selected: selected,
                        onSelected: (i) => setState(() => selected = i),
                        onAverage: () => averageOpened++))))));
    final negative = find.byKey(const ValueKey('column-bar-0')),
        positive = find.byKey(const ValueKey('column-bar-1'));
    expect(
        t.getTopLeft(negative).dy, closeTo(t.getBottomLeft(positive).dy, .001));
    expect(t.getBottomLeft(negative).dy,
        greaterThan(t.getBottomLeft(positive).dy));
    await t.tap(negative);
    await t.pump();
    expect(selected, 0);
    expect(find.byKey(const ValueKey('column-point-detail')), findsOneWidget);
    expect(find.text('1日\n−10'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('column-average-label')));
    await t.pump();
    expect(averageOpened, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets('全零序列可显示且有限布局、不创建伪金额', (t) async {
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: const Scaffold(
            body: SizedBox(
                width: 300,
                child: BeeColumnChart(
                    values: [0, 0],
                    labels: ['1', '2'],
                    valueLabels: ['0', '0'],
                    average: 0,
                    averageLabel: '日均 0')))));
    expect(t.getTopLeft(find.byKey(const ValueKey('column-bar-0'))).dy,
        greaterThan(100));
    expect(t.takeException(), isNull);
  });
  testWidgets('紧凑Tab不横滚且整项点击保留40px高度', (t) async {
    var chosen = 'month';
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 320,
                child: StatefulBuilder(
                    builder: (context, setState) => BeeCompactTabs<String>(
                            items: const [
                              BeeSegment('month', '月'),
                              BeeSegment('year', '年'),
                              BeeSegment('all', '全部')
                            ],
                            value: chosen,
                            onChanged: (v) => setState(() => chosen = v)))))));
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(t.getSize(find.byType(BeeCompactTabs<String>)).height, 40);
    await t.tap(find.text('全部'));
    await t.pump();
    expect(chosen, 'all');
    await t.drag(find.byType(BeeCompactTabs<String>), const Offset(-180, 0));
    await t.pump();
    expect(chosen, 'all');
    expect(t.takeException(), isNull);
  });
}
