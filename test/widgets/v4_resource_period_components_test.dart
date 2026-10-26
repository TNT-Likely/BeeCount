import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('详情周期视觉32触控44，父分类长名称不挤出范围且可点', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var parentTapped = false;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
                child: Padding(
                    padding: const EdgeInsets.all(17),
                    child: Column(children: [
                      BeeCompactTabs<String>(
                          value: 'all',
                          items: const [
                            BeeSegment('month', '月'),
                            BeeSegment('year', '年'),
                            BeeSegment('all', '全部')
                          ],
                          trackHeight: 32,
                          tapHeight: 44,
                          onChanged: (_) {}),
                      BeeDateRangeBar(label: '2026 年 10 月', onChoose: () {}),
                      BeeResourceParentLink(
                          label: '上级',
                          name: '工作出差与城市旅行中的日常餐饮消费',
                          onPressed: () => parentTapped = true),
                    ]))))));
    expect(tester.getSize(find.byType(BeeCompactTabs<String>)).height, 44);
    expect(
        tester.getSize(find.byKey(const ValueKey('compact-tab-track'))).height,
        32);
    await tester.tap(find.byType(BeeResourceParentLink));
    expect(parentTapped, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('账户摘要三列与历史图是受控组件，小屏大字不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selected;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
                child: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(17),
                        child: Column(children: [
                          const BeeAccountSummaryCard(
                              title: '很长的储蓄账户名称',
                              caption: '电子钱包 · CNY',
                              icon: Icon(Icons.wallet),
                              balanceLabel: '当前余额',
                              amount: '8,760.50',
                              prefix: '¥',
                              currency: 'CNY',
                              properties: [
                                BeeAccountProperty(
                                    label: '账户类型', value: '电子钱包'),
                                BeeAccountProperty(
                                    label: '计入净资产', value: '已计入'),
                                BeeAccountProperty(
                                    label: '关联账本', value: '3 个账本')
                              ]),
                          BeeBalanceHistoryCard(
                              title: '余额趋势',
                              currency: 'CNY',
                              values: const [1000, 1080, 1040],
                              axisLabels: const ['10.01', '', '10.20'],
                              selectedLabel: '¥1,040.00',
                              emptyLabel: '暂无数据',
                              onSelected: (v) => selected = v),
                        ])))))));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(BeeResourceTrend));
    final rect = tester.getRect(find.byType(BeeResourceTrend));
    await tester.tapAt(Offset(rect.right - 2, rect.center.dy));
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });
}
