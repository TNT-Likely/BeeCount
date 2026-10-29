import 'dart:convert';
import 'dart:io';
import 'package:beecount/cloud/transactions_sync_manager.dart';
import 'package:beecount/cloud/transactions_json.dart';
import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/data/repositories/transaction_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' as cloud;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends cloud.NoopAuthService {
  @override
  Future<cloud.CloudUser?> get currentUser async =>
      const cloud.CloudUser(id: 'qa');
}

class _Storage extends cloud.NoopStorageService {
  String? value;
  @override
  Future<String?> download({required String path}) async => value;
}

class _Provider implements cloud.CloudProvider {
  _Provider(this.storage);
  @override
  final _Storage storage;
  @override
  cloud.CloudAuthService get auth => _Auth();
  @override
  String get providerId => 'qa';
  @override
  String get providerName => 'QA';
  @override
  Future<void> initialize(Map<String, dynamic> config) async {}
  @override
  bool validateConfig(Map<String, dynamic> config) => true;
  @override
  Future<void> dispose() async {}
}

class _Repo extends LocalRepository {
  _Repo(super.db) : super(changeTracker: ChangeTracker(db));
  bool shortResult = false;
  @override
  Future<List<int>> insertTransactionsBatchWithRelations(
      {required List<TransactionsCompanion> transactions,
      Map<int, List<int>> tagIdsByIndex = const {},
      Map<int, List<BatchAttachmentData>> attachmentsByIndex = const {},
      bool recordChanges = true}) async {
    final ids = await super.insertTransactionsBatchWithRelations(
        transactions: transactions,
        tagIdsByIndex: tagIdsByIndex,
        attachmentsByIndex: attachmentsByIndex,
        recordChanges: recordChanges);
    return shortResult && ids.isNotEmpty ? ids.sublist(1) : ids;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late _Repo repo;
  late _Storage storage;
  late TransactionsSyncManager manager;
  late Directory files;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'hideAmounts': true});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repo(db);
    storage = _Storage();
    files = await Directory.systemTemp.createTemp('beecount-r95-legacy-');
    await File('${files.path}/shared.jpg').writeAsBytes([1, 2, 3, 4]);
    await File('${files.path}/target-only.jpg').writeAsBytes([5, 6, 7]);
    manager = TransactionsSyncManager(
        config: const cloud.CloudServiceConfig(
            type: cloud.CloudBackendType.webdav,
            name: 'QA',
            webdavUrl: 'https://qa.invalid',
            webdavUsername: 'qa',
            webdavPassword: 'synthetic'),
        db: db,
        repo: repo,
        provider: _Provider(storage));
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'Target','CNY'),(2,'Other','USD')");
    await db.customStatement(
        "INSERT INTO accounts(id,ledger_id,name,type,currency,initial_balance) VALUES(1,0,'Shared account','cash','USD',123)");
    await db.customStatement(
        "INSERT INTO categories(id,name,kind,icon) VALUES(1,'Shared food','expense','restaurant')");
    await db.customStatement(
        "INSERT INTO tags(id,name,color) VALUES(1,'Shared tag','#123456')");
    await db.customStatement(
        "INSERT INTO transactions(id,ledger_id,type,amount,happened_at,note,sync_id,account_id,category_id,currency_code,native_amount,exclude_from_stats,exclude_from_budget) VALUES(1,1,'expense',10,1792454400,'target old','old-target',1,1,'USD',72,1,1),(2,2,'expense',80,1792454400,'other stays','other-book',1,1,'USD',80,0,1)");
    await db.customStatement(
        "INSERT INTO transaction_tags(transaction_id,tag_id) VALUES(1,1),(2,1)");
    await db.customStatement(
        "INSERT INTO transaction_attachments(transaction_id,file_name,sort_order) VALUES(1,'shared.jpg',0),(1,'target-only.jpg',1),(2,'shared.jpg',0)");
    await db.customStatement(
        "INSERT INTO transaction_tag_overrides(transaction_sync_id,tag_sync_id,created_at) VALUES('old-target','shared-tag',1792454400),('other-book','other-tag',1792454400)");
    await repo.upsertAutoRates(
        base: 'CNY',
        rateDate: '2026-10-20',
        rates: {'USD': '7.2'},
        source: 'qa',
        fetchedAt: DateTime.utc(2026, 10, 20));
  });
  tearDown(() async {
    await db.close();
    await files.delete(recursive: true);
  });
  Map<String, dynamic> backup({List<Map<String, dynamic>>? items}) {
    final rows = items ??
        [
          {
            'type': 'expense',
            'amount': 12.0,
            'happenedAt': '2026-10-20T00:00:00Z',
            'note': 'restored',
            'categoryName': 'Shared food',
            'categoryKind': 'expense',
            'accountName': 'Shared account',
            'currencyCode': 'USD',
            'nativeAmount': 86.4,
            'excludeFromStats': true,
            'excludeFromBudget': true,
            'tags': 'Shared tag,New tag',
            'attachments': [
              {
                'fileName': 'shared.jpg',
                'originalName': 'receipt.jpg',
                'sortOrder': 0,
                'cloudFileId': 'qa-file',
                'cloudSha256': 'qa-hash'
              }
            ]
          },
          {
            'type': 'income',
            'amount': 5.0,
            'happenedAt': '2026-10-21T00:00:00Z',
            'note': 'restored second',
            'currencyCode': 'CNY',
            'nativeAmount': 5.0
          },
        ];
    return {
      'version': 5,
      'count': rows.length,
      'ledgerName': 'Restored target',
      'currency': 'CNY',
      'accounts': [
        {
          'name': 'Shared account',
          'type': 'cash',
          'currency': 'USD',
          'initialBalance': 999
        }
      ],
      'categories': [
        {
          'name': 'Shared food',
          'kind': 'expense',
          'level': 1,
          'icon': 'changed-icon'
        }
      ],
      'tags': [
        {'name': 'Shared tag', 'color': '#abcdef'},
        {'name': 'New tag', 'color': '#678901'}
      ],
      'items': rows
    };
  }

  Future<Map<String, List<Map<String, dynamic>>>> snapshot() async {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final table in [
      'ledgers',
      'transactions',
      'transaction_tags',
      'transaction_attachments',
      'transaction_tag_overrides',
      'accounts',
      'categories',
      'tags',
      'exchange_rates',
      'exchange_rate_overrides',
      'local_changes'
    ]) {
      result[table] =
          (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
              .map((r) => r.data)
              .toList();
    }
    return result;
  }

  Future<void> expectUnchanged(Future<void> Function() attempt) async {
    final before = await snapshot();
    await expectLater(attempt(), throwsA(anything));
    expect(await snapshot(), before);
    expect(await File('${files.path}/shared.jpg').readAsBytes(), [1, 2, 3, 4]);
    expect(
        await File('${files.path}/target-only.jpg').readAsBytes(), [5, 6, 7]);
    expect(
        (await SharedPreferences.getInstance()).getBool('hideAmounts'), isTrue);
  }

  Map<String, dynamic> signedRefunds() => backup(items: [
        {
          'type': 'expense',
          'amount': -12.0,
          'happenedAt': '2026-10-20T00:00:00Z',
          'note': 'refund expense',
          'accountName': 'Shared account',
          'currencyCode': 'USD',
          'nativeAmount': -86.4
        },
        {
          'type': 'income',
          'amount': -5.0,
          'happenedAt': '2026-10-21T00:00:00Z',
          'note': 'reversed income',
          'accountName': 'Shared account',
          'currencyCode': 'USD',
          'nativeAmount': -36.0
        },
      ]);
  Map<String, dynamic> historicalTransfer() {
    final value = backup(items: [
      {
        'type': 'transfer',
        'amount': 7.5,
        'happenedAt': '2026-10-20T00:00:00Z',
        'note': 'historic cross currency',
        'fromAccountName': 'Shared account',
        'toAccountName': 'Historic EUR',
        'currencyCode': 'USD',
        'nativeAmount': 54.0
      },
    ]);
    (value['accounts'] as List).add({
      'name': 'Historic EUR',
      'type': 'cash',
      'currency': 'EUR',
      'initialBalance': 50.0
    });
    return value;
  }

  Future<List<Transaction>> originalImport(Map<String, dynamic> value) async {
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(3,'Original parser target','CNY')");
    final result = await importTransactionsJson(repo, 3, jsonEncode(value),
        recordChanges: false);
    expect(result.inserted, (value['items'] as List).length);
    return (db.select(db.transactions)..where((t) => t.ledgerId.equals(3)))
        .get();
  }

  test('原parse/import实际接受负支出退款与负收入并保留signed余额语义', () async {
    final rows = await originalImport(signedRefunds());
    expect({for (final row in rows) row.type: (row.amount, row.nativeAmount)},
        {'expense': (-12.0, -86.4), 'income': (-5.0, -36.0)});
    expect(rows, hasLength(2));
    expect(await repo.getAccountBalanceInLedger(1, 3), 7.0);
  });
  test('原parse/import实际接受历史USD转EUR且转入仍为原amount', () async {
    final rows = await originalImport(historicalTransfer());
    final tx = rows.single;
    final target = (await repo.getAllAccounts())
        .singleWhere((a) => a.name == 'Historic EUR');
    expect(tx.accountId, 1);
    expect(tx.toAccountId, target.id);
    expect(tx.amount, 7.5);
    expect(tx.currencyCode, 'USD');
    expect(tx.nativeAmount, 54.0);
    expect(await repo.getAccountBalanceInLedger(1, 3), -7.5);
    expect(await repo.getAccountBalanceInLedger(target.id, 3), 7.5);
  });
  test('原子恢复兼容负支出和负收入signed快照且另一账本未改变', () async {
    final baseline = await originalImport(signedRefunds());
    final otherBefore = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(2)))
        .get();
    storage.value = jsonEncode(signedRefunds());
    final result =
        await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    expect(result.inserted, 2);
    final rows = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(1)))
        .get();
    expect(rows.map((x) => x.amount), baseline.map((x) => x.amount));
    expect(
        rows.map((x) => x.nativeAmount), baseline.map((x) => x.nativeAmount));
    expect(rows.every((x) => x.currencyCode == 'USD'), true);
    expect(await repo.getAccountBalanceInLedger(1, 1),
        await repo.getAccountBalanceInLedger(1, 3));
    expect(
        await (db.select(db.transactions)..where((t) => t.ledgerId.equals(2)))
            .get(),
        otherBefore);
  });
  test('原子恢复兼容历史跨币种转账且不新造转入金额', () async {
    final baseline = (await originalImport(historicalTransfer())).single;
    storage.value = jsonEncode(historicalTransfer());
    final result =
        await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    expect(result.inserted, 1);
    final tx = (await (db.select(db.transactions)
              ..where((t) => t.ledgerId.equals(1)))
            .get())
        .single;
    expect(tx.accountId, baseline.accountId);
    expect(tx.toAccountId, baseline.toAccountId);
    expect(tx.amount, baseline.amount);
    expect(tx.nativeAmount, baseline.nativeAmount);
    expect(tx.currencyCode, baseline.currencyCode);
    expect(await repo.getAccountBalanceInLedger(1, 1), -7.5);
    expect(await repo.getAccountBalanceInLedger(tx.toAccountId!, 1), 7.5);
    expect(await repo.getAccountBalanceInLedger(tx.toAccountId!, 1),
        await repo.getAccountBalanceInLedger(tx.toAccountId!, 3));
  });
  test('负金额原手工signed汇率快照逐字保留不重算', () async {
    final value = signedRefunds();
    (value['items'] as List).first['nativeAmount'] = -84.125;
    storage.value = jsonEncode(value);
    await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    final row = (await (db.select(db.transactions)
              ..where((t) => t.note.equals('refund expense')))
            .get())
        .single;
    expect(row.amount, -12.0);
    expect(row.nativeAmount, -84.125);
  });
  test('负金额缺历史快照时沿原有效汇率得到signed结果', () async {
    final value = signedRefunds();
    for (final row in value['items'] as List) {
      (row as Map).remove('nativeAmount');
    }
    storage.value = jsonEncode(value);
    await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    final rows = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(1)))
        .get();
    expect({for (final row in rows) row.type: row.nativeAmount},
        {'expense': -86.4, 'income': -36.0});
    expect(rows, hasLength(2));
  });
  for (final field in ['amount', 'nativeAmount']) {
    test('signed兼容仍拒绝非有限数并保持全库原状态 $field', () async {
      final raw = jsonEncode(backup());
      final needle =
          field == 'amount' ? '"amount":12.0' : '"nativeAmount":86.4';
      expect(raw, contains(needle));
      storage.value = raw.replaceFirst(needle, '"$field":1e999');
      await expectUnchanged(() async {
        await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
      });
    });
  }
  test('完整旧格式原子替换仅当前账本，附件/标签/旗标/外币快照精确保留', () async {
    final otherBefore = (await db
            .customSelect('SELECT * FROM transactions WHERE ledger_id=2')
            .get())
        .single
        .data;
    storage.value = jsonEncode(backup());
    final result =
        await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    expect(result.inserted, 2);
    final restored = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(1)))
        .get();
    expect(restored.length, 2);
    expect(restored.any((t) => t.note == 'target old'), isFalse);
    final first = restored.firstWhere((t) => t.note == 'restored');
    expect(first.currencyCode, 'USD');
    expect(first.nativeAmount, 86.4);
    expect(first.excludeFromStats, isTrue);
    expect(first.excludeFromBudget, isTrue);
    expect(first.accountId, 1);
    expect(first.categoryId, 1);
    expect(
        (await db
                .customSelect('SELECT * FROM transactions WHERE ledger_id=2')
                .get())
            .single
            .data,
        otherBefore);
    expect((await repo.getAllAccounts()).single.initialBalance, 123);
    expect((await repo.getAllTags()).firstWhere((t) => t.id == 1).color,
        '#123456');
    expect(
        (await db.select(db.transactionAttachments).get())
            .map((a) => a.fileName),
        ['shared.jpg', 'shared.jpg']);
    final metadata = (await (db.select(db.transactionAttachments)
              ..where((a) => a.transactionId.equals(first.id)))
            .get())
        .single;
    expect(metadata.cloudFileId, 'qa-file');
    expect(metadata.cloudSha256, 'qa-hash');
    expect(
        (await (db.select(db.transactionTags)
                  ..where((t) => t.transactionId.equals(first.id)))
                .get())
            .length,
        2);
    expect(
        (await db.select(db.transactionTagOverrides).get())
            .single
            .transactionSyncId,
        'other-book');
    expect(await File('${files.path}/shared.jpg').readAsBytes(), [1, 2, 3, 4]);
    expect(await File('${files.path}/target-only.jpg').exists(), isTrue);
    expect(
        (await SharedPreferences.getInstance()).getBool('hideAmounts'), isTrue);
    expect((await repo.getLatestAutoRates('CNY')).single.rate, '7.2');
  });
  test('显式空备份仅清空当前账本，另一本及物理文件保留', () async {
    storage.value = jsonEncode(backup(items: []));
    final result =
        await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    expect(result.inserted, 0);
    expect((await db.select(db.transactions).get()).single.ledgerId, 2);
    expect(
        (await db.select(db.transactionAttachments).get()).single.transactionId,
        2);
    expect(await File('${files.path}/target-only.jpg').exists(), isTrue);
  });
  for (final broken in [
    '{',
    '{}',
    '{"version":5,"count":1,"items":[]}',
    '{"version":6,"items":[]}'
  ]) {
    test('损坏、缺失结构、数量不符及现代格式在删除前拒绝 $broken', () async {
      storage.value = broken;
      await expectUnchanged(() async {
        await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
      });
    });
  }
  test('备份在确认后消失，拒绝而非清空', () async {
    storage.value = null;
    await expectUnchanged(() async {
      await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    });
  });
  for (final field in [
    'amount',
    'nativeAmount',
    'excludeFromStats',
    'currencyCode',
    'happenedAt',
    'attachments'
  ]) {
    test('全部字段预校验不因坏记录清空当前账本 $field', () async {
      final data = backup();
      final row = (data['items'] as List).first as Map<String, dynamic>;
      row[field] = switch (field) {
        'amount' => 'bad',
        'nativeAmount' => 'bad',
        'excludeFromStats' => 1,
        'currencyCode' => '?',
        'happenedAt' => 'not-a-date',
        _ => [
            {'fileName': '../escape.jpg'}
          ]
      };
      storage.value = jsonEncode(data);
      await expectUnchanged(() async {
        await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
      });
    });
  }
  for (final invalid in ['type', 'categoryKind', 'transfer']) {
    test('交易语义全量验证拒绝无效类型或不完整转账 $invalid', () async {
      final data = backup();
      final row = (data['items'] as List).first as Map<String, dynamic>;
      if (invalid == 'type') {
        row['type'] = 'unsupported';
      }
      if (invalid == 'categoryKind') {
        row['categoryKind'] = 'balance';
      }
      if (invalid == 'transfer') {
        row['type'] = 'transfer';
      }
      storage.value = jsonEncode(data);
      await expectUnchanged(() async {
        await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
      });
    });
  }
  test('真实SQLite第二条插入失败，整批事务和资源创建回滚', () async {
    final data = backup();
    ((data['items'] as List)[1] as Map<String, dynamic>)['note'] = 'reject';
    storage.value = jsonEncode(data);
    await db.customStatement(
        "CREATE TRIGGER qa_reject BEFORE INSERT ON transactions WHEN NEW.note='reject' BEGIN SELECT RAISE(ABORT,'QA row rejected'); END");
    await expectUnchanged(() async {
      await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    });
  });
  test('附件关系插入失败回滚交易、标签及原附件关系', () async {
    storage.value = jsonEncode(backup());
    await db.customStatement(
        "CREATE TRIGGER qa_reject_attachment BEFORE INSERT ON transaction_attachments WHEN NEW.cloud_file_id='qa-file' BEGIN SELECT RAISE(ABORT,'QA attachment rejected'); END");
    await expectUnchanged(() async {
      await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    });
  });
  test('返回部分笔数不能算成功，已写入批次和资源全部回滚', () async {
    repo.shortResult = true;
    storage.value = jsonEncode(backup());
    await expectUnchanged(() async {
      await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    });
  });
  test('跨账本syncId冲突拒绝并保持两本账全部关系', () async {
    final data = backup();
    ((data['items'] as List).first as Map<String, dynamic>)['syncId'] =
        'other-book';
    storage.value = jsonEncode(data);
    await expectUnchanged(() async {
      await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    });
  });
  test('已有全局账户币种冲突不修改另一账本资源', () async {
    final data = backup();
    ((data['accounts'] as List).first as Map<String, dynamic>)['currency'] =
        'JPY';
    storage.value = jsonEncode(data);
    await expectUnchanged(() async {
      await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    });
  });
  test('缺历史汇率且无原始快照时拒绝静默1比1替换', () async {
    await db.customStatement('DELETE FROM exchange_rates');
    final data = backup();
    ((data['items'] as List).first as Map<String, dynamic>)
        .remove('nativeAmount');
    storage.value = jsonEncode(data);
    await expectUnchanged(() async {
      await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    });
  });
  test('无原始快照但有有效汇率使用原纯计算，不改汇率表', () async {
    final data = backup();
    ((data['items'] as List).first as Map<String, dynamic>)
        .remove('nativeAmount');
    storage.value = jsonEncode(data);
    await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    expect(
        (await db.select(db.transactions).get())
            .firstWhere((t) => t.note == 'restored')
            .nativeAmount,
        closeTo(86.4, 1e-10));
    expect((await repo.getLatestAutoRates('CNY')).single.rate, '7.2');
  });
  test('只读共享角色在任何清空前拒绝', () async {
    await db.customStatement(
        "UPDATE ledgers SET is_shared=1,my_role='viewer' WHERE id=1");
    storage.value = jsonEncode(backup());
    await expectUnchanged(() async {
      await manager.restoreLegacyBackupToCurrentLedger(ledgerId: 1);
    });
  });
}
