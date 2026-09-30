import 'dart:convert';
import 'dart:io';

import 'package:beecount/agent/memory/local_agent_memory_repository.dart';
import 'package:beecount/agent/tools/local_agent_tools.dart';
import 'package:beecount/ai/core/ai_extraction_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/ai/ai_bookkeeper.dart';
import 'package:beecount/services/billing/bill_creation_service.dart';
import 'package:drift/native.dart';

/// Creates an isolated database for each scenario. All dates and amounts come
/// from a versioned fixture, never from the simulator or the user's database.
final class LedgerEvalFixture {
  LedgerEvalFixture._(this.database, this.repository, this.now, this.ledgers);

  final BeeDatabase database;
  final LocalRepository repository;
  final DateTime now;
  final Map<String, int> ledgers;

  static Future<LedgerEvalFixture> create() async {
    final data = jsonDecode(
            await File('test/ai_eval/fixtures/ledger_v1.json').readAsString())
        as Map;
    if (data['schemaVersion'] != 1) {
      throw const FormatException('Unknown ledger fixture version');
    }
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final repository = LocalRepository(db);
    try {
      final ledgers = <String, int>{};
      for (final row in data['ledgers'] as List) {
        final id = await repository.createLedger(
            name: row['name'] as String, currency: row['currency'] as String);
        ledgers[row['key'] as String] = id;
        await repository.updateLedger(
            id: id, monthStartDay: row['monthStartDay'] as int);
      }
      final categories = <String, int>{};
      for (final row in data['categories'] as List) {
        final parent = row['parent'] as String?;
        categories[row['key'] as String] = await repository.createCategory(
          name: row['name'] as String,
          kind: row['kind'] as String,
          parentId: parent == null ? null : categories[parent],
          level: parent == null ? 1 : 2,
        );
      }
      final accounts = <String, int>{};
      for (final row in data['accounts'] as List) {
        accounts[row['key'] as String] = await repository.createAccount(
          ledgerId: ledgers[row['ledger']]!,
          name: row['name'] as String,
          currency: row['currency'] as String,
        );
      }
      for (final row in data['transactions'] as List) {
        final amount = (row['amount'] as num).toDouble();
        await repository.addTransaction(
          ledgerId: ledgers[row['ledger']]!,
          type: row['type'] as String,
          amount: amount,
          categoryId: categories[row['category']],
          accountId: accounts[row['account']],
          toAccountId: accounts[row['toAccount']],
          happenedAt: DateTime.parse(row['date'] as String),
          note: row['note'] as String?,
          excludeFromStats: row['excludeFromStats'] == true,
          currencyCode: row['currency'] as String? ?? 'CNY',
          nativeAmount: (row['nativeAmount'] as num?)?.toDouble() ?? amount,
        );
      }
      return LedgerEvalFixture._(
          db, repository, DateTime.parse(data['now'] as String), ledgers);
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  LocalAgentMemoryRepository get memory => LocalAgentMemoryRepository(database);

  BeeCountLocalAgentToolGateway get gateway => BeeCountLocalAgentToolGateway(
        repository: repository,
        database: database,
        memoryRepository: memory,
        bookkeeper: AiBookkeeper(
          repository: repository,
          engine: const DefaultAiExtractionEngine(),
          persister: BillCreationService(repository),
        ),
      );

  Future<int> transactionCount() async =>
      (await database.select(database.transactions).get()).length;
  Future<void> close() => database.close();
}
