import 'dart:async';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/transaction/recurring_transaction_page.dart';
import 'package:beecount/pages/transaction/recurring/bindings/recurring_bill_controls.dart';
import 'package:beecount/dev/component_gallery/bindings/recurring_bills_preview.dart';
import 'package:beecount/dev/component_gallery/recurring_bills_sample.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends LocalRepository {
  _Repository(super.db);
  bool fail = false;
  Completer<void>? gate;
  int toggles = 0;
  @override
  Future<void> toggleRecurringTransaction(int id, bool enabled) async {
    toggles++;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('QA write failure');
    await super.toggleRecurringTransaction(id, enabled);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        // Drain LoggerService 2s debounce timer and dispose SQLite streams
        // before TestWidgetsFlutterBinding invariant check.
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }, timeout: const Timeout(Duration(seconds: 35)));
  }

  late BeeDatabase db;
  late _Repository repo;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'QA CNY','CNY'),(2,'QA USD','USD')");
    await db.customStatement(
        "INSERT INTO categories(id,name,kind,icon) VALUES(9,'QA category','expense','restaurant')");
  });
  tearDown(() async => db.close());

  Future<RecurringTransaction> seed(
      {int id = 1,
      int ledger = 1,
      String type = 'expense',
      String frequency = 'monthly',
      int interval = 1,
      String? currency = 'USD',
      bool enabled = true,
      String note = 'qa-rule'}) async {
    await db.customStatement(
        'INSERT INTO recurring_transactions(id,ledger_id,type,amount,category_id,frequency,interval,start_date,last_generated_date,note,currency_code,enabled) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          id,
          ledger,
          type,
          123.45,
          type == 'transfer' ? null : 9,
          frequency,
          interval,
          DateTime(2050, 1, 1).millisecondsSinceEpoch ~/ 1000,
          DateTime(2049, 12, 1).millisecondsSinceEpoch ~/ 1000,
          note,
          currency,
          enabled ? 1 : 0
        ]);
    return (await repo.getAllRecurringTransactions())
        .firstWhere((r) => r.id == id);
  }

  Widget host(Widget page,
          {Stream<List<RecurringTransaction>> Function()? load}) =>
      ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
            if (load != null)
              allRecurringTransactionsProvider.overrideWith((ref) => load())
          ],
          child: MaterialApp(
              theme: beeTheme(),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: page));

  void screen(WidgetTester t, Size size) {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Finder rule(int id) => find.byKey(ValueKey('recurring-rule-$id'));
  Finder toggle(int id) =>
      find.descendant(of: rule(id), matching: find.byType(Switch));

  for (final scale in [1.0, 1.4]) {
    scenario('纯周期卡320深色长文本与金额无溢出，开关不触发编辑 $scale', (t) async {
      screen(t, const Size(320, 568));
      var opened = 0, toggled = false;
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(brightness: Brightness.dark),
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      padding: const EdgeInsets.all(17),
                      child: BeeRecurringBillCard(
                          title: 'QA long category with a custom image',
                          ledger:
                              'An independent ledger with a long name · USD',
                          frequency: 'Every 12 months',
                          lastGenerated: 'Last generated 12/31/2049',
                          note: 'A sufficiently long note for a compact phone',
                          icon: const BeeLineIcon('Coffee'),
                          amount: const Text('USD -12,345,678.90'),
                          enabled: true,
                          toggleLabel: 'Enable QA recurring bill',
                          onOpen: () => opened++,
                          onToggle: (value) => toggled = !value))))));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(Switch));
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(toggled, isTrue);
      expect(opened, 0);
      expect(t.takeException(), isNull);
    });
  }

  scenario('忙碌周期卡不能重复切换或打开编辑', (t) async {
    var calls = 0;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BeeRecurringBillCard(
                title: 'QA',
                ledger: 'L',
                frequency: 'Monthly',
                amount: const Text('13.00'),
                icon: const BeeLineIcon('Repeat2'),
                enabled: true,
                toggleLabel: 'Enable QA',
                busy: true,
                onToggle: (_) => calls++,
                onOpen: () => calls++))));
    await t.pump();
    expect(t.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(t.widget<InkWell>(find.byType(InkWell).first).onTap, isNull);
    expect(calls, 0);
    await t.pumpWidget(const SizedBox());
  });

  scenario('四种频率与间隔保留原字符串规则', (t) async {
    final l = AppLocalizationsEn();
    final expected = {
      'daily': [
        l.recurringTransactionDaily,
        l.recurringTransactionEveryNDays(3)
      ],
      'weekly': [
        l.recurringTransactionWeekly,
        l.recurringTransactionEveryNWeeks(3)
      ],
      'monthly': [
        l.recurringTransactionMonthly,
        l.recurringTransactionEveryNMonths(3)
      ],
      'yearly': [
        l.recurringTransactionYearly,
        l.recurringTransactionEveryNYears(3)
      ],
    };
    var id = 1;
    for (final entry in expected.entries) {
      for (final interval in [1, 3]) {
        final record =
            await seed(id: id++, frequency: entry.key, interval: interval);
        expect(recurringFrequencyLabel(l, record),
            entry.value[interval == 1 ? 0 : 1]);
      }
    }
  });

  scenario('真实列表保留全账本、外币ISO、原生成日期与转账模板', (t) async {
    screen(t, const Size(398, 1000));
    await seed();
    await seed(
        id: 2,
        ledger: 2,
        type: 'transfer',
        currency: null,
        note: 'qa-other-book');
    await t.pumpWidget(host(const RecurringTransactionPage()));
    await t.pumpAndSettle();
    expect(find.byType(BeeRecurringUsageNotice), findsOneWidget);
    expect(find.byType(BeeRecurringBillCard), findsNWidgets(2));
    expect(find.text('QA CNY · CNY'), findsOneWidget);
    expect(find.text('QA USD · USD'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.textContaining('Last generated'), findsNWidgets(2));
    expect(find.text('Transfer'), findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(t.takeException(), isNull);
  });

  scenario('启停实际仓储只改变enabled和更新时间，不改币种规则或财务记录', (t) async {
    screen(t, const Size(398, 1000));
    final before = await seed();
    await t.pumpWidget(host(const RecurringTransactionPage()));
    await t.pumpAndSettle();
    await t.ensureVisible(toggle(1));
    await t.tap(toggle(1));
    await t.pump(const Duration(milliseconds: 150));
    await t.pumpAndSettle();
    final after = (await repo.getAllRecurringTransactions()).single;
    expect(after.enabled, false);
    final a = before.toJson()
      ..remove('enabled')
      ..remove('updatedAt');
    final b = after.toJson()
      ..remove('enabled')
      ..remove('updatedAt');
    expect(b, a);
    expect(repo.toggles, 1);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(t.takeException(), isNull);
  });

  scenario('未完成的真实写入禁用重复点击，成功后展示仓储新值', (t) async {
    screen(t, const Size(398, 1000));
    await seed();
    repo.gate = Completer<void>();
    await t.pumpWidget(host(const RecurringTransactionPage()));
    await t.pumpAndSettle();
    await t.ensureVisible(toggle(1));
    await t.tap(toggle(1));
    await t.pump();
    expect(t.widget<Switch>(toggle(1)).onChanged, isNull);
    expect(repo.toggles, 1);
    repo.gate!.complete();
    await t.pump(const Duration(milliseconds: 150));
    await t.pumpAndSettle();
    expect(t.widget<Switch>(toggle(1)).value, false);
    expect(t.widget<Switch>(toggle(1)).onChanged, isNotNull);
    expect(repo.toggles, 1);
  });

  scenario('仓储切换失败保留原值且可重试', (t) async {
    screen(t, const Size(398, 1000));
    await seed();
    repo.fail = true;
    await t.pumpWidget(host(const RecurringTransactionPage()));
    await t.pumpAndSettle();
    await t.ensureVisible(toggle(1));
    await t.tap(toggle(1));
    await t.pump();
    expect((await repo.getAllRecurringTransactions()).single.enabled, true);
    expect(t.widget<Switch>(toggle(1)).value, true);
    expect(t.widget<Switch>(toggle(1)).onChanged, isNotNull);
    await t.pump(const Duration(seconds: 4));
    repo.fail = false;
    await t.tap(toggle(1));
    await t.pump(const Duration(milliseconds: 150));
    await t.pumpAndSettle();
    expect((await repo.getAllRecurringTransactions()).single.enabled, false);
    expect(repo.toggles, 2);
  });

  scenario('空列表保留原添加入口，不创建示例模板', (t) async {
    screen(t, const Size(320, 568));
    await t.pumpWidget(host(const RecurringTransactionPage()));
    await t.pumpAndSettle();
    expect(find.byType(BeeEmptyState), findsOneWidget);
    expect(find.byTooltip(AppLocalizationsEn().recurringTransactionAdd),
        findsOneWidget);
    expect(await repo.getAllRecurringTransactions(), isEmpty);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(t.takeException(), isNull);
  });
  scenario('60组受控启停和忙碌不写真实配置，保留只读插槽', (t) async {
    screen(t, const Size(398, 1100));
    await t.pumpWidget(host(const Scaffold(
        body: SingleChildScrollView(
            child: RecurringBillsSample(liveData: Text('QA live slot'))))));
    await t.pumpAndSettle();
    final firstSwitch = find.byType(Switch).first;
    await t.ensureVisible(firstSwitch);
    await t.tap(firstSwitch);
    await t.pumpAndSettle();
    expect(t.widget<Switch>(firstSwitch).value, false);
    expect(await repo.getAllRecurringTransactions(), isEmpty);
    await t.ensureVisible(find.text('查看忙碌状态'));
    await t.tap(find.text('查看忙碌状态'));
    await t.pump();
    expect(
        t
            .widget<BeeRecurringBillCard>(
                find.byType(BeeRecurringBillCard).first)
            .busy,
        true);
    expect(t.widget<Switch>(firstSwitch).onChanged, isNull);
    expect(find.text('QA live slot'), findsOneWidget);
    await t.ensureVisible(find.text('恢复示例开关'));
    await t.tap(find.text('恢复示例开关'));
    await t.pumpAndSettle();
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(repo.toggles, 0);
    expect(t.takeException(), isNull);
  });

  scenario('真实周期目录只读同一仓储，打开正式页也不创建模板或账单', (t) async {
    screen(t, const Size(398, 1100));
    final before = await seed();
    await t.pumpWidget(host(const Scaffold(
        body: SingleChildScrollView(child: LiveRecurringBillsPreview()))));
    await t.pumpAndSettle();
    expect(find.text('1 个周期账单 · 全部账本'), findsOneWidget);
    expect(t.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect((await repo.getAllRecurringTransactions()).single, before);
    await t.tap(find.text('打开真实周期账单'));
    await t.pumpAndSettle();
    expect(find.byType(RecurringTransactionPage), findsOneWidget);
    expect((await repo.getAllRecurringTransactions()).single, before);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(repo.toggles, 0);
    expect(t.takeException(), isNull);
  });
  scenario('加载失败可重试原数据流，过程不创建模板或财务记录', (t) async {
    screen(t, const Size(398, 1000));
    final original = await seed();
    final first = StreamController<List<RecurringTransaction>>();
    var subscriptions = 0;
    await t.pumpWidget(host(const RecurringTransactionPage(), load: () {
      subscriptions++;
      return subscriptions == 1 ? first.stream : Stream.value([original]);
    }));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    first.addError(StateError('QA load failure'));
    await t.pumpAndSettle();
    expect(find.textContaining('QA load failure'), findsOneWidget);
    await t.tap(find.text(AppLocalizationsEn().v4RecordingRetry));
    await t.pumpAndSettle();
    expect(subscriptions, 2);
    expect(find.byType(BeeRecurringBillCard), findsOneWidget);
    expect((await repo.getAllRecurringTransactions()).single, original);
    expect(await db.select(db.transactions).get(), isEmpty);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
    await t.runAsync(() => first.close());
  });

  scenario('窄屏1.4倍字号下带下次排期与告警横幅的周期卡无溢出', (t) async {
    screen(t, const Size(320, 640));
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(17),
                    child: BeeRecurringBillCard(
                        title: 'QA Rent & Utilities',
                        ledger: 'Daily Ledger · CNY · CMB Checking',
                        frequency: 'Monthly · Day 31',
                        lastGenerated: 'Not generated yet',
                        nextRunLabel: 'Next 11/30 · In 12 days',
                        nextRunHighlighted: true,
                        warningMessage:
                            'Linked account "CMB Checking" is hidden; auto-recording paused',
                        note: 'Monthly rent with month-end alignment',
                        icon: const BeeLineIcon('Home'),
                        amount: const Text('CNY -4,500.00'),
                        enabled: true,
                        toggleLabel: 'Enable QA rent'))))));
    await t.pumpAndSettle();
    expect(find.text('Next 11/30 · In 12 days'), findsOneWidget);
    expect(find.textContaining('Linked account'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  scenario('隐藏关联账户显示阻塞告警，取消隐藏后实时恢复排期状态', (t) async {
    screen(t, const Size(398, 1000));
    final accountId = await repo.createAccount(
        ledgerId: 1, name: 'QA Hidden Card', initialBalance: 100);
    await repo.setAccountHidden(accountId, true);
    await db.customStatement(
        'INSERT INTO recurring_transactions(id,ledger_id,type,amount,category_id,account_id,frequency,interval,day_of_month,start_date,enabled) VALUES(?,?,?,?,?,?,?,?,?,?,?)',
        [
          10,
          1,
          'expense',
          88.0,
          9,
          accountId,
          'monthly',
          1,
          15,
          DateTime(2050, 1, 15).millisecondsSinceEpoch ~/ 1000,
          1
        ]);
    await t.pumpWidget(host(const RecurringTransactionPage()));
    await t.pumpAndSettle();
    final l = AppLocalizationsEn();
    expect(find.text(l.v4RecurringAccountHiddenWarning('QA Hidden Card')),
        findsOneWidget);
    expect(find.text(l.v4RecurringStatusBlocked), findsOneWidget);
    expect(find.text('QA CNY · QA Hidden Card · CNY'), findsOneWidget);

    await repo.setAccountHidden(accountId, false);
    await t.pumpAndSettle();
    expect(find.text(l.v4RecurringAccountHiddenWarning('QA Hidden Card')),
        findsNothing);
    expect(find.text(l.v4RecurringStatusBlocked), findsNothing);
    expect(find.textContaining('Next '), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  scenario('重新开启今日到期的暂停规则立即补生成当期账单并记录recurringId', (t) async {
    screen(t, const Size(398, 1000));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await db.customStatement(
        'INSERT INTO recurring_transactions(id,ledger_id,type,amount,category_id,frequency,interval,day_of_month,start_date,note,enabled) VALUES(?,?,?,?,?,?,?,?,?,?,?)',
        [
          11,
          1,
          'expense',
          66.0,
          9,
          'monthly',
          1,
          today.day,
          today.millisecondsSinceEpoch ~/ 1000,
          'qa-toggle-on-due',
          0
        ]);
    await t.pumpWidget(host(const RecurringTransactionPage()));
    await t.pumpAndSettle();
    expect(find.text(AppLocalizationsEn().v4RecurringStatusPaused),
        findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);

    await t.ensureVisible(toggle(11));
    await t.tap(toggle(11));
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.single.note, 'qa-toggle-on-due');
    expect(txs.single.amount, 66.0);
    expect(txs.single.recurringId, 11);
    final updatedRule = (await repo.getAllRecurringTransactions())
        .singleWhere((r) => r.id == 11);
    expect(updatedRule.enabled, isTrue);
    expect(updatedRule.lastGeneratedDate, today);
    expect(t.takeException(), isNull);
  });
}
