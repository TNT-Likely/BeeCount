import 'dart:convert';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final editable in [true, false]) {
    testWidgets('预算128环形与分类行冻结几何，editable=$editable', (t) async {
      final f = jsonDecode(
              File('test/fixtures/v4-budget-geometry.json').readAsStringSync())
          as Map<String, dynamic>;
      t.view.physicalSize = const Size(398, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: Scaffold(
              body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  child: Column(children: [
                    BeeBudgetOverview(
                        title: '本月预算',
                        amount: '¥5000.00',
                        totalLabel: '总预算',
                        usedLabel: '已用',
                        used: '¥3286.50',
                        remainingLabel: '剩余',
                        remaining: '¥1713.50',
                        daysLabel: '剩余11天',
                        dailyLabel: '日均可用 ¥156',
                        editLabel: '编辑',
                        progressLabel: '66%',
                        progress: .6573,
                        negativeRemaining: false,
                        tone: BeeBudgetTone.normal,
                        onEdit: editable ? () {} : null),
                    const BeeBudgetCategoryRow(
                        name: '餐饮',
                        amounts: '¥1200 / ¥1500',
                        percent: '80%',
                        progress: .8,
                        tone: BeeBudgetTone.warning,
                        icon: BeeLineIcon('Utensils', size: 20))
                  ])))));
      await t.pumpAndSettle();
      final overview = find.byType(BeeBudgetOverview),
          ring = find.byType(CircularProgressIndicator),
          row = find.byType(BeeBudgetCategoryRow);
      expect(t.getSize(overview).width, f['overviewWidth']);
      expect(t.getSize(ring), Size.square((f['ringSize'] as num).toDouble()));
      expect(
          t.getTopLeft(ring).dy - t.getTopLeft(overview).dy, f['ringTopInset']);
      expect(t.widget<CircularProgressIndicator>(ring).strokeWidth,
          f['ringStroke']);
      expect(t.getSize(row).height, f['categoryRowHeight']);
      expect(t.takeException(), isNull);
    });
  }
}
