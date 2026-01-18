import 'dart:async';

import 'package:flutter_cloud_sync_supabase/flutter_cloud_sync_supabase.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import '../../db.dart';
import '../ledger_repository.dart';

/// 云端账本Repository实现
/// 基于 Supabase 实现
class CloudLedgerRepository implements LedgerRepository {
  final SupabaseProvider supabase;

  CloudLedgerRepository(this.supabase);

  @override
  Stream<List<Ledger>> watchLedgers() {
    // 使用 Realtime 订阅账本变化
    final controller = StreamController<List<Ledger>>();

    // 立即获取初始数据
    _fetchLedgers().then((ledgers) {
      if (!controller.isClosed) {
        controller.add(ledgers);
      }
    });

    // 创建 Realtime 频道
    final channel = supabase.realtimeService!.channel('ledgers');

    // 监听所有变化
    channel.onPostgresChanges(
      event: '*',
      schema: 'public',
      table: 'ledgers',
      callback: (payload) async {
        // 数据变化时重新获取
        try {
          final ledgers = await _fetchLedgers();
          if (!controller.isClosed) {
            controller.add(ledgers);
          }
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }
      },
    );

    // 订阅频道
    channel.subscribe();

    // 清理资源
    controller.onCancel = () {
      channel.unsubscribe();
    };

    return controller.stream;
  }

  /// 获取所有账本
  Future<List<Ledger>> _fetchLedgers() async {
    final results = await supabase.databaseService!.query(
      table: 'ledgers',
      orderBy: 'created_at',
    );

    return results.map((data) => _ledgerFromJson(data)).toList();
  }

  @override
  Future<List<Ledger>> getAllLedgers() async {
    return _fetchLedgers();
  }

  @override
  Future<Ledger?> getLedgerById(int id) async {
    final results = await supabase.databaseService!.query(
      table: 'ledgers',
      filters: [QueryFilter(column: 'id', operator: 'eq', value: id)],
    );

    if (results.isEmpty) return null;
    return _ledgerFromJson(results.first);
  }

  @override
  Future<int> getLedgerCount() async {
    final results = await supabase.databaseService!.query(table: 'ledgers');
    return results.length;
  }

  @override
  Future<int> ledgerCount() => getLedgerCount();

  @override
  Future<({int dayCount, int txCount})> getCountsForLedger({
    required int ledgerId,
  }) async {
    // 查询交易数量
    final transactions = await supabase.databaseService!.query(
      table: 'transactions',
      filters: [QueryFilter(column: 'ledger_id', operator: 'eq', value: ledgerId)],
    );

    final txCount = transactions.length;

    // 计算记账天数
    int dayCount = 0;
    if (transactions.isNotEmpty) {
      final dates = transactions
          .map((t) => DateTime.parse(t['happened_at'] as String))
          .map((dt) => DateTime(dt.year, dt.month, dt.day))
          .toSet();

      if (dates.isNotEmpty) {
        final minDate = dates.reduce((a, b) => a.isBefore(b) ? a : b);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        dayCount = today.difference(minDate).inDays + 1;
      }
    }

    return (dayCount: dayCount, txCount: txCount);
  }

  @override
  Future<({int dayCount, int txCount})> getCountsAll() async {
    // 查询所有交易
    final transactions = await supabase.databaseService!.query(
      table: 'transactions',
    );

    final txCount = transactions.length;

    // 计算记账天数
    int dayCount = 0;
    if (transactions.isNotEmpty) {
      final dates = transactions
          .map((t) => DateTime.parse(t['happened_at'] as String))
          .map((dt) => DateTime(dt.year, dt.month, dt.day))
          .toSet();

      if (dates.isNotEmpty) {
        final minDate = dates.reduce((a, b) => a.isBefore(b) ? a : b);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        dayCount = today.difference(minDate).inDays + 1;
      }
    }

    return (dayCount: dayCount, txCount: txCount);
  }

