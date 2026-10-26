import 'package:beecount/data/db.dart';
import 'package:beecount/presentation/v4/bindings/account_detail_controller.dart';
import 'package:beecount/services/currency/exchange_rate_service.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/account_detail_page.dart';
import 'package:beecount/pages/account/accounts_page.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/presentation/v4/bindings/account_detail.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LocalRates extends ExchangeRateService {
  @override
  Future<RateFetchResult> fetch(String base) async => RateFetchResult(
      rateDate: '2026-10-26',
      source: 'synthetic-widget-transport',
      ratesBaseToQuote:
          base == 'CNY' ? {'USD': '0.1408450704'} : {'CNY': '7.1'});
}

class AccountDetailTestRepository extends LocalRepository {
  AccountDetailTestRepository(super.db);
  bool failPageOnce = false;
  @override
  Future<List<Transaction>> getAccountTransactions(int id,
      {int limit = 50,
      int offset = 0,
      String? flow,
      DateTime? startDate,
      DateTime? endExclusive,
      String query = '',
      bool ascending = false,
      bool orderByAmount = false}) {
    if (failPageOnce) {
      failPageOnce = false;
      throw StateError('Synthetic page error');
    }
    return super.getAccountTransactions(id,
        limit: limit,
        offset: offset,
        flow: flow,
        startDate: startDate,
        endExclusive: endExclusive,
        query: query,
        ascending: ascending,
        orderByAmount: orderByAmount);
  }
}

