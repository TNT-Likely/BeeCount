import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/account_detail_page.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/styles/tokens.dart';
import 'package:beecount/widgets/biz/amount_text.dart';

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
              of: row, matching: find.text('转账  (信用卡还款)', findRichText: true)),
          findsOneWidget);
      final amount = tester.widget<AmountText>(
          find.descendant(of: row, matching: find.byType(AmountText)));
      expect(amount.value, incoming ? 135 : -135);
      expect(amount.signed, isTrue);
      expect(amount.style?.color, BeeTokens.textPrimary(tester.element(row)));
      expect(tester.takeException(), isNull);
      expect(await repo.getAccountBalance(accountId), incoming ? 0 : 865);
      expect(await repo.getAccountCategoryStats(accountId, type: 'income'), isEmpty);
      expect(await repo.getAccountCategoryStats(accountId, type: 'expense'), isEmpty);
      await tester.ensureVisible(find.text(incoming ? '支出与转出' : '收入与转入'));
      await tester.tap(find.text(incoming ? '支出与转出' : '收入与转入'));
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      await tester.tap(find.text('全部流水'));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(await repo.getAccountBalance(accountId), incoming ? 0 : 865);
      await tester.pumpWidget(const SizedBox());
      // 清理生产 logger 的延迟落盘任务和 drift 的取消订阅定时器。
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
