import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/net_worth_trend_page.dart';
import 'package:beecount/pages/account/net_worth/bindings/net_worth_trend.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends LocalRepository {
  _Repository(super.db);
  bool fail = false;
  final requests = <({DateTime startDate, DateTime endDate})>[];
  @override
  Future<List<({DateTime date, double assets, double liabilities, double net})>>
      getNetWorthTrendSeries(
          {required DateTime startDate,
          required DateTime endDate,
          required Map<String, double> ratesToBase}) {
    requests.add((startDate: startDate, endDate: endDate));
    if (fail) {
      fail = false;
      throw StateError('合成读取失败');
    }
    return super.getNetWorthTrendSeries(
        startDate: startDate, endDate: endDate, ratesToBase: ratesToBase);
  }
}

void main() {
  late BeeDatabase db;
  late _Repository repo;
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'人民币','CNY'),(2,'美元账本','USD')");
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo)
    ]);
    container.read(currentLedgerIdProvider.notifier).state = 2;
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> fixture() async {
    await db.customStatement(
        "INSERT INTO accounts(id,ledger_id,name,type,currency,initial_balance) VALUES(1,1,'现金','cash','CNY',1000),(2,1,'美元卡','bank_card','USD',100),(3,1,'信用卡','credit_card','CNY',-300),(4,1,'欧元','cash','EUR',50)");
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7');
    final now = DateTime.now();
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 100,
        accountId: 1,
        happenedAt: DateTime(now.year, now.month - 1, 2));
    await repo.addTransaction(
        ledgerId: 1,
        type: 'income',
        amount: 10,
        accountId: 2,
        currencyCode: 'USD',
        nativeAmount: 10,
        happenedAt: DateTime(now.year, now.month, 2));
  }

  Future<void> open(WidgetTester t, {bool compact = false}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = compact ? const Size(320, 568) : const Size(398, 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(
                brightness: compact ? Brightness.dark : Brightness.light),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(compact ? 1.4 : 1)),
                child: child!),
            home: const NetWorthTrendPage())));
    await t.pumpAndSettle();
  }

  testWidgets('真实跨币种仓库、缺汇率剔除，币种符号不受美元账本影响', (t) async {
    await fixture();
    await open(t);
    expect(container.read(currentLedgerIdProvider), 2);
    final chart = t.widget<BeeLineChart>(find.byType(BeeLineChart));
    // 现金900 + 美元110×7 − 信用卡300 = 1370；EUR无汇率不计入。
    expect(chart.values.last, 1370);
    final hero = t.widget<BeeResourceHero>(find.byType(BeeResourceHero));
    expect(hero.amount, '¥1,370');
    expect(hero.caption, 'CNY · 12个月');
    expect(hero.metrics.first.value, '¥1,400');
    expect(hero.metrics[1].value, '¥-30');
    expect(hero.metrics.last.value, '-2.1%');
    expect(find.textContaining('按当前汇率折算为主币种'), findsOneWidget);
    expect(await db.customSelect('SELECT * FROM transactions').get(),
        hasLength(2));
    expect(await db.customSelect('SELECT * FROM accounts').get(), hasLength(4));
  });
  testWidgets('原三条线和四个时间范围，默认12个月；全部从最早交易月初起', (t) async {
    await fixture();
    await open(t);
    for (final row in [('总资产', 1670.0), ('总负债', -300.0), ('净资产', 1370.0)]) {
      await t.ensureVisible(find.byType(BeeSegmented<NetWorthLine>));
      await t.tap(find.descendant(
          of: find.byType(BeeSegmented<NetWorthLine>),
          matching: find.text(row.$1)));
      await t.pumpAndSettle();
      expect(t.widget<BeeLineChart>(find.byType(BeeLineChart)).values.last,
          row.$2);
    }
    final now = DateTime.now();
    for (final row in [('3个月', 2), ('6个月', 5), ('12个月', 11), ('全部', 1)]) {
      await t.ensureVisible(find.byType(BeeFilterBar));
      await t.tap(find.text(row.$1));
      await t.pumpAndSettle();
      expect(
          repo.requests.any(
              (r) => r.startDate == DateTime(now.year, now.month - row.$2, 1)),
          isTrue);
      expect(
          t
              .widget<V4NetWorthTrendContent>(
                  find.byType(V4NetWorthTrendContent))
              .range
              .label(AppLocalizations.of(
                  t.element(find.byType(NetWorthTrendPage)))),
          row.$1);
      expect(
          repo.requests.last.endDate, DateTime(now.year, now.month, now.day));
    }
  });
  testWidgets('空数据仍能选择范围，读取失败后生产重试恢复', (t) async {
    repo.fail = true;
    await open(t);
    expect(find.byType(BeeStatus), findsOneWidget);
    await t.tap(find.text('重试'));
    await t.pumpAndSettle();
    expect(find.byType(BeeEmptyState), findsOneWidget);
    await t.tap(find.text('3个月'));
    await t.pumpAndSettle();
    expect(
        repo.requests.last.startDate, NetWorthRange.m3.dates(null).startDate);
    expect(t.takeException(), isNull);
  });
  testWidgets('320深色140%滚动切线与共享金额隐藏，不泄漏摘要/比例/标注', (t) async {
    await fixture();
    await open(t, compact: true);
    await t.tap(find.byTooltip('隐藏金额'));
    await t.pumpAndSettle();
    expect(container.read(hideAmountsProvider), isTrue);
    final hero = t.widget<BeeResourceHero>(find.byType(BeeResourceHero));
    expect(hero.amount, '••••');
    expect(hero.metrics, hasLength(2));
    expect(hero.metrics.every((v) => v.value == '••••'), isTrue);
    expect(
        t.widget<BeeLineChart>(find.byType(BeeLineChart)).hideAmounts, isTrue);
    await t.ensureVisible(find.byType(BeeSegmented<NetWorthLine>));
    await t.tap(find.descendant(
        of: find.byType(BeeSegmented<NetWorthLine>),
        matching: find.text('总负债')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.byTooltip('显示金额'));
    await t.pumpAndSettle();
    expect(container.read(hideAmountsProvider), isFalse);
  });
  testWidgets('真实期初零不显示误导变化比例，负债仍保留自然负号', (t) async {
    final id = await repo.createAccount(ledgerId: 1, name: '零余额');
    await repo.addTransaction(
        ledgerId: 1,
        type: 'income',
        amount: 10,
        accountId: id,
        happenedAt: DateTime.now());
    await open(t);
    final hero = t.widget<BeeResourceHero>(find.byType(BeeResourceHero));
    expect(hero.metrics.first.value, '¥0');
    expect(hero.metrics, hasLength(2));
    expect(hero.amount, '¥10');
    await t.pump(const Duration(seconds: 2));
  });
  testWidgets('320大字高额摘要在卡片内保持单行，货币符号不单独折行', (t) async {
    await fixture();
    await db.customStatement(
        'UPDATE accounts SET initial_balance=125000000 WHERE id=1');
    await open(t, compact: true);
    final value = find.text('¥125,000,400');
    expect(value, findsOneWidget);
    final paragraph = t.renderObject<RenderParagraph>(value);
    expect(
        paragraph.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 12)),
        hasLength(1));
    final box = t.getRect(value),
        hero = t.getRect(find.byType(BeeResourceHero));
    expect(box.left, greaterThanOrEqualTo(hero.left + 15));
    expect(box.right, lessThanOrEqualTo(hero.right - 15));
    expect(t.takeException(), isNull);
  });
  test('无交易全部范围回退12月', () {
    expect(NetWorthRange.all.dates(null), NetWorthRange.m12.dates(null));
  });
}
