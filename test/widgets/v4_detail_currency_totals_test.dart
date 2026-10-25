import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/tag/tag_detail_page.dart';
import 'package:beecount/pages/transaction/category_detail_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_business_ui/detail_currency.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  late int category, tag;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'人民币','CNY'),(2,'美元','USD')");
    category = await repo.createCategory(name: '餐饮', kind: 'expense');
    tag = await repo.createTag(name: '旅行');
    for (final data in [
      (1, 10.0, 'CNY', 10.0),
      (2, 16.0, 'EUR', 20.0),
      (1, 12.0, 'USD', 85.2)
    ]) {
      final id = await repo.addTransaction(
          ledgerId: data.$1,
          type: 'expense',
          amount: data.$2,
          currencyCode: data.$3,
          nativeAmount: data.$4,
          categoryId: category,
          happenedAt: DateTime(2026, 10, 24));
      await repo.addTagToTransaction(transactionId: id, tagId: tag);
    }
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      currentLedgerProvider.overrideWith(
          (ref) => repo.watchLedger(ref.watch(currentLedgerIdProvider))),
      accountFeatureEnabledProvider.overrideWith((ref) async => true),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> open(WidgetTester t, bool isTag) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.4)),
                child: child!),
            home: isTag
                ? TagDetailPage(tagId: tag, tagName: '旅行', allLedgers: true)
                : CategoryDetailPage(
                    categoryId: category,
                    categoryName: '餐饮',
                    allLedgers: true))));
    await t.pumpAndSettle();
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
  }

  BeeResourceHero hero(WidgetTester t) =>
      t.widget<BeeResourceHero>(find.byType(BeeResourceHero));
  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(BeeResourceHero)));
  for (final isTag in [false, true]) {
    final page = isTag ? '标签' : '分类';
    testWidgets('$page当前目标和汇率自动投影，行原币/旧快照不变且无写入', (t) async {
      await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.1');
      final before = await db.select(db.transactions).get();
      await open(t, isTag);
      expect(hero(t).amount, '237.20');
      expect(hero(t).prefix, '¥');
      expect(find.text(l(t).v4DetailConvertedScope('CNY')), findsOneWidget);
      await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.2');
      container.read(rateRefreshTickProvider.notifier).state++;
      await t.pumpAndSettle();
      expect(hero(t).amount, '239.20');
      container.read(currentLedgerIdProvider.notifier).state = 2;
      await t.pumpAndSettle();
      expect(hero(t).prefix, r'US$');
      expect(hero(t).amount, closeDisplay(20 + 95.2 / 7.2));
      expect(find.text(l(t).v4DetailConvertedScope('USD')), findsOneWidget);
      await t.drag(find.byType(ListView).first, const Offset(0, -1700));
      await t.pumpAndSettle();
      final rows =
          t.widgetList<BeeTransactionRow>(find.byType(BeeTransactionRow));
      expect(
          rows.any((r) =>
              r.amount.contains(r'US$12.00') && r.converted == '≈ ¥85.20'),
          isTrue);
      expect(await db.select(db.transactions).get(), before);
      expect(t.takeException(), isNull);
      await close(t);
    });
    testWidgets('$page缺汇率保留明细和笔数，主金额/均值/份额不伪装完整', (t) async {
      await open(t, isTag);
      expect(hero(t).amount, '—');
      expect(hero(t).prefix, '');
      expect(
          find.text(l(t).v4DetailMissingConversion(1, 'USD')), findsOneWidget);
      if (!isTag) {
        expect(hero(t).metrics[1].value, '—');
        expect(hero(t).metrics[2].value, '—');
        expect(t.widget<BeeResourceTrend>(find.byType(BeeResourceTrend)).values,
            isEmpty);
      }
      await t.drag(find.byType(ListView).first, const Offset(0, -1700));
      await t.pumpAndSettle();
      expect(find.byType(BeeTransactionRow), findsNWidgets(3));
      expect(t.takeException(), isNull);
      await close(t);
    });
    testWidgets('$page隐私保留缺项状态，隐藏汇总及原币快照金额', (t) async {
      container.read(hideAmountsProvider.notifier).state = true;
      await open(t, isTag);
      expect(hero(t).amount, '••••');
      expect(
          find.text(l(t).v4DetailMissingConversion(1, 'USD')), findsOneWidget);
      await t.drag(find.byType(ListView).first, const Offset(0, -1700));
      await t.pumpAndSettle();
      for (final row
          in t.widgetList<BeeTransactionRow>(find.byType(BeeTransactionRow))) {
        expect(row.hidden, isTrue);
      }
      expect(find.textContaining('237.20'), findsNothing);
      expect(find.textContaining('85.20'), findsNothing);
      expect(find.textContaining('12.00'), findsNothing);
      expect(t.takeException(), isNull);
      await close(t);
    });
  }
  testWidgets('陈旧汇率日期明确展示，readonly提示支持320及2倍系统文字', (t) async {
    await repo.upsertAutoRates(
        base: 'CNY',
        rateDate: '2020-01-01',
        rates: {'USD': '7.1'},
        source: 'fixture',
        fetchedAt: DateTime(2026, 10, 24));
    await open(t, true);
    expect(hero(t).amount, '237.20');
    expect(find.text(l(t).v4DetailRatesStale('2020-01-01')), findsOneWidget);
    await close(t);
    for (final scale in [1.4, 2.0]) {
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: Scaffold(
              body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: const SingleChildScrollView(
                      child: SizedBox(
                          width: 286,
                          child: BeeDetailCurrencyNotice(
                              scopeLabel: '已按当前账本币种 CNY 汇总',
                              missingLabel:
                                  '12 笔未折算 · USD / EUR / 未知账本，暂不显示汇总金额',
                              rateDateLabel: '汇率已超过 7 天 · 2020-01-01',
                              stale: true)))))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
}

String closeDisplay(double amount) => amount.toStringAsFixed(2);