  @override
  Future<({double balance, int transactionCount})> getLedgerStats({
    required int ledgerId,
    bool accountFeatureEnabled = true,
    List<Transaction>? transactions,
  }) async {
    // 如果没有传入 transactions，则查询
    List<Map<String, dynamic>> txData;
    if (transactions == null) {
      txData = await supabase.databaseService!.query(
        table: 'transactions',
        filters: [QueryFilter(column: 'ledger_id', operator: 'eq', value: ledgerId)],
      );
    } else {
      // 使用传入的交易列表（需要转换）
      txData = transactions.map((t) => _transactionToJson(t)).toList();
    }

    final transactionCount = txData.length;
    double balance = 0.0;

    for (final t in txData) {
      final type = t['type'] as String;
      final amount = (t['amount'] as num).toDouble();

      if (type == 'income') {
        balance += amount;
      } else if (type == 'expense') {
        balance -= amount;
      } else if (type == 'adjustment') {
        // 平账交易：根据金额的正负来决定增加或减少余额
        balance += amount;
      }
      // transfer 不影响总余额
    }

    return (balance: balance, transactionCount: transactionCount);
  }

  @override
  Future<int> createLedger({
    required String name,
    String currency = 'CNY',
  }) async {
    final result = await supabase.databaseService!.insert(
      table: 'ledgers',
      data: {
        'name': name,
        'currency': currency,
        'type': 'personal',  // 默认创建个人账本
        'user_id': supabase.client?.auth.currentUser?.id,
      },
    );

    return result['id'] as int;
  }

  @override
  Future<void> updateLedgerName({required int id, required String name}) async {
    await supabase.databaseService!.update(
      table: 'ledgers',
      id: id.toString(),
      data: {'name': name},
    );
  }

  @override
  Future<void> updateLedger({
    required int id,
    String? name,
    String? currency,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (currency != null) data['currency'] = currency;

    if (data.isNotEmpty) {
      await supabase.databaseService!.update(
        table: 'ledgers',
        id: id.toString(),
        data: data,
      );
    }
  }

  @override
  Future<void> deleteLedger(int id) async {
    await supabase.databaseService!.delete(
      table: 'ledgers',
      id: id.toString(),
    );
  }

  @override
  Future<int> getMaxLedgerId() async {
    final results = await supabase.databaseService!.query(
      table: 'ledgers',
      orderBy: 'id',
      descending: true,
      limit: 1,
    );

    if (results.isEmpty) return 0;
    return results.first['id'] as int;
  }

  @override
  Future<int> getNextFreeLedgerId() async {
    final maxId = await getMaxLedgerId();
    return maxId + 1;
  }

  @override
  Future<void> reassignLedgerId({
    required int fromId,
    required int toId,
  }) async {
    // 云端不支持 ID 重新分配（PostgreSQL BIGSERIAL 自动递增）
    throw UnsupportedError('云端模式不支持账本 ID 重新分配');
  }

  @override
  Future<int> clearLedgerTransactions(int ledgerId) async {
    final transactions = await supabase.databaseService!.query(
      table: 'transactions',
      filters: [QueryFilter(column: 'ledger_id', operator: 'eq', value: ledgerId)],
    );

    for (final tx in transactions) {
      await supabase.databaseService!.delete(
        table: 'transactions',
        id: tx['id'].toString(),
      );
    }

    return transactions.length;
  }

  @override
  Future<double> getTotalInitialBalance(int ledgerId) async {
    final accounts = await supabase.databaseService!.query(
      table: 'accounts',
      filters: [QueryFilter(column: 'ledger_id', operator: 'eq', value: ledgerId)],
    );

    double total = 0.0;
    for (final account in accounts) {
      total += (account['initial_balance'] as num).toDouble();
    }
    return total;
  }

  // ============================================
  // 辅助方法：数据转换
  // ============================================

  /// 从 JSON 转换为 Ledger 对象
  Ledger _ledgerFromJson(Map<String, dynamic> json) {
    return Ledger(
      id: json['id'] as int,
      name: json['name'] as String,
      currency: json['currency'] as String? ?? 'CNY',
      type: json['type'] as String? ?? 'personal',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// 从 Transaction 转换为 JSON（用于统计）
  Map<String, dynamic> _transactionToJson(Transaction t) {
    return {
      'id': t.id,
      'ledger_id': t.ledgerId,
      'type': t.type,
      'amount': t.amount,
      'category_id': t.categoryId,
      'account_id': t.accountId,
      'to_account_id': t.toAccountId,
      'happened_at': t.happenedAt.toIso8601String(),
      'note': t.note,
    };
  }
}
