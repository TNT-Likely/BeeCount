import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart'
    show
        BeeCategoryChoice,
        BeeCategoryPicker,
        RecordingCategoryTile,
        RecordingSubcategoryChip;
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<BeeCategoryChoice> choices({bool parentEnabled = false}) => List.generate(
    36,
    (i) => BeeCategoryChoice(
            id: 'p$i',
            label: '父类${i.toString().padLeft(2, '0')}',
            icon: const Icon(Icons.category_outlined, size: 18),
            enabled: parentEnabled,
            detail: '$i笔',
            children: [
              BeeCategoryChoice(
                  id: 'c$i',
                  label: i == 7 ? 'Nectar子类' : '子类$i',
                  icon: const Icon(Icons.local_cafe_outlined, size: 18),
                  detail: '${i + 1}笔'),
              BeeCategoryChoice(
                  id: 'blocked$i',
                  label: '禁用$i',
                  icon: const Icon(Icons.block, size: 18),
                  enabled: false)
            ]));

Finder parent(int i) => find.widgetWithText(
    RecordingCategoryTile, '父类${i.toString().padLeft(2, '0')}');
Finder chip(String text) => find.widgetWithText(RecordingSubcategoryChip, text);

void main() {
  String? result;
  var confirms = 0, cancels = 0;

  Future<void> open(WidgetTester t,
      {bool immediate = true,
      bool expandAll = false,
      bool parentEnabled = false,
      String? selected = 'c8',
      double scale = 1,
      Brightness brightness = Brightness.light}) async {
    result = null;
    confirms = cancels = 0;
    await t.pumpWidget(MaterialApp(
      theme: beeTheme(brightness: brightness),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () async {
                    result = await showDialog<String>(
                        context: context,
                        builder: (context) => BeeDialog(
                            title: const Text('选择分类'),
                            content: SizedBox(
                                width: double.maxFinite,
                                height: math.min(440,
                                    MediaQuery.sizeOf(context).height * .62),
                                child: BeeCategoryPicker(
                                    items:
                                        choices(parentEnabled: parentEnabled),
                                    selected: selected,
                                    immediate: immediate,
                                    expandAllChildren: expandAll,
                                    searchLabel: '搜索分类',
                                    emptyLabel: '没有分类',
                                    confirmLabel: '确认分类',
                                    cancelLabel: '取消分类',
                                    onConfirm: (value) {
                                      confirms++;
                                      Navigator.pop(context, value);
                                    },
                                    onCancel: () {
                                      cancels++;
                                      Navigator.pop(context);
                                    }))));
                  },
                  child: const Text('打开分类')))),
    ));
    await t.tap(find.text('打开分类'));
    await t.pumpAndSettle();
  }

  void narrow(WidgetTester t) {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 568);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
  }

  for (final scale in [1.0, 1.4]) {
    testWidgets(
        '36 parents first-row child can be tapped without scrolling $scale',
        (t) async {
      narrow(t);
      await open(t,
          scale: scale,
          brightness: scale == 1.4 ? Brightness.dark : Brightness.light);
      final scroll = t.state<ScrollableState>(find.byType(Scrollable).last);
      expect(scroll.position.pixels, 0);
      expect(scroll.position.maxScrollExtent, greaterThan(500));
      await t.tap(parent(0));
      await t.pumpAndSettle();
      expect(confirms, 0); // Disabled parent remains navigable.
      expect(chip('子类0').hitTestable(), findsOneWidget);
      expect(t.getBottomLeft(chip('子类0')).dy,
          lessThan(t.getTopLeft(parent(4)).dy));
      expect(scroll.position.pixels, 0);
      await t.tap(chip('子类0'));
      await t.pumpAndSettle();
      expect(result, 'c0');
      expect(confirms, 1);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('another parent in the same row expands before the next row',
      (t) async {
    narrow(t);
    await open(t, selected: null);
    await t.tap(parent(3));
    await t.pumpAndSettle();
    expect(chip('子类0'), findsNothing);
    expect(chip('子类3').hitTestable(), findsOneWidget);
    expect(
        t.getBottomLeft(chip('子类3')).dy, lessThan(t.getTopLeft(parent(4)).dy));
    await t.tap(chip('子类3'));
    await t.pumpAndSettle();
    expect(result, 'c3');
  });

  testWidgets(
      'default first group keeps disabled direct parent and child eligibility',
      (t) async {
    narrow(t);
    final semantics = t.ensureSemantics();
    await open(t, selected: null);
    expect(chip('子类0').hitTestable(), findsOneWidget);
    expect(t.widget<RecordingSubcategoryChip>(chip('父类00')).onTap, isNull);
    expect(t.widget<RecordingSubcategoryChip>(chip('禁用0')).onTap, isNull);
    expect(t.getSemantics(chip('禁用0')).hasFlag(ui.SemanticsFlag.isEnabled),
        isFalse);
    await t.tap(chip('禁用0'));
    await t.pumpAndSettle();
    expect(result, isNull);
    expect(confirms, 0);
    await t.tap(chip('子类0'));
    await t.pumpAndSettle();
    expect(result, 'c0');
    semantics.dispose();
  });

  testWidgets(
      'enabled direct parent still confirms immediately from its child block',
      (t) async {
    narrow(t);
    await open(t, parentEnabled: true, selected: null);
    await t.tap(parent(0));
    await t.pumpAndSettle();
    expect(confirms, 0);
    await t.tap(chip('父类00'));
    await t.pumpAndSettle();
    expect(result, 'p0');
    expect(confirms, 1);
  });

  testWidgets(
      'non-immediate mode stages child until confirm and cancel keeps original',
      (t) async {
    narrow(t);
    await open(t, immediate: false, selected: null);
    await t.tap(chip('子类0'));
    await t.pumpAndSettle();
    expect(confirms, 0);
    await t.tap(find.text('确认分类'));
    await t.pumpAndSettle();
    expect(result, 'c0');
    await open(t, immediate: false, selected: null);
    await t.tap(chip('子类0'));
    await t.pumpAndSettle();
    await t.tap(find.text('取消分类'));
    await t.pumpAndSettle();
    expect(result, isNull);
    expect(confirms, 0);
    expect(cancels, 1);
  });

  testWidgets('expand-all retains all original groups after the parent grid',
      (t) async {
    narrow(t);
    await open(t, expandAll: true);
    expect(find.byType(RecordingSubcategoryChip), findsNWidgets(36 * 3));
    expect(t.getTopLeft(chip('子类0')).dy,
        greaterThan(t.getBottomLeft(parent(35)).dy));
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'child and parent search retain counts and only eligible matching choices',
      (t) async {
    narrow(t);
    await open(t);
    await t.enterText(find.byType(TextField), 'nEcTaR');
    await t.pumpAndSettle();
    expect(parent(7), findsOneWidget);
    expect(parent(0), findsNothing);
    expect(chip('Nectar子类').hitTestable(), findsOneWidget);
    expect(chip('禁用7'), findsNothing);
    expect(find.text('7笔'), findsNWidgets(2)); // Parent tile and direct choice.
    expect(find.text('8笔'), findsOneWidget);
    await t.enterText(find.byType(TextField), '父类07');
    await t.pumpAndSettle();
    expect(chip('禁用7'), findsOneWidget);
    await t.tap(chip('Nectar子类'));
    await t.pumpAndSettle();
    expect(result, 'c7');
  });

  testWidgets(
      'read-only audit: text-field role persists and set-text action requires focus',
      (t) async {
    narrow(t);
    final handle = t.ensureSemantics();
    await open(t);
    final field = find.byType(EditableText);
    expect(t.getSemantics(field).hasFlag(ui.SemanticsFlag.isTextField), isTrue);
    expect(
        t
            .getSemantics(field)
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.setText),
        isFalse);
    await t.tap(find.byType(TextField));
    await t.pumpAndSettle();
    expect(t.getSemantics(field).hasFlag(ui.SemanticsFlag.isFocused), isTrue);
    expect(
        t
            .getSemantics(field)
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.setText),
        isTrue);
    await t.enterText(find.byType(TextField), 'Nectar');
    await t.pumpAndSettle();
    expect(parent(7), findsOneWidget);
    expect(t.takeException(), isNull);
    handle.dispose();
  });
}
