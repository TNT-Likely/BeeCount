import 'dart:io';

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/widget_management_page.dart';
import 'package:beecount/presentation/v4/bindings/maintenance_access.dart';
import 'package:beecount/providers/font_scale_provider.dart';
import 'package:beecount/theme.dart';
import 'package:beecount/widget/views/glance_view.dart';
import 'package:beecount_business_ui/maintenance.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _canvasKey = ValueKey('glance-canvas');

GlanceView _glance(double height,
        {bool english = false, bool isolateTypography = true}) =>
    GlanceView.medium(
      isolatePreviewTypography: isolateTypography,
      todayExpense: '¥88.5',
      todayIncome: '¥0',
      monthExpense: '¥3,200.5',
      monthIncome: '¥8,000',
      themeColor: const Color(0xfffacb16),
      redForIncome: true,
      dark: false,
      titleLabel: english ? 'Income & expense' : '收支速览',
      monthSuffix: english ? ' month' : '月',
      todayExpenseLabel: english ? 'Today expense' : '今日支出',
      todayIncomeLabel: english ? 'Today income' : '今日收入',
      monthExpenseLabel: english ? 'Month expense' : '本月支出',
      monthIncomeLabel: english ? 'Month income' : '本月收入',
      width: 364,
      height: height,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Real SDK Roboto metrics, rather than the square Ahem test font. Locate
    // only the public Flutter SDK artifact relative to the test executable.
    var directory = File(Platform.resolvedExecutable).parent;
    while (!Directory('${directory.path}/material_fonts').existsSync() &&
        directory.parent.path != directory.path) {
      directory = directory.parent;
    }
    final loader = FontLoader('Roboto');
    for (final weight in ['Regular', 'Bold']) {
      final bytes =
          await File('${directory.path}/material_fonts/Roboto-$weight.ttf')
              .readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  testWidgets('182px canvas keeps the original 169px content on every host',
      (t) async {
    final canvas =
        SizedBox(key: _canvasKey, width: 364, height: 182, child: _glance(182));
    await t.pumpWidget(Directionality(
        textDirection: TextDirection.ltr, child: Center(child: canvas)));
    final canvasRect = t.getRect(find.byKey(_canvasKey));
    final content = find.descendant(
        of: find.byType(GlanceView),
        matching: find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).borderRadius ==
                BorderRadius.circular(16)));
    expect(t.getRect(content).top - canvasRect.top, 6.5);
    expect(t.getSize(content), const Size(364, 169));
    expect(t.takeException(), isNull);
  });

  testWidgets('headless callers retain deliberately supplied font defaults',
      (t) async {
    await t.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
            style: const TextStyle(fontFamily: 'Roboto'),
            child: Center(child: _glance(182, isolateTypography: false)))));
    expect(DefaultTextStyle.of(t.element(find.text('¥88.5'))).style.fontFamily,
        'Roboto');
    expect(t.takeException(), isNull);
  });

  for (final height in [169.0, 182.0]) {
    for (final english in [false, true]) {
      testWidgets(
          'glance $height en=$english isolates inherited app line height',
          (t) async {
        final canvas = SizedBox(
            key: _canvasKey,
            width: 364,
            height: height,
            child: _glance(height, english: english));
        await t.pumpWidget(MaterialApp(
            theme: applyBeeCardTheme(
                BeeTheme.lightTheme(platform: TargetPlatform.android)),
            home: Scaffold(
                body: DefaultTextStyle(
                    style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 24,
                        height: 1.8,
                        letterSpacing: 2),
                    child: Center(child: canvas)))));
        expect(t.takeException(), isNull);
        for (final value in ['¥88.5', '¥0', '¥3,200.5', '¥8,000']) {
          expect(find.text(value), findsOneWidget);
          final amount = t.getRect(find.text(value));
          final canvas = t.getRect(find.byKey(_canvasKey));
          expect(canvas.contains(amount.topLeft), isTrue);
          expect(canvas.contains(amount.bottomRight), isTrue);
        }
      });
    }
  }

  for (final width in [320.0, 406.0]) {
    for (final scale in [.9, 1.4]) {
      for (final english in [false, true]) {
        for (final brightness in Brightness.values) {
          testWidgets(
              'all nine real previews $width scale=$scale en=$english ${brightness.name}',
              (t) async {
            t.view.devicePixelRatio = 3;
            t.view.physicalSize = Size(width * 3, 900 * 3);
            addTearDown(t.view.resetDevicePixelRatio);
            addTearDown(t.view.resetPhysicalSize);
            final theme = brightness == Brightness.light
                ? BeeTheme.lightTheme(platform: TargetPlatform.android)
                : BeeTheme.darkTheme(platform: TargetPlatform.android);
            await t.pumpWidget(ProviderScope(
                overrides: [
                  effectiveFontScaleProvider.overrideWithValue(scale),
                  maintenancePlatformProvider
                      .overrideWithValue(TargetPlatform.android),
                ],
                child: MaterialApp(
                    locale: Locale(english ? 'en' : 'zh'),
                    theme: applyBeeCardTheme(theme),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: TextScaler.linear(scale)),
                        child: child!),
                    home: const WidgetManagementPage())));
            await t.pumpAndSettle();
            final cards = <String, Size>{};
            for (var step = 0; step < 40; step++) {
              for (final card in t.widgetList<BeeMaintenanceWidgetCard>(
                  find.byType(BeeMaintenanceWidgetCard))) {
                cards['${card.title}|${card.sizeLabel}'] = card.previewSize;
              }
              for (final element
                  in find.byType(BeeMaintenanceWidgetCard).evaluate()) {
                final card = element.widget as BeeMaintenanceWidgetCard;
                final preview = find.byWidget(card.preview);
                final frame = find
                    .ancestor(of: preview, matching: find.byType(FittedBox))
                    .first;
                final displaySize = t.getSize(frame);
                final isSmall = card.previewSize == const Size(155, 155);
                expect(displaySize.width,
                    lessThanOrEqualTo(isSmall ? 190.0 : 400.0));
                expect(t.getSize(preview), card.previewSize);
                if (!isSmall) expect(displaySize.width, greaterThan(190.0));
                expect(
                    find.descendant(
                        of: find.byWidget(card),
                        matching: find.text(
                            '${card.sizeLabel} · ${card.previewSize.width.toInt()}×${card.previewSize.height.toInt()}')),
                    findsOneWidget);
              }
              expect(t.takeException(), isNull);
              final position = t
                  .state<ScrollableState>(find.byType(Scrollable).first)
                  .position;
              if (position.pixels == position.maxScrollExtent) break;
              await t.drag(find.byType(ListView), const Offset(0, -600));
              await t.pumpAndSettle();
            }
            expect(cards, hasLength(9));
            expect(
                cards.values,
                containsAll([
                  const Size(155, 155),
                  const Size(364, 169),
                  const Size(364, 382)
                ]));
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox.shrink());
            await t.pump();
          });
        }
      }
    }
  }
}
