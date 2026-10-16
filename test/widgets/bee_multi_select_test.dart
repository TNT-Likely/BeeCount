import 'package:beecount/widgets/ui/bee_multi_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'multiple selections stay independent and input set remains untouched',
      (tester) async {
    final original = {'note'};
    Set<String> selected = original;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, setState) => BeeMultiSelect<String>(
          selectedValues: selected,
          options: const [
            BeeMultiSelectOption(value: 'note', label: '备注'),
            BeeMultiSelectOption(value: 'account', label: '账户'),
          ],
          onChanged: (value) => setState(() => selected = value)),
    ))));
    await tester.tap(find.text('账户'));
    await tester.pumpAndSettle();
    expect(selected, {'note', 'account'});
    expect(original, {'note'});
    await tester.tap(find.text('备注'));
    await tester.pumpAndSettle();
    expect(selected, {'account'});
    await tester.tap(find.text('账户'));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'capsules follow project colors and remain readable with large text: dark=$dark',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const primary = Color(0xFFF8C800);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
                colorSchemeSeed: primary)
            .copyWith(
                colorScheme: ColorScheme.fromSeed(
                        seedColor: primary,
                        brightness: dark ? Brightness.dark : Brightness.light)
                    .copyWith(primary: primary)),
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: BeeMultiSelect<String>(selectedValues: const {
                'note'
              }, options: const [
                BeeMultiSelectOption(value: 'note', label: '备注'),
                BeeMultiSelectOption(value: 'account', label: '账户'),
                BeeMultiSelectOption(value: 'ledger', label: '账本'),
              ], onChanged: null),
            )),
      ));
      final first = tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
      expect((first.decoration! as BoxDecoration).color,
          dark ? primary : Colors.black);
      expect(tester.takeException(), isNull);
      final semantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.checked != null);
      expect(semantics.first.properties.checked, isTrue);
      expect(semantics.first.properties.enabled, isFalse);
    });
  }
}
