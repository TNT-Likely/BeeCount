import 'dart:io';
import 'dart:ui' as ui;

import 'package:beecount_business_ui/cloud_shared.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _options = {24: '1 day', 72: '3 days', 168: '7 days'};

BeeCloudSharedInviteForm _form({
  int selected = 24,
  bool busy = false,
  required ValueChanged<int> onExpiry,
  VoidCallback? onGenerate,
}) =>
    BeeCloudSharedInviteForm(
        roleLabel: 'Role',
        role: 'Editor',
        expiryLabel: 'Expires in',
        expiryOptions: _options,
        selectedHours: selected,
        onExpiry: onExpiry,
        generateLabel: 'Generate invite',
        onGenerate: onGenerate ?? () {},
        warning: 'Keep your invite private.',
        busy: busy);

Finder _chip(int hours) => find.widgetWithText(BeeChoiceChip, _options[hours]!);

Material _visual(WidgetTester tester, int hours) =>
    tester.widget<Material>(find.descendant(
        of: _chip(hours),
        matching: find.byKey(const ValueKey('bee-choice-chip-visual'))));

Widget _host(Widget child,
    {required Brightness brightness, required Color accent, double scale = 1}) {
  final theme = beeTheme(brightness: brightness, accent: accent);
  return MaterialApp(
      theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'InviteCompactRoboto')),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(17), child: child)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Actual Flutter Roboto metrics avoid Ahem changing wrap geometry.
    var directory = File(Platform.resolvedExecutable).parent;
    while (!Directory('${directory.path}/material_fonts').existsSync() &&
        directory.parent.path != directory.path) {
      directory = directory.parent;
    }
    final loader = FontLoader('InviteCompactRoboto');
    for (final weight in ['Regular', 'Bold']) {
      final bytes =
          await File('${directory.path}/material_fonts/Roboto-$weight.ttf')
              .readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  final themes = [
    (Brightness.light, const Color(0xfffacb16)),
    (Brightness.dark, const Color(0xff219670)),
  ];
  for (final (brightness, accent) in themes) {
    for (final width in [320.0, 406.0]) {
      for (final scale in [1.0, 1.4]) {
        testWidgets('邀请compact主题14%与短屏几何 $brightness $width $scale',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 360);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(_host(_form(onExpiry: (_) {}),
              brightness: brightness, accent: accent, scale: scale));
          await tester.pumpAndSettle();
          expect(find.byType(ChoiceChip), findsNothing);
          expect(find.byType(BeeChoiceChip), findsNWidgets(3));
          expect(_visual(tester, 24).color, accent.withValues(alpha: .14));
          final shape = _visual(tester, 24).shape! as RoundedRectangleBorder;
          expect(shape.side.color, accent);
          expect(shape.borderRadius, BorderRadius.circular(10));
          for (final hours in _options.keys) {
            final chip = tester.widget<BeeChoiceChip>(_chip(hours));
            expect(chip.compact, isTrue);
            expect(chip.selected, hours == 24);
            final rect = tester.getRect(_chip(hours));
            expect(rect.height, greaterThanOrEqualTo(44));
            expect(rect.width, greaterThanOrEqualTo(44));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
            final visualSize = tester.getSize(find.descendant(
                of: _chip(hours),
                matching:
                    find.byKey(const ValueKey('bee-choice-chip-visual'))));
            expect(visualSize.height, greaterThanOrEqualTo(34));
            if (scale == 1) expect(visualSize.height, 34);
            final text = tester.widget<Text>(find.descendant(
                of: _chip(hours), matching: find.text(_options[hours]!)));
            expect(text.style!.fontSize, 11);
            expect(text.style!.height, 1.5);
            if (hours != 24) {
              expect(_visual(tester, hours).color,
                  BeeCardTheme.fromBrightness(brightness).soft);
            }
          }
          if (scale == 1) {
            expect(tester.getTopLeft(_chip(24)).dy,
                tester.getTopLeft(_chip(72)).dy);
            expect(tester.getTopLeft(_chip(72)).dy,
                tester.getTopLeft(_chip(168)).dy);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
    testWidgets('邀请不置空且busy无回调与checked语义 $brightness', (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = 24, busy = false, generated = 0;
      final events = <int>[];
      late StateSetter update;
      try {
        await tester
            .pumpWidget(_host(StatefulBuilder(builder: (context, setState) {
          update = setState;
          return _form(
              selected: selected,
              busy: busy,
              onExpiry: (hours) {
                events.add(hours);
                setState(() => selected = hours);
              },
              onGenerate: () => generated++);
        }), brightness: brightness, accent: accent));
        await tester.pumpAndSettle();
        expect(
            tester.getSemantics(_chip(24)).hasFlag(ui.SemanticsFlag.isChecked),
            isTrue);
        expect(
            tester.getSemantics(_chip(24)).hasFlag(ui.SemanticsFlag.isSelected),
            isFalse);
        await tester.tap(_chip(24));
        await tester.pump();
        expect(events, isEmpty);
        expect(selected, 24);
        for (final hours in [72, 168, 24]) {
          await tester.tap(_chip(hours));
          await tester.pump();
          expect(selected, hours);
          expect(events.last, hours);
          expect(
              tester
                  .widgetList<BeeChoiceChip>(find.byType(BeeChoiceChip))
                  .where((chip) => chip.selected),
              hasLength(1));
          await tester.tap(_chip(hours));
          await tester.pump();
          expect(events.length, [72, 168, 24].indexOf(hours) + 1);
        }
        update(() => busy = true);
        await tester.pump();
        final calls = events.length;
        for (final hours in _options.keys) {
          expect(tester.widget<BeeChoiceChip>(_chip(hours)).onSelected, isNull);
          expect(
              tester
                  .getSemantics(_chip(hours))
                  .hasFlag(ui.SemanticsFlag.isEnabled),
              isFalse);
          await tester.tap(_chip(hours));
        }
        await tester.tap(find.text('Generate invite'));
        await tester.pump();
        expect(events, hasLength(calls));
        expect(generated, 0);
        expect(selected, 24);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}
