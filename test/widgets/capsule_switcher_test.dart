import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/widgets/ui/ui.dart';

void main() {
  testWidgets('nullable 全部选项可切换，向辅助技术提供选中状态', (tester) async {
    final semantics = tester.ensureSemantics();
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
      builder: (context, setState) => Scaffold(
          body: CapsuleSwitcher<String?>(
        selectedValue: selected,
        options: const [
          CapsuleOption(value: null, label: '全部流水'),
          CapsuleOption(value: 'income', label: '收入与转入'),
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

  testWidgets('箭头打开周期选择器，不触发选项切换', (tester) async {
    var opened = 0;
    var changed = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CapsuleSwitcher<int>(
      selectedValue: 0,
      options: [
        CapsuleOption(
            value: 0, label: '月', showArrow: true, onTap: () => opened++)
      ],
      onChanged: (_) => changed++,
    ))));
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
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
                child: CapsuleSwitcher<String?>(
                  selectedValue: null,
                  options: const [
                    CapsuleOption(value: null, label: '全部流水'),
                    CapsuleOption(value: 'expense', label: '支出与转出'),
                    CapsuleOption(value: 'income', label: '收入与转入'),
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
