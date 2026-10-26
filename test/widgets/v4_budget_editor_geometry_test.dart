import 'dart:convert';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('预算编辑类型/金额卡与HTML冻结尺寸一致', (t) async {
    final f = jsonDecode(File('test/fixtures/v4-budget-editor-geometry.json')
        .readAsStringSync());
    t.view.physicalSize = const Size(398, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: '5000.00');
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Column(children: [
                  BeeBudgetEditorForm(
                      amountController: controller,
                      type: 'total',
                      totalLabel: '总预算',
                      categoryTypeLabel: '分类预算',
                      categoryLabel: '选择分类',
                      categoryHint: '请选择预算分类',
                      amountLabel: '预算金额',
                      amountHint: '请输入预算金额',
                      symbol: '¥',
                      onType: (_) {}),
                  BeeButton(label: '保存', onPressed: () {})
                ])))));
    await t.pumpAndSettle();
    final surfaces = find.descendant(
        of: find.byType(BeeBudgetEditorForm),
        matching: find.byType(BeeSurface));
    expect(t.getSize(find.byType(BeeBudgetEditorForm)).width, f['formWidth']);
    expect(t.getSize(surfaces.first).height, f['typeCardHeight']);
    expect(t.getSize(find.byType(TextField)).height, f['amountInputHeight']);
    expect(t.getSize(surfaces.last).height, closeTo(f['amountCardHeight'], .1));
    expect(t.getSize(find.byType(BeeButton)).height, f['saveButtonHeight']);
    expect(
        t
            .widget<FilledButton>(find.byType(FilledButton))
            .style!
            .minimumSize!
            .resolve({})!.height,
        f['saveVisualMinimumHeight']);
    // Frozen HTML uses a plain amount on the card surface. Resolve the global
    // filled-input theme too, so it cannot silently add a second gray plate.
    final decoration = t
        .widget<TextField>(find.byType(TextField))
        .decoration!
        .applyDefaults(
            Theme.of(t.element(find.byType(TextField))).inputDecorationTheme);
    expect(f['amountFieldFill'], 'surface');
    expect(decoration.filled, false);
    for (final border in [
      decoration.border,
      decoration.enabledBorder,
      decoration.focusedBorder,
      decoration.disabledBorder
    ]) {
      expect(border, InputBorder.none, reason: f['amountFieldBorders']);
    }
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
