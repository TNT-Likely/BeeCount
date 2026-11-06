import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:beecount/data/db.dart';

void main() {
  test('v33 到 v34 只接续无历史贷款并保留账户身份与估值', () async {
    final dir = Directory.systemTemp.createTempSync('loan-migration-');
    final file = File('${dir.path}/fixture.sqlite');
    var db = BeeDatabase.forTesting(NativeDatabase(file));
    try {
      await db.customStatement(
          "INSERT INTO ledgers (id, name) VALUES (1, 'fixture')");
      await db.customStatement(
          "INSERT INTO accounts (id, ledger_id, name, type, initial_balance, sync_id, hidden, note) VALUES (1, 1, '旧无历史贷款', 'loan', -30000, 'stable', 1, 'retain'), (2, 1, '旧有历史贷款', 'loan', -50000, 'history', 0, null), (3, 1, '房产', 'real_estate', 800000, 'house', 0, null)");
      await db.customStatement(
          "INSERT INTO transactions (ledger_id, type, amount, to_account_id) VALUES (1, 'transfer', 1000, 2)");
      await db.close();
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('ALTER TABLE accounts DROP COLUMN loan_balance_since');
      raw.execute('ALTER TABLE accounts DROP COLUMN loan_balance_version');
      raw.execute('PRAGMA user_version = 33');
      raw.dispose();
      db = BeeDatabase.forTesting(NativeDatabase(file));
      final accounts = await db.select(db.accounts).get();
      final a = accounts.singleWhere((a) => a.id == 1);
      expect(a.loanBalanceVersion, 1);
      expect(a.initialBalance, -30000);
      expect(a.syncId, 'stable');
      expect(a.hidden, true);
      expect(a.note, 'retain');
      expect(accounts.singleWhere((a) => a.id == 2).loanBalanceVersion, 0);
      expect(accounts.singleWhere((a) => a.id == 3).initialBalance, 800000);
      expect((await db.select(db.transactions).get()).length, 1);
      final changes = await db.select(db.localChanges).get();
      expect(
          changes
              .where((c) =>
                  c.entityType == 'account' && c.entitySyncId == 'stable')
              .length,
          1);
    } finally {
      await db.close();
      dir.deleteSync(recursive: true);
    }
  });
}
