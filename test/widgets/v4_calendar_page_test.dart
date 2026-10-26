import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/calendar/calendar_page.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/presentation/v4/bindings/calendar_month_view.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/calendar_providers.dart';
import 'package:beecount/widgets/biz/transaction_list_item.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

class _Repo extends LocalRepository {
  _Repo(super.db);
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<Map<String, (double, double)>> getDailyTotalsByMonth(
      {required int ledgerId, required DateTime month}) async {
    await gate?.future;
    if (fail) throw StateError('synthetic calendar failure');
    return super.getDailyTotalsByMonth(ledgerId: ledgerId, month: month);
  }
}

void main() {
  late BeeDatabase db;
  late _Repo repo;
  late ProviderContainer c;
  final now = DateTime.now();
  final month = DateTime(now.year, now.month);
  final day = DateTime(now.year, now.month, 15);
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repo(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'日历合成账本','CNY')");
    final parent = await repo.createCategory(
        name: '合成餐饮', kind: 'expense', icon: 'restaurant');
    final at =
        day.add(const Duration(hours: 12)).millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
        '''INSERT INTO transactions(ledger_id,type,amount,native_amount,currency_code,category_id,happened_at,note,exclude_from_stats,exclude_from_budget) VALUES
      (1,'expense',12,85.2,'USD',$parent,$at,'外币午餐',0,0),
      (1,'expense',30,NULL,'CNY',$parent,${at + 3600},'不计收支仍可见',1,0),
      (1,'expense',10,NULL,'CNY',$parent,${at + 7200},'仅排除预算',0,1),
      (1,'income',12000,NULL,'CNY',NULL,${at + 10800},'工资',0,0),
      (1,'transfer',500,NULL,'CNY',NULL,${at + 14400},'转账',0,0)''');
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService())
    ]);
    await c.read(currentLedgerProvider.future);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  Future<void> ready(WidgetTester t, Finder finder) async {
    for (var i = 0; i < 80; i++) {
      await t.pump(const Duration(milliseconds: 30));
      if (finder.evaluate().isNotEmpty) {
        await t.pump(const Duration(milliseconds: 400));
        return;
      }
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    expect(finder, findsWidgets);
  }

  Future<void> open(WidgetTester t,
      {bool narrow = false, Finder? target}) async {
    t.view.physicalSize = narrow ? const Size(320, 568) : const Size(398, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: beeTheme(
                brightness: narrow ? Brightness.dark : Brightness.light),
            locale: narrow ? const Locale('en') : const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(narrow ? 1.4 : 1)),
                child: child!),
            home: const CalendarPage())));
    await ready(t, target ?? find.byType(CalendarMonthView));
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 3));
  }

  Finder calendar() => find.byWidgetPredicate((w) => w is TableCalendar);
  Future<void> select15(WidgetTester t) async {
    await t.tap(find.descendant(of: calendar(), matching: find.text('15')));
    await ready(
        t,
        find.byWidgetPredicate(
            (w) => w is TransactionListItem && w.title == '外币午餐'));
  }

  test('真实SQLite：日历收支沿用native快照、排除收支，转账不参与且排除预算仍计入', () async {
    final rows = await repo.getDailyTotalsByMonth(ledgerId: 1, month: month);
    expect(rows[calendarDateKey(day)], (12000.0, 95.2));
    final detail = await repo.getTransactionsByDate(ledgerId: 1, date: day);
    expect(detail.length, 5);
    expect(detail.first.t.type, 'transfer');
    expect(detail.last.t.currencyCode, 'USD');
    expect(detail.last.t.nativeAmount, 85.2);
    expect(detail.where((r) => r.t.excludeFromStats).length, 1);
    expect(detail.where((r) => r.t.excludeFromBudget).length, 1);
  });

  for (final dark in [false, true]) {
    for (final redIncome in [false, true]) {
      testWidgets('日历与冻结设计语义色一致且保留颜色反转 dark=$dark redIncome=$redIncome',
          (t) async {
        c.read(incomeExpenseColorSchemeProvider.notifier).state = redIncome;
        await open(t, narrow: dark);
        final tokens = jsonDecode(
            File('docs/design/card-refresh/tokens/design-tokens.json')
                .readAsStringSync())['color'][dark ? 'dark' : 'light'];
        Color color(String key) =>
            Color(int.parse((tokens[key] as String).replaceFirst('#', 'ff'),
                radix: 16));
        final cell = t.widget<BeeCalendarDayCell>(find.byWidgetPredicate((w) =>
            w is BeeCalendarDayCell &&
            w.day == '15' &&
            w.expense == '-95' &&
            w.income == '+1.2w'));
        expect(cell.expenseColor, color(redIncome ? 'expense' : 'income'));
        expect(cell.incomeColor, color(redIncome ? 'income' : 'expense'));
        expect(t.takeException(), isNull);
        await close(t);
      });
    }
  }
  testWidgets('原生朗读树保留日期以及未缩略的实际日收支', (t) async {
    final semantics = t.ensureSemantics();
    await open(t);
    expect(find.bySemanticsLabel(RegExp(r'.*收入 12000.00 支出 95.20.*')),
        findsWidgets);
    await close(t);
    semantics.dispose();
  });
  test('原整数与k/w缩略阈值保持', () {
    expect(calendarCompactAmount(999.99, '-'), '-999');
    expect(calendarCompactAmount(1000, '-'), '-1.0k');
    expect(calendarCompactAmount(10000, '+'), '+1.0w');
    expect(calendarDateKey(DateTime(2000, 2, 29)), '2000-02-29');
  });
  testWidgets('真实按日列表：完整时间/外币换算/排除标记/转账保留', (t) async {
    await open(t);
    await select15(t);
    final items = t
        .widgetList<TransactionListItem>(find.byType(TransactionListItem))
        .toList();
    expect(items.length, 5);
    final usd = items.singleWhere((r) => r.currencyCode == 'USD');
    expect(usd.amount, 12);
    expect(usd.nativeAmount, 85.2);
    expect(usd.happenedAt, day.add(const Duration(hours: 12)));
    expect(
        items.singleWhere((r) => r.title == '不计收支仍可见').excludeFromStats, true);
    expect(
        items.singleWhere((r) => r.title == '仅排除预算').excludeFromBudget, true);
    expect(items.singleWhere((r) => r.title == '转账').isTransfer, true);
    expect(find.text('-95'), findsOneWidget);
    expect(find.text('+1.2w'), findsOneWidget);
    expect(t.takeException(), isNull);
    await close(t);
  });

  testWidgets('分类图标默认沿用账单编辑；正文点击同样回填原交易并取消不写', (t) async {
    await open(t);
    await select15(t);
    final row = find.byWidgetPredicate(
        (w) => w is TransactionListItem && w.currencyCode == 'USD');
    for (final icon in [true, false]) {
      final target = icon
          ? find
              .descendant(
                  of: row,
                  matching: find.byWidgetPredicate((w) =>
                      w is Semantics &&
                      w.properties.button == true &&
                      w.properties.label == '合成餐饮'))
              .first
          : find
              .descendant(
                  of: row,
                  matching: find.textContaining('外币午餐', findRichText: true))
              .first;
      await t.ensureVisible(target);
      await t.tap(target);
      await t.pumpAndSettle();
      final editor =
          t.widget<TransactionEditorPage>(find.byType(TransactionEditorPage));
      expect(editor.editingTransactionId, 1);
      expect(editor.initialAmount, 12);
      expect(editor.initialCurrencyCode, 'USD');
      expect(editor.initialNativeAmount, 85.2);
      Navigator.of(t.element(find.byType(TransactionEditorPage))).pop();
      await t.pumpAndSettle();
      await ready(t, row);
    }
    expect(
        await db
            .customSelect('SELECT count(*) AS n FROM transactions')
            .getSingle()
            .then((r) => r.read<int>('n')),
        5);
    expect(t.takeException(), isNull);
    await close(t);
  });
  testWidgets('左右切月清除选中、今天恢复月份与日期，不改交易', (t) async {
    await open(t);
    await select15(t);
    final next = DateTime(month.year, month.month + 1);
    await t.tap(find.byTooltip(DateFormat.yMMMM('zh').format(next)));
    await t.pumpAndSettle();
    expect(c.read(calendarSelectedDateProvider), isNull);
    expect(find.byType(BeeCalendarDayHeading), findsNothing);
    expect(find.text(DateFormat.yMMMM('zh').format(next)), findsOneWidget);
    await t.tap(find.text('今天'));
    await t.pumpAndSettle();
    final selected = c.read(calendarSelectedDateProvider)!;
    expect(calendarDateKey(selected), calendarDateKey(now));
    expect(
        await db
            .customSelect('SELECT count(*) AS n FROM transactions')
            .getSingle()
            .then((r) => r.read<int>('n')),
        5);
    expect(t.takeException(), isNull);
    await close(t);
  });
  testWidgets('实际水平滑动切月同样清除当天列表', (t) async {
    await open(t);
    await select15(t);
    await t.drag(calendar(), const Offset(-300, 0));
    await t.pumpAndSettle();
    expect(c.read(calendarSelectedDateProvider), isNull);
    expect(c.read(calendarSelectedMonthProvider).month,
        DateTime(month.year, month.month + 1).month);
    expect(find.byType(BeeCalendarDayHeading), findsNothing);
    expect(t.takeException(), isNull);
    await close(t);
  });
  testWidgets('在该日记账进入正式编辑器，日期锁到所选日中午；取消不写', (t) async {
    await open(t);
    await select15(t);
    await t.ensureVisible(find.text('在该日记账'));
    await t.tap(find.text('在该日记账'));
    await t.pumpAndSettle();
    final editor =
        t.widget<TransactionEditorPage>(find.byType(TransactionEditorPage));
    expect(editor.initialDate, day.add(const Duration(hours: 12)));
    expect(editor.initialKind, 'expense');
    expect(editor.quickAdd, true);
    Navigator.of(t.element(find.byType(TransactionEditorPage))).pop();
    await t.pumpAndSettle();
    await ready(t, find.byType(CalendarMonthView));
    expect(
        await db
            .customSelect('SELECT count(*) AS n FROM transactions')
            .getSingle()
            .then((r) => r.read<int>('n')),
        5);
    expect(t.takeException(), isNull);
    await close(t);
  });
  testWidgets('读取失败重试、刷新期间保留旧日历', (t) async {
    repo.fail = true;
    await open(t, target: find.textContaining('synthetic calendar failure'));
    repo.fail = false;
    await t.tap(find.text('重试'));
    await ready(t, find.byType(CalendarMonthView));
    repo.gate = Completer<void>();
    c.read(calendarRefreshProvider.notifier).state++;
    await t.pump();
    expect(find.byType(CalendarMonthView), findsOneWidget);
    repo.gate!.complete();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await close(t);
  });
  testWidgets('320英文深色140%日历、两种金额和当天操作滚动可达无溢出', (t) async {
    await open(t, narrow: true);
    await select15(t);
    await t.ensureVisible(find.byType(BeeCalendarDayHeading));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byType(BeeCalendarDayHeading), findsOneWidget);
    await t.ensureVisible(find.byWidgetPredicate(
        (w) => w is TransactionListItem && w.title == '外币午餐'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await close(t);
  });
}
