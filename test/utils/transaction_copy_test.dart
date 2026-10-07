import 'package:beecount/data/db.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/utils/shared_ledger_picker_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final oldDate = DateTime(2020, 1, 1);
  final now = DateTime(2026, 10, 7, 12, 34);
  Transaction source(String kind) => Transaction(
        id: 7,
        ledgerId: 2,
        type: kind,
        amount: 123,
        categoryId: 3,
        accountId: 4,
        toAccountId: kind == 'transfer' ? 5 : null,
        happenedAt: oldDate,
        note: 'Lunch',
        recurringId: 8,
        syncId: 'old-identity',
        createdByUserId: 'source-author',
        lastEditedByUserId: 'source-editor',
        excludeFromStats: true,
        excludeFromBudget: true,
        currencyCode: 'JPY',
        nativeAmount: 6.15,
      );

  for (final kind in ['expense', 'income', 'transfer']) {
    test('$kind copies business fields into a new editable transaction', () {
      final original = source(kind);
      final page = TransactionEditorPage.copy(
        source: original,
        tagIds: [9, 10],
        now: now,
      );
      expect(page.isCopy, isTrue);
      expect(page.editingTransactionId, isNull);
      expect(page.initialKind, kind);
      expect(page.initialCategoryId, 3);
      expect(page.initialAccountId, 4);
      expect(page.initialToAccountId, kind == 'transfer' ? 5 : null);
      expect(page.initialAmount, 123);
      expect(page.initialNote, 'Lunch');
      expect(page.initialTagIds, [9, 10]);
      expect(page.initialExcludeFromStats, isTrue);
      expect(page.initialExcludeFromBudget, isTrue);
      expect(page.initialCurrencyCode, 'JPY');
      expect(page.initialNativeAmount, 6.15);
      expect(page.initialDate, now);
      expect(original.happenedAt, oldDate);
      expect(original.syncId, 'old-identity');
      expect(original.recurringId, 8);
    });
  }

  test('shared references use the same synthetic IDs as resource pickers', () {
    final shared = Transaction(
      id: 1,
      ledgerId: 2,
      type: 'transfer',
      amount: 3,
      happenedAt: oldDate,
      excludeFromStats: false,
      excludeFromBudget: false,
      categorySyncIdOverride: 'shared-cat',
      accountSyncIdOverride: 'shared-from',
      toAccountSyncIdOverride: 'shared-to',
    );
    final page =
        TransactionEditorPage.copy(source: shared, tagIds: [-10], now: now);
    expect(page.initialCategoryId, syntheticIdForSyncId('shared-cat'));
    expect(page.initialAccountId, syntheticIdForSyncId('shared-from'));
    expect(page.initialToAccountId, syntheticIdForSyncId('shared-to'));
    expect(page.initialTagIds, [-10]);
  });

  test('empty account and note stay empty and input tag list is independent',
      () {
    final tags = <int>[];
    final empty = Transaction(
      id: 1,
      ledgerId: 2,
      type: 'expense',
      amount: 3,
      happenedAt: oldDate,
      excludeFromStats: false,
      excludeFromBudget: false,
    );
    final page =
        TransactionEditorPage.copy(source: empty, tagIds: tags, now: now);
    tags.add(10);
    expect(page.initialTagIds, isEmpty);
    expect(page.initialAccountId, isNull);
    expect(page.initialNote, isNull);
  });
}
