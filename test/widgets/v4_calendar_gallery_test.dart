import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/presentation/v4/gallery/calendar_sample.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('暂停目录时年月操作仍真正移动日历页，不只替换标题', (t) async {
    t.view.physicalSize = const Size(398, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
      theme: beeTheme(),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: TickerMode(
          enabled: false,
          child: SingleChildScrollView(child: CalendarSample()),
        ),
      ),
    ));
    await t.pumpAndSettle();
    final view = find.byType(PageView);
    final before = t.widget<PageView>(view).controller!.page!;
    await t.tap(find.byTooltip('2026年9月'));
    await t.pumpAndSettle();
    expect(find.text('2026年9月'), findsOneWidget);
    expect(t.widget<PageView>(view).controller!.page, before - 1);
    expect(t.takeException(), isNull);
  });
}
