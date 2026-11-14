import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('收入单项不留支出空行，选中空日只高亮日期', (t) async {
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        home: Scaffold(
            body: Row(children: [
          const SizedBox(
              width: 50,
              height: 80,
              child: BeeCalendarDayCell(
                  day: '1',
                  semanticLabel: '收入日',
                  income: '+100',
                  expenseColor: Colors.red,
                  incomeColor: Colors.green)),
          const SizedBox(
              width: 50,
              height: 80,
              child: BeeCalendarDayCell(
                  day: '2',
                  semanticLabel: '支出日',
                  expense: '-100',
                  expenseColor: Colors.red,
                  incomeColor: Colors.green)),
          const SizedBox(
              width: 50,
              height: 80,
              child: BeeCalendarDayCell(
                  day: '3',
                  semanticLabel: '空日',
                  selected: true,
                  expenseColor: Colors.red,
                  incomeColor: Colors.green)),
        ]))));
    expect(
        t.getTopLeft(find.text('+100')).dy, t.getTopLeft(find.text('-100')).dy);
    final cell =
        find.byWidgetPredicate((w) => w is BeeCalendarDayCell && w.day == '3');
    final selected =
        find.descendant(of: cell, matching: find.byType(Container));
    final rect = t.getRect(selected);
    expect(rect.width, rect.height);
    expect(rect.height, lessThan(t.getSize(cell).height));
    expect(t.takeException(), isNull);
  });
}
