import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/shared/branding/bee_artwork.dart';
import 'package:beecount/pages/main/home/bindings/transaction_list.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester t, Widget child,
      {Brightness brightness = Brightness.light,
      double scale = 1,
      bool settle = true}) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: beeTheme(brightness: brightness),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(body: SizedBox(height: 180, child: child))))));
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('真实空列表复用BeeEmptyState，保留文案品牌并支持小屏大字 $brightness', (t) async {
      await open(
          t,
          const TransactionList(
              transactionsWithDetails: [], hideAmounts: false),
          brightness: brightness,
          scale: 1.4);
      final l = AppLocalizations.of(t.element(find.byType(TransactionList)));
      expect(find.byType(BeeEmptyState), findsOneWidget);
      expect(find.text(l.commonEmpty), findsOneWidget);
      expect(find.text(l.homeNoRecords), findsOneWidget);
      expect(t.widget<BeeIcon>(find.byType(BeeIcon)).size, 52);
      expect(t.getSize(find.byType(TransactionList)).height, 180);
      await t.ensureVisible(find.text(l.homeNoRecords));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('自定义空态操作仍直达，加载和失败不被空态遮盖', (t) async {
    var tapped = 0, retried = 0;
    await open(
        t,
        TransactionList(
            transactionsWithDetails: const [],
            hideAmounts: false,
            emptyWidget: BeeEmptyState(
                title: '没有搜索结果',
                action: TextButton(
                    onPressed: () => tapped++, child: const Text('重新搜索')))));
    await t.ensureVisible(find.text('重新搜索'));
    await t.tap(find.text('重新搜索'));
    expect(tapped, 1);
    await open(
        t,
        const TransactionList(
            transactionsWithDetails: [],
            hideAmounts: false,
            sourceReady: false),
        settle: false);
    expect(find.byType(BeeEmptyState), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await open(
        t,
        TransactionList(
            transactionsWithDetails: const [],
            hideAmounts: false,
            sourceError: StateError('synthetic'),
            onRetrySource: () => retried++));
    final l = AppLocalizations.of(t.element(find.byType(TransactionList)));
    expect(find.byType(BeeEmptyState), findsNothing);
    await t.tap(find.text(l.v4RecordingRetry));
    expect(retried, 1);
    expect(t.takeException(), isNull);
  });
}
