import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/pages/transaction/recording/bindings/amount_editor_sheet.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/pages/main/home/bindings/transaction_list.dart';
import 'package:beecount/pages/shared/transactions/transaction_list_item.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('copy menu can open again after cancelling the new editor',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final repo = LocalRepository(db);
    final ledgerId = await repo.createLedger(name: 'Test');
    final categoryId = await repo.createCategory(name: 'Test', kind: 'expense');
    final id = await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 12,
        categoryId: categoryId,
        happenedAt: DateTime.now(),
        note: 'Source');
    final tx = (await repo.getTransactionById(id))!;
    final category = await repo.getCategoryById(categoryId);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => ledgerId),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
            body: TransactionList(hideAmounts: false, transactions: [
          (t: tx, category: category, account: null, toAccount: null)
        ])),
      ),
    ));
    await tester.pumpAndSettle();
    final row = find.byType(TransactionListItem, skipOffstage: false);
    await tester.longPress(row);
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsNWidgets(3));
    expect(find.text('账单详情'), findsOneWidget);
    expect(find.text('生成小票'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('复制为新交易'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.byType(AmountEditorSheet), findsOneWidget);
    final nav = Navigator.of(tester.element(find.byType(AmountEditorSheet)));
    nav.pop();
    await tester.pumpAndSettle();
    // The v4 editor embeds AmountEditorSheet on its page. Only the legacy
    // modal presentation has an additional editor route to close.
    if (find.byType(TransactionEditorPage).evaluate().isNotEmpty) {
      nav.pop();
      await tester.pumpAndSettle();
    }
    expect((await db.select(db.transactions).get()).length, 1);
    await tester.longPress(row);
    await tester.pumpAndSettle();
    expect(find.text('复制为新交易'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