void main() {
  late BeeDatabase db;
  late AccountDetailTestRepository repo;
  late ProviderContainer container;
  late int cash, bank, food, salary;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = AccountDetailTestRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'日常生活','CNY'),(2,'旅行','USD')");
    cash = await repo.createAccount(
        ledgerId: 1, name: '日常现金', initialBalance: 1000);
    bank =
        await repo.createAccount(ledgerId: 1, name: '银行卡', type: 'bank_card');
    food = await repo.createCategory(name: '餐饮', kind: 'expense');
    salary = await repo.createCategory(name: '工资', kind: 'income');
    container = ProviderContainer(overrides: [
      exchangeRateServiceProvider.overrideWithValue(_LocalRates()),
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo)
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<int> tx(
          {required String type,
          required double amount,
          int? from,
          int? to,
          int ledger = 1,
          String currency = 'CNY',
          double? native,
          int? category,
          String? note,
          DateTime? at}) =>
      repo.addTransaction(
          ledgerId: ledger,
          type: type,
          amount: amount,
          accountId: from,
          toAccountId: to,
          currencyCode: currency,
          nativeAmount: native,
          categoryId: category,
          note: note,
          happenedAt: at ?? DateTime(2026, 10, 24, 12, 34, 56));
  AccountDetailController model(WidgetTester tester) =>
      (tester.state(find.byType(AccountDetailPage)) as dynamic).c
          as AccountDetailController;
  Future<void> waitLoaded(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && model(tester).loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, int id,
      {double scale = 1, Size size = const Size(398, 844)}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final account = (await repo.getAccount(id))!;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(
                brightness: scale > 1 ? Brightness.dark : Brightness.light),
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
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    AccountDetailPage(account: account))),
                        child: const Text('打开真实账户')))))));
    await tester.tap(find.text('打开真实账户'));
    await tester.pumpAndSettle();
    await waitLoaded(tester);
    await tester
        .runAsync(() => container.read(accountDetailReferencesProvider.future));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  List<BeeTransactionRow> rows(WidgetTester tester) => tester
      .widgetList<BeeTransactionRow>(find.byType(BeeTransactionRow))
      .toList();

  testWidgets('账户余额与原币流水一致，转入转出保留方向、来源账本、时间、真实标签附件', (tester) async {
    await tx(type: 'income', amount: 100, from: cash, category: salary);
    final id = await tx(
        type: 'expense', amount: 32, from: cash, category: food, note: '午餐');
    await tx(type: 'transfer', amount: 20, from: cash, to: bank);
    await tx(type: 'transfer', amount: 10, from: bank, to: cash);
    final tag = await repo.createTag(name: '工作日', color: '#219c9c');
    await repo.updateTransactionTags(transactionId: id, tagIds: [tag]);
    await repo.createAttachment(
        transactionId: id, fileName: 'synthetic.png', fileSize: 20);
    final before = await repo.getTransactionsByLedger(1);
    await open(tester, cash);
    expect(
        tester
            .widget<BeeAccountSummaryCard>(find.byType(BeeAccountSummaryCard))
            .amount,
        '1,058.00');
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();
    final visible = rows(tester);
    expect(visible.any((r) => r.amount == '−¥20.00'), isTrue);
    expect(visible.any((r) => r.amount == '+¥10.00'), isTrue);
    final expense = visible.singleWhere((r) => r.amount == '−¥32.00');
    expect(expense.tags.single.label, '工作日');
    expect(expense.attachmentCount, 1);
    expect(expense.ledgerName, '日常生活');
    expect(expense.showFullDate, isTrue);
    expect(await repo.getTransactionsByLedger(1), before);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('信用卡欠款、溢缴款、未设额度均有还款入口且目标身份不丢', (tester) async {
    for (final sample in [
      (
        balance: -3200.0,
        limit: 20000.0,
        label: '当前欠款',
        available: '¥16,800.00'
      ),
      (balance: 500.0, limit: 20000.0, label: '溢缴款', available: '¥20,500.00'),
      (balance: -800.0, limit: null, label: '当前欠款', available: null)
    ]) {
      final id = await repo.createAccount(
          ledgerId: 1,
          name: '信用卡${sample.balance}',
          type: 'credit_card',
          initialBalance: sample.balance,
          creditLimit: sample.limit,
          billingDay: 12,
          paymentDueDay: 28);
      await open(tester, id);
      final hero = tester
          .widget<BeeAccountSummaryCard>(find.byType(BeeAccountSummaryCard));
      expect(hero.balanceLabel, sample.label);
      if (sample.available != null) {
        expect(find.textContaining(sample.available!), findsOneWidget);
      } else {
        expect(find.byType(BeeCreditCardTerms), findsOneWidget);
      }
      await tester.ensureVisible(find.text('记一笔还款'));
      await tester.tap(find.text('记一笔还款'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TransactionEditorPage>(find.byType(TransactionEditorPage))
              .initialToAccountId,
          id);
      expect(await repo.getTransactionsByLedger(1), isEmpty);
      expect(tester.takeException(), isNull);
      await close(tester);
    }
  });

  testWidgets('贷款更新保留弹窗，拒绝非有限数，取消无写入，保存为负值且不生成交易', (tester) async {
    final id = await repo.createAccount(
        ledgerId: 1, name: '住房贷款', type: 'loan', initialBalance: -120000);
    await open(tester, id);
    expect(find.byType(BeeSegmented<String>), findsNothing);
    await tester.tap(find.text('更新欠款'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'NaN');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.text('请输入有效金额'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect((await repo.getAccount(id))!.initialBalance, -120000);
    await tester.tap(find.text('更新欠款'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '119000');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect((await repo.getAccount(id))!.initialBalance, -119000);
    expect(find.text('打开真实账户'), findsOneWidget);
    expect(await repo.getTransactionsByLedger(1), isEmpty);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('美元账户显示美元余额，流水折算使用来源账本历史快照', (tester) async {
    final usd = await repo.createAccount(
        ledgerId: 1, name: '美元账户', currency: 'USD', initialBalance: 100);
    await tx(
        type: 'expense',
        amount: 12,
        from: usd,
        currency: 'USD',
        native: 85.2,
        category: food);
    await tx(
        type: 'expense',
        amount: 5,
        from: usd,
        ledger: 2,
        currency: 'USD',
        native: 5,
        category: food);
    await open(tester, usd);
    final hero = tester
        .widget<BeeAccountSummaryCard>(find.byType(BeeAccountSummaryCard));
    expect(hero.prefix, 'US\$');
    expect(hero.amount, '83.00');
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -550));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();
    final actual = rows(tester);
    expect(
        actual.any((r) => r.converted == '≈ ¥85.20' && r.ledgerName == '日常生活'),
        isTrue,
        reason: actual
            .map((r) => '${r.amount}/${r.converted}/${r.ledgerName}')
            .join('|'));
    expect(
        actual.any((r) =>
            r.amount == '−US\$5.00' &&
            r.converted == null &&
            r.ledgerName == '旅行'),
        isTrue);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('真实分页按50条增量加载，滚动后仍保留全部53条且没有重复', (tester) async {
    for (var i = 0; i < 53; i++) {
      await tx(
          type: 'expense',
          amount: i + 1,
          from: cash,
          category: food,
          at: DateTime(2026, 10, 24, 12, i));
    }
    await open(tester, cash);
    expect(model(tester).rows.length, 50);
    for (var i = 0; i < 18; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await tester.pumpAndSettle();
    }
    final loaded = model(tester);
    expect(loaded.rows.length, 53);
    expect(loaded.rows.map((t) => t.id).toSet().length, 53);
    expect(loaded.hasMore, isFalse);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('分页异常显示可重试状态，点击重试读取真实数据', (tester) async {
    await tx(type: 'expense', amount: 3, from: cash, category: food);
    repo.failPageOnce = true;
    await open(tester, cash);
    expect(find.text('重试'), findsOneWidget);
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    await waitLoaded(tester);
    expect(model(tester).rows.length, 1);
    expect(find.text('重试'), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('320深色140%信用卡隐私隐藏金额，日期和还款仍可达', (tester) async {
    final id = await repo.createAccount(
        ledgerId: 1,
        name: '长名称信用卡',
        type: 'credit_card',
        initialBalance: -3200,
        creditLimit: 20000,
        billingDay: 12,
        paymentDueDay: 28);
    container.read(hideAmountsProvider.notifier).state = true;
    await open(tester, id, scale: 1.4, size: const Size(320, 568));
    final hero = tester
        .widget<BeeAccountSummaryCard>(find.byType(BeeAccountSummaryCard));
    expect(hero.amount, '••••');
    expect(find.textContaining('20,000.00'), findsNothing);
    await tester.ensureVisible(find.text('记一笔还款'));
    expect(find.textContaining('12日出账'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('资金流向筛选只列本账户支出转出或收入转入', (tester) async {
    final expense =
        await tx(type: 'expense', amount: 32, from: cash, category: food);
    final income =
        await tx(type: 'income', amount: 100, from: cash, category: salary);
    final outgoing =
        await tx(type: 'transfer', amount: 20, from: cash, to: bank);
    final incoming =
        await tx(type: 'transfer', amount: 10, from: bank, to: cash);
    final before = await repo.getTransactionsByLedger(1);
    await open(tester, cash);
    final l =
        AppLocalizations.of(tester.element(find.byType(AccountDetailPage)));
    await tester.ensureVisible(find.byWidgetPredicate(
        (w) => w is BeeIconButton && w.label == l.accountAllFlows));
    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate(
        (w) => w is BeeIconButton && w.label == l.accountAllFlows));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.accountOutflows));
    await tester.tap(find.text(l.commonConfirm));
    await waitLoaded(tester);
    expect(model(tester).rows.map((t) => t.id).toSet(), {expense, outgoing});
    await tester.ensureVisible(find.byWidgetPredicate(
        (w) => w is BeeIconButton && w.label == l.accountAllFlows));
    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate(
        (w) => w is BeeIconButton && w.label == l.accountAllFlows));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.accountInflows));
    await tester.tap(find.text(l.commonConfirm));
    await waitLoaded(tester);
    expect(model(tester).rows.map((t) => t.id).toSet(), {income, incoming});
    expect(await repo.getTransactionsByLedger(1), before);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('分类分布保留最多八类加其他，并可选中查看金额', (tester) async {
    for (var i = 1; i <= 10; i++) {
      final category = await repo.createCategory(name: '分类$i', kind: 'expense');
      await tx(
          type: 'expense',
          amount: i.toDouble(),
          from: cash,
          category: category);
    }
    await open(tester, cash);
    final l =
        AppLocalizations.of(tester.element(find.byType(AccountDetailPage)));
    await tester.ensureVisible(find.text(l.accountCategoryBreakdown));
    await tester.tap(find.text(l.accountCategoryBreakdown));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(BeeDonutChart));
    await tester.pumpAndSettle();
    final chart = tester.widget<BeeDonutChart>(find.byType(BeeDonutChart));
    expect(chart.items.length, 9);
    expect(chart.items.last.label, '其他');
    expect(chart.items.last.value, 3);
    final other = find.widgetWithText(
        ActionChip, '${chart.items.last.label} ${chart.items.last.valueLabel}');
    await tester.ensureVisible(other);
    await tester.tap(other);
    await tester.pumpAndSettle();
    expect(tester.widget<BeeDonutChart>(find.byType(BeeDonutChart)).centerLabel,
        '其他\n3.00');
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('估值弹窗保存返回真实资产页时立即刷新全局余额缓存', (tester) async {
    final loan = await repo.createAccount(
        ledgerId: 1, name: '住房贷款', type: 'loan', initialBalance: -200);
    await repo.upsertAutoRates(
        base: 'CNY',
        rateDate: '2026-10-24',
        rates: {'USD': '7.1'},
        source: 'synthetic-local',
        fetchedAt: DateTime.now().toUtc());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(398, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AccountsPage())));
    await tester.pumpAndSettle();
    await tester.runAsync(() => container.read(allAccountStatsProvider.future));
    await tester.pumpAndSettle();
    expect(container.read(allAccountStatsProvider).requireValue[loan]!.balance,
        -200);
    await tester.scrollUntilVisible(find.text('住房贷款'), 350,
        scrollable: find.byType(Scrollable).first, maxScrolls: 30);
    await tester.ensureVisible(find.text('住房贷款'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('住房贷款'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新欠款'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '190');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountsPage), findsOneWidget);
    final global = await tester
        .runAsync(() => container.read(allAccountStatsProvider.future));
    expect(global![loan]!.balance, -190);
    expect((await repo.getAccount(loan))!.initialBalance, -190);
    expect(await repo.getTransactionsByLedger(1), isEmpty);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  test('还款倒计时保留当日、闰月和跨年规则', () {
    expect(daysUntilAccountPayment(null, DateTime(2026, 10, 24)), isNull);
    expect(daysUntilAccountPayment(24, DateTime(2026, 10, 24)), 0);
    expect(daysUntilAccountPayment(2, DateTime(2024, 2, 28)), 3);
    expect(daysUntilAccountPayment(28, DateTime(2026, 12, 31)), 28);
  });
}
