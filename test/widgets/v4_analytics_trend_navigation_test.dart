import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/main/analytics/bindings/analytics_data.dart';
import 'package:beecount/pages/main/analytics/widgets/analytics_trend.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 411.428571, 440.0]) {
    for (final language in ['zh', 'en']) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        testWidgets('趋势周期按钮无溢出 $width $language ${brightness.name}',
            (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final data = AnalyticsResult(
            categories: const [],
            series: [
              (day: DateTime(2026, 11, 1), total: 12000.0),
              (day: DateTime(2026, 11, 2), total: 1200.0),
              (day: DateTime(2026, 11, 3), total: 23.6),
            ],
            start: DateTime(2026, 11, 1),
            end: DateTime(2026, 11, 4),
            count: 3,
            total: 13223.6,
            average: 4407.8667,
            empty: false,
          );
          var previous = 0, next = 0;
          for (final scale in [1.0, 1.4]) {
            await tester.pumpWidget(MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: beeTheme(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(19),
                  child: AnalyticsTrend(
                    data: data,
                    scope: 'month',
                    title: language == 'en' ? 'Income trend' : '收入趋势',
                    unit: 'CNY',
                    averageLabel: 'Daily Avg ¥4,407.87',
                    formatValue: (value) => value.toStringAsFixed(2),
                    onAverage: () {},
                    onPrevious: () => previous++,
                    onNext: () => next++,
                  ),
                ),
              ),
            ));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final context = tester.element(find.byType(AnalyticsTrend));
            final l = AppLocalizations.of(context);
            await tester.tap(find.byTooltip(l.v4InsightsPreviousPeriod));
            await tester.tap(find.byTooltip(l.v4InsightsNextPeriod));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          expect(previous, 2);
          expect(next, 2);
        });
      }
    }
  }
}
