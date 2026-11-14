import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/account_detail_page.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';

void main() {
  for (final incoming in [true, false]) {
    testWidgets('${incoming ? '信用卡转入' : '银行卡转出'}还款显示方向、中性色和转账标题，筛选不影响统计',
        (tester) async {
      final db = BeeDatabase.forTesting(NativeDatabase.memory());
      final repo = LocalRepository(db);
      addTearDown(db.close);
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final ledgerId = await db
          .into(db.ledgers)
          .insert(LedgersCompanion.insert(name: '很长的跨账本名称用于确认不会挤掉转账标题'));
      final bank = await repo.createAccount(
          ledgerId: ledgerId,
          name: '农业银行',
          type: 'bank_card',
          initialBalance: 1000);
      final card = await repo.createAccount(
          ledgerId: ledgerId,
          name: '招商银行',
          type: 'credit_card',
          initialBalance: -135);
      final txId = await repo.addTransaction(
          ledgerId: ledgerId,
          type: 'transfer',
          amount: 135,
          accountId: bank,
          toAccountId: card,
          happenedAt: DateTime.now(),
          note: '信用卡还款');
      final accountId = incoming ? card : bank;
      await tester.pumpWidget(ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            currentLedgerIdProvider.overrideWith((ref) => ledgerId),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home:
                AccountDetailPage(account: (await repo.getAccount(accountId))!),
          )));
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey('account-transaction-$txId'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('农业银行 → 招商银行')),
          findsOneWidget);
      expect(
          find.descendant(
              of: row, matching: find.text('信用卡还款', findRichText: true)),
          findsOneWidget);
      final presentation = tester.widget<BeeTransactionRow>(
          find.descendant(of: row, matching: find.byType(BeeTransactionRow)));
      expect(presentation.kind, BeeTransactionKind.transfer);
      expect(presentation.ledgerName, '很长的跨账本名称用于确认不会挤掉转账标题');
      expect(presentation.amount, incoming ? '+¥135.00' : '−¥135.00');
      final renderedAmount = tester.widget<RichText>(find.descendant(
          of: row,
          matching: find.byWidgetPredicate((widget) =>
              widget is RichText &&
              widget.text.toPlainText() == presentation.amount)));
      expect(renderedAmount.text.style?.color,
          Theme.of(tester.element(row)).colorScheme.onSurface);
      expect(tester.takeException(), isNull);
      expect(await repo.getAccountBalance(accountId), incoming ? 0 : 865);
      expect(await repo.getAccountCategoryStats(accountId, type: 'income'),
          isEmpty);
      expect(await repo.getAccountCategoryStats(accountId, type: 'expense'),
          isEmpty);
      final l = AppLocalizations.of(tester.element(row));
      Future<void> filter(String value) async {
        final control = find.byWidgetPredicate(
            (w) => w is BeeIconButton && w.label == l.accountAllFlows);
        await tester.ensureVisible(control);
        await tester.drag(find.byType(ListView).first, const Offset(0, -100));
        await tester.pumpAndSettle();
        await tester.tap(control);
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(
            of: find.byType(BeeAccountFlowFilter), matching: find.text(value)));
        await tester.tap(find.text(l.commonConfirm));
        await tester.pumpAndSettle();
      }

      await filter(incoming ? l.accountOutflows : l.accountInflows);
      expect(row, findsNothing);
      await filter(l.accountAllFlows);
      expect(row, findsOneWidget);
      expect(await repo.getAccountBalance(accountId), incoming ? 0 : 865);
      await tester.pumpWidget(const SizedBox());
      // 清理生产 logger 的延迟落盘任务和 drift 的取消订阅定时器。
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
