import 'dart:convert';
import 'dart:io';
import 'package:beecount/pages/calendar/widgets/calendar_month_view.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('日历与HTML冻结宽度、行高和选择色 dark=$dark', (t) async {
      SharedPreferences.setMockInitialValues({});
      final f = jsonDecode(
          File('test/fixtures/v4-calendar-geometry.json').readAsStringSync());
      t.view.physicalSize = const Size(398, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(ProviderScope(
          child: MaterialApp(
              theme: beeTheme(
                  brightness: dark ? Brightness.dark : Brightness.light),
              home: Scaffold(
                  body: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 17),
                      child: CalendarMonthView(
                          focusedMonth: DateTime(2026, 10),
                          firstDay: DateTime(2000),
                          lastDay: DateTime(2027, 10, 20),
                          selectedDay: DateTime(2026, 10, 20),
                          totals: {'2026-10-20': (12000.0, 208.4)},
                          onSelect: (_, __) {},
                          onPage: (_) {},
                          onMonth: () {},
                          onJump: (_) {}))))));
      await t.pumpAndSettle();
      final card = find.byType(BeeSurface),
          header = find.byType(BeeCalendarMonthHeading),
          calendar = find.byWidgetPredicate((w) => w is TableCalendar),
          cell = find
              .byWidgetPredicate((w) => w is BeeCalendarDayCell && w.selected);
      expect(t.getSize(card).width, f['monthCardWidth']);
      expect(t.getSize(header).height, f['monthHeadingHeight']);
      final table = t.widget<TableCalendar<void>>(calendar);
      expect(table.rowHeight, f['rowHeight']);
      expect(table.daysOfWeekHeight, f['weekdayHeight']);
      expect(t.getSize(cell).height, f['rowHeight']);
      expect(t.getSize(cell).width, closeTo(f['dayColumnWidth'], .01));
      final box = t.widget<DecoratedBox>(
          find.descendant(of: cell, matching: find.byType(DecoratedBox)));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, Theme.of(t.element(cell)).colorScheme.primary);
      expect(decoration.borderRadius,
          BorderRadius.circular(f['dayRadius'].toDouble()));
      expect(t.takeException(), isNull);
    });
  }
}
