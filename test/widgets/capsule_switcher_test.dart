import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount_ui/beecount_ui.dart';

void main() {
  testWidgets('nullable 全部选项可切换，向辅助技术提供选中状态', (tester) async {
    final semantics = tester.ensureSemantics();
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
      builder: (context, setState) => Scaffold(
          body: BeeSegmented<String?>(
        value: selected,
        items: const [
          BeeSegment(null, '全部流水'),
          BeeSegment('income', '收入与转入'),
        ],
        onChanged: (value) => setState(() => selected = value),
      )),
    )));
    expect(
        tester
            .getSemantics(find.text('全部流水'))
            .hasFlag(SemanticsFlag.isSelected),
        isTrue);
    await tester.tap(find.text('收入与转入'));
    await tester.pumpAndSettle();
    expect(selected, 'income');
    expect(
        tester
            .getSemantics(find.text('收入与转入'))
            .hasFlag(SemanticsFlag.isSelected),
        isTrue);
    await tester.tap(find.text('全部流水'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    semantics.dispose();
  });

  testWidgets('当前独立日期入口打开选择器，不触发周期Tab切换', (tester) async {
    var opened = 0;
    var changed = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      BeeSegmented<int>(
          value: 0,
          items: const [BeeSegment(0, '月'), BeeSegment(1, '年')],
          onChanged: (_) => changed++),
      BeeDateRangeBar(label: '2026 年 10 月', onChoose: () => opened++)
    ]))));
    final arrow = find.descendant(
        of: find.byType(BeeDateRangeBar),
        matching: find.byWidgetPredicate(
            (widget) => widget is BeeLineIcon && widget.name == 'ChevronDown'));
    await tester.tap(arrow);
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(changed, 0);
    await tester.tap(find.text('月'));
    expect(changed, 1);
  });

  testWidgets('窄屏、大字号和 RTL 下可滚动到最后一个完整标签', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            body: SizedBox(
                width: 200,
                child: BeeSegmented<String?>(
                  value: null,
                  items: const [
                    BeeSegment(null, '全部流水'),
                    BeeSegment('expense', '支出与转出'),
                    BeeSegment('income', '收入与转入'),
                  ],
                  onChanged: (value) => selected = value,
                ))),
      ),
    )));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('收入与转入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收入与转入'));
    expect(selected, 'income');
    expect(tester.takeException(), isNull);
  });
}
