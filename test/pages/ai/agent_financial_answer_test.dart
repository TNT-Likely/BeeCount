import 'dart:convert';

import 'package:agentcore/agentcore.dart';
import 'package:beecount/agent/tools/ledger_query_snapshot.dart';
import 'package:beecount/agent/tools/local_agent_tools.dart';
import 'package:beecount/data/db.dart' show TransactionsCompanion;
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/pages/ai/chat/widgets/agent_financial_answer.dart';
import 'package:beecount/pages/ai/chat/widgets/ledger_evidence_sheet.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/pages/transaction/transaction_detail_page.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai_eval/support/ledger_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LedgerEvalFixture fixture;
  late LocalAgentTools owner;
  late int ledger, category, wallet, card;
  final l = AppLocalizationsZh();
  const january = {
    'period': 'custom',
    'start': '2027-01-01',
    'end': '2027-02-01'
  };
  const february = {
    'period': 'custom',
    'start': '2027-02-01',
    'end': '2027-03-01'
  };
  LocalAgentTools tools({LedgerSnapshotBudget? budget}) => LocalAgentTools(
      scope: AgentScope(id: 'frozen', ledgerId: ledger),
      gateway: fixture.gateway,
      snapshotBudget: budget);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fixture = await LedgerEvalFixture.create();
    ledger = await fixture.repository.createLedger(name: '冻结账单测试账本');
    category =
        await fixture.repository.createCategory(name: '测试晚餐', kind: 'expense');
    wallet =
        await fixture.repository.createAccount(ledgerId: ledger, name: '日用钱夹');
    card = await fixture.repository
        .createAccount(ledgerId: ledger, name: '旅行卡', currency: 'USD');
    owner = tools();
  });
  tearDown(() => fixture.close());

  Future<int> bill(double amount,
          {int month = 1,
          int day = 2,
          String type = 'expense',
          bool excluded = false,
          int? account,
          String? currency,
          double? native,
          String? note,
          int? ledgerId}) =>
      fixture.repository.addTransaction(
          ledgerId: ledgerId ?? ledger,
          happenedAt: DateTime(2027, month, day, 12),
          type: type,
          amount: amount,
          categoryId: type == 'expense' ? category : null,
          accountId: account,
          currencyCode: currency,
          nativeAmount: native ?? amount,
          excludeFromStats: excluded,
          note: note);

  Future<Map<String, Object?>> run(String name, Map<String, Object?> args) =>
      owner.build()[name]!.execute(AgentToolCall(name: name, arguments: args));
  String metadata() => jsonEncode({
        'contextLedgerId': ledger,
        'queryContext': {
          'queries': owner.evidence.current,
          'displayRefs': owner.evidence.current.map((q) => q['ref']).toList(),
          'snapshots': owner.evidence.snapshots,
        }
      });
  List<Map<String, Object?>> queries() =>
      LedgerEvidenceSheet.forMessage(metadata(), ledger);

  Future<void> render(WidgetTester tester, List<Map<String, Object?>> saved,
      {bool openSheet = false}) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(fixture.database),
          repositoryProvider.overrideWithValue(fixture.repository),
          currentLedgerIdProvider.overrideWith((ref) => ledger),
        ],
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: SingleChildScrollView(
                    child: Builder(
              builder: (context) => openSheet
                  ? LedgerEvidenceSheet(ledgerId: ledger, queries: saved)
                  : AgentFinancialAnswer.fromQueries(
                          queries: saved,
                          onEvidence: (scope) => LedgerEvidenceSheet.show(
                              context,
                              ledgerId: ledger,
                              queries: scope)) ??
                      const SizedBox.shrink(),
            ))))));
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
      'old card, old list and bill comparison survive editing and deletion',
      (tester) async {
    final id = await bill(28, note: '午饭冻结行', account: wallet);
    await bill(100, type: 'income');
    await bill(50, type: 'transfer');
    await bill(999, excluded: true);
    await bill(777, ledgerId: fixture.ledgers['other']);
    final result =
        await run('get_period_overview', {...january, 'end': '2027-01-20'});
    expect(result['expense'], 28);
    expect(result.containsKey('_snapshot'), isFalse);
    expect(jsonEncode(owner.evidence.current), isNot(contains('午饭冻结行')));
    // The monthly review can fetch an unrelated supporting annual trend.
    await run('get_spending_trend',
        {...january, 'end': '2028-01-01', 'interval': 'month'});
    final stored = metadata(), saved = queries();
    expect(LedgerEvidenceSheet.forMessage(stored, fixture.ledgers['other']!),
        isEmpty);
    await (fixture.database.update(fixture.database.transactions)
          ..where((t) => t.id.equals(id)))
        .write(const TransactionsCompanion(
            amount: Value(32), nativeAmount: Value(32)));
    await render(tester, saved);
    expect(find.text(l.agentAnswerMonthBalance('1月')), findsOneWidget);
    expect(find.byKey(const ValueKey('financial-answer-overview')),
        findsOneWidget);
    expect(tester.widget<BeeMoney>(find.byType(BeeMoney)).amount, '72.00');
    expect(find.text('¥28.00'), findsOneWidget);
    final copied = AgentFinancialAnswer.copyText(
        tester.element(find.byType(BeeMoney)), saved)!;
    expect(copied, contains('¥72.00'));
    expect(copied, contains('¥28.00'));
    expect(copied, contains(l.agentEvidenceCount(2)));
    expect(copied, isNot(contains('¥32.00')));
    expect(copied, isNot(contains('午饭冻结行')));
    expect(find.text(l.agentAnswerTransferNote(1)), findsOneWidget);
    await tester.tap(find.text(l.agentEvidenceBills));
    await tester.pumpAndSettle();
    expect(find.text(l.agentEvidenceCount(2)), findsWidgets);
    final row = find.byKey(ValueKey(id));
    final originalAmount = find.descendant(
        of: row, matching: find.byKey(const ValueKey('transaction-amount')));
    expect(tester.widget<Text>(originalAmount).textSpan!.toPlainText(),
        endsWith('28.00'));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text(l.agentAnswerFrozenBill), findsOneWidget);
    expect(find.text(l.agentAnswerBillChanged), findsOneWidget);
    expect(find.text('¥32.00'), findsOneWidget);
    await tester.tap(find.text(l.agentAnswerCurrentBill));
    await tester.pumpAndSettle();
    final detail = tester
        .widget<TransactionDetailPage>(find.byType(TransactionDetailPage));
    expect((detail.ledgerId, detail.transactionId), (ledger, id));
    Navigator.of(tester.element(find.byType(TransactionDetailPage))).pop();
    await tester.pumpAndSettle();
    final options = ProviderScope.containerOf(
        tester.element(find.text(l.agentAnswerBillChanged)));
    options.read(hideAmountsProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(find.text('¥32.00'), findsNothing);
    options.read(hideAmountsProvider.notifier).state = false;
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton).last);
    await tester.pumpAndSettle();
    owner = tools();
    final updated = await run('get_period_overview', january);
    expect(updated['expense'], 32);
    expect(
        ((queries().single['snapshot'] as Map)['totals'] as Map)['expense']
            ['amount'],
        32);
    await fixture.repository.deleteTransaction(id);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text(l.agentAnswerBillGone), findsOneWidget);
    expect(find.text(l.agentAnswerCurrentBill), findsNothing);
    await dispose(tester);
  });

  testWidgets(
      'category and per-account queries use complete ledger-currency amounts and preserve privacy',
      (tester) async {
    await bill(28, account: wallet);
    await bill(10, account: card, currency: 'USD', native: 72);
    final filter = {
      ...january,
      'categoryNames': ['测试晚餐'],
      'flowType': 'expense'
    };
    await run('get_period_overview', filter);
    for (final name in ['日用钱夹', '旅行卡']) {
      await run('get_period_overview', {
        ...filter,
        'accountNames': [name]
      });
    }
    await render(tester, queries());
    expect(find.byKey(const ValueKey('financial-answer-accounts')),
        findsOneWidget);
    expect(tester.widget<BeeMoney>(find.byType(BeeMoney)).amount, '100.00');
    expect(find.text('¥72.00'), findsOneWidget);
    expect(find.textContaining('日用钱夹'), findsOneWidget);
    final copied = AgentFinancialAnswer.copyText(
        tester.element(find.byType(BeeMoney)), queries())!;
    expect(copied, contains('旅行卡 · ¥72.00'));
    expect(copied, contains('日用钱夹 · ¥28.00'));
    expect(
        AgentFinancialAnswer.copyText(
            tester.element(find.byType(BeeMoney)), queries(),
            accountsEnabled: false),
        isNot(contains('日用钱夹')));
    await tester.tap(find.text(l.agentEvidenceBills));
    await tester.pumpAndSettle();
    final usd = tester
        .widgetList<BeeTransactionRow>(find.byType(BeeTransactionRow))
        .singleWhere((row) => row.accountName == '旅行卡');
    expect(usd.amount, contains(r'US$10.00'));
    expect(usd.converted, contains('¥72.00'));
    final scope =
        ProviderScope.containerOf(tester.element(find.byType(BeeSheet)));
    scope.read(hideAmountsProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(find.text('¥72.00'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await dispose(tester);
  });

  testWidgets(
      'comparison orders the later period first and opens only its expenses',
      (tester) async {
    await bill(40);
    await bill(28, month: 2);
    await bill(100, month: 2, type: 'income');
    // Tool order is deliberately old then new; headings and delta use dates.
    await run('get_period_overview', {...january, 'end': '2027-01-26'});
    await run('get_period_overview', {...february, 'end': '2027-02-26'});
    await render(tester, queries());
    expect(find.text(l.agentAnswerLowerExpense), findsOneWidget);
    expect(tester.widget<BeeMoney>(find.byType(BeeMoney)).amount, '12.00');
    final copied = AgentFinancialAnswer.copyText(
        tester.element(find.byType(BeeMoney)), queries())!;
    expect(copied, contains(l.agentAnswerLowerExpense));
    expect(copied, contains('¥40.00'));
    expect(copied, contains('¥28.00'));
    await tester.tap(find.text(l.agentEvidenceBills));
    await tester.pumpAndSettle();
    final visible =
        tester.widgetList<BeeTransactionRow>(find.byType(BeeTransactionRow));
    expect(visible.single.amount, endsWith('28.00'));
    final sheet =
        tester.widget<LedgerEvidenceSheet>(find.byType(LedgerEvidenceSheet));
    expect((sheet.queries.first['filters'] as Map)['start'],
        startsWith('2027-02'));
    expect(sheet.queries.first['displayFlow'], 'expense');
    await dispose(tester);
  });

  testWidgets(
      'bounded partial snapshots retain full totals and clearly label frozen coverage',
      (tester) async {
    owner = tools(budget: LedgerSnapshotBudget(rowLimit: 3, byteLimit: 10000));
    for (var i = 1; i <= 6; i++) {
      await bill(i.toDouble(), day: i);
    }
    final result = await run('query_transactions', {...january, 'limit': 2});
    expect(result['totalCount'], 6);
    expect((result['items'] as List).length, 2);
    expect(owner.evidence.current.single['options'], {'limit': 2});
    final first = queries().single;
    expect((first['snapshot'] as Map)['capturedCount'], 3);
    expect(
        LedgerQuerySnapshot.page(first['snapshot'] as Map, 0)
            .map((row) => row['amount']),
        [6, 5, 4]);
    await run('query_transactions',
        {...january, 'cursor': result['nextCursor'], 'limit': 2});
    expect(owner.evidence.current.last['options'],
        {'cursor': result['nextCursor'], 'limit': 2});
    expect((queries().last['snapshot'] as Map)['capturedCount'], 0);
    await render(tester, [first], openSheet: true);
    expect(find.text(l.agentAnswerSnapshotLimit(3, 6)), findsOneWidget);
    expect(find.byType(BeeTransactionRow), findsNWidgets(3));
    await dispose(tester);
  });
  test(
      'frozen pages keep their values and ordering after an earlier bill moves or disappears',
      () async {
    final ids = [
      for (var i = 1; i <= 25; i++) await bill(i.toDouble(), day: i)
    ];
    await run('query_transactions', {...january, 'limit': 2});
    final saved = queries().single['snapshot'] as Map;
    expect(saved['count'], 25);
    await (fixture.database.update(fixture.database.transactions)
          ..where((t) => t.id.equals(ids.first)))
        .write(TransactionsCompanion(
            happenedAt: Value(DateTime(2027, 1, 31)), amount: const Value(99)));
    await fixture.repository.deleteTransaction(ids[1]);
    expect(LedgerQuerySnapshot.page(saved, 0).map((r) => r['amount']),
        [for (int i = 25; i >= 6; i--) i]);
    expect(LedgerQuerySnapshot.page(saved, 1).map((r) => r['amount']),
        [5, 4, 3, 2, 1]);
    owner = tools();
    await run('query_transactions', january);
    final fresh = queries().single['snapshot'] as Map;
    expect(fresh['count'], 24);
    expect(LedgerQuerySnapshot.page(fresh, 0).first['amount'], 99);
    expect(LedgerQuerySnapshot.page(fresh, 1).map((r) => r['amount']),
        [6, 5, 4, 3]);
  });
}
