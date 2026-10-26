import 'dart:ui' show SemanticsFlag;
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('月起始日保留1到28，小屏仍有44触控区域并受控返回', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selected;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                    child: BeeMonthStartDayGrid(
                        value: 28,
                        hint: '每月起始日',
                        onSelected: (day) => selected = day))))));
    expect(find.text('29'), findsNothing);
    for (var day = 1; day <= 28; day++) {
      final cell =
          find.ancestor(of: find.text('$day'), matching: find.byType(InkWell));
      expect(tester.getSize(cell).shortestSide, greaterThanOrEqualTo(44));
    }
    await tester.tap(find.text('1'));
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('账本卡独立菜单有按钮语义，选择和长按分别触发', (tester) async {
    final handle = tester.ensureSemantics();
    var selects = 0, menus = 0;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: BeeLedgerCard(
                name: '生活',
                subtitle: 'CNY · 2 笔',
                icon: const BeeLineIcon('BookOpen'),
                expense: '¥10.00',
                income: '¥20.00',
                expenseLabel: '本月支出',
                incomeLabel: '本月收入',
                currentLabel: '当前',
                current: true,
                onSelect: () => selects++,
                onMenu: () => menus++))));
    expect(
        tester
            .getSemantics(find.byType(BeeLedgerCard))
            .hasFlag(SemanticsFlag.isImage),
        isFalse);
    final menu = find.byType(BeeIconButton);
    expect(tester.getSemantics(menu).hasFlag(SemanticsFlag.isButton), isTrue);
    expect(tester.getSemantics(menu).hasFlag(SemanticsFlag.isImage), isFalse);
    await tester.tap(menu);
    expect(menus, 1);
    expect(selects, 0);
    await tester.tap(find.text('生活'));
    expect(selects, 1);
    await tester.longPress(find.text('生活'));
    expect(menus, 2);
    handle.dispose();
  });

  testWidgets('账本编辑和菜单在320深色140%长文字中无溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: '家人与旅行的共同账本');
    addTearDown(controller.dispose);
    var currency = 0, period = 0;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(children: [
                      BeeLedgerEditorForm(
                          nameController: controller,
                          nameLabel: '名称',
                          currencyLabel: '账本本位币',
                          currency: '美元 (USD)',
                          periodLabel: '月起始日',
                          period: '每月 28 日',
                          onCurrency: () => currency++,
                          onPeriod: () => period++),
                      BeeLedgerActions(
                          name: '家人与旅行的共同账本',
                          subtitle: '共享账本 · 编辑者',
                          actions: const [
                            BeeAction(
                                id: 'local',
                                label: '仅删除本地账本',
                                icon: BeeLineIcon('Trash2'))
                          ],
                          onSelected: (_) {}),
                    ]))))));
    await tester.tap(find.text('账本本位币'));
    await tester.tap(find.text('月起始日'));
    expect((currency, period), (1, 1));
    expect(tester.takeException(), isNull);
  });
}
