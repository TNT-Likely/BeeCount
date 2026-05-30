import 'package:drift/drift.dart';
import 'package:collection/collection.dart';
import '../../data/db.dart';

/// 重复交易频率枚举
enum RecurringFrequency {
  daily('daily'),      // 每天
  weekly('weekly'),    // 每周
  monthly('monthly'),  // 每月
  yearly('yearly');    // 每年

  final String value;
  const RecurringFrequency(this.value);

  static RecurringFrequency fromString(String value) {
    return RecurringFrequency.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RecurringFrequency.monthly,
    );
  }
}

/// 重复交易服务
///
/// 注意：此服务主要用于生成待处理的周期交易记录
/// 基础的 CRUD 操作请使用 RecurringTransactionRepository
///
/// repository 参数可以是 BeeRepository 或 CloudRepository
class RecurringTransactionService {
  final dynamic repository;

  RecurringTransactionService(this.repository);

  /// 静态方法：生成待处理的重复交易（供启动时和初始化时调用）
  ///
  /// [repository] 可以是 BeeRepository 或 CloudRepository
  /// [verbose] 是否打印详细日志
  ///
  /// 返回：生成了交易的账本ID集合（用于触发同步）
  static Future<Set<int>> generatePendingTransactionsStatic({
    required dynamic repository,
    bool verbose = false,
  }) async {
    try {
      if (verbose) {
        print('🔄 [RecurringTransaction] 开始生成待处理的重复交易...');
        print('🔧 [RecurringTransaction] Repository类型: ${repository.runtimeType}');
      }

      final service = RecurringTransactionService(repository);
      final generatedTransactions = await service.generatePendingTransactions();

      if (generatedTransactions.isNotEmpty) {
        print('✅ [RecurringTransaction] 成功生成 ${generatedTransactions.length} 条重复交易记录');
        // 收集生成了交易的账本ID
        final ledgerIds = generatedTransactions.map((t) => t.ledgerId).toSet();
        return ledgerIds;
      } else {
        if (verbose) {
          print('ℹ️  [RecurringTransaction] 没有待生成的重复交易');
        }
        return {};
      }
    } catch (e, stackTrace) {
      print('❌ [RecurringTransaction] 生成重复交易失败: $e');
      if (verbose) {
        print('📍 [RecurringTransaction] 错误堆栈:');
        print(stackTrace.toString());
      }
      // 不抛出异常，避免影响应用启动
      return {};
    }
  }

  /// 计算下一次应该生成交易的日期
  DateTime? calculateNextDate(RecurringTransaction recurring) {
    final now = DateTime.now();
    final lastGenerated = recurring.lastGeneratedDate;
    final frequency = RecurringFrequency.fromString(recurring.frequency);
    final interval = recurring.interval;

    // 如果有结束日期且已过期，返回null
    if (recurring.endDate != null && now.isAfter(recurring.endDate!)) {
      return null;
    }

    // 基准日期：最后生成日期 或 开始日期。
    // 防止历史开始日期回溯补生成脏数据(issue #135):从未生成过(lastGenerated
    // 为 null)的周期账单,基准不早于今天零点,只面向未来生成,不补创建之前的历史。
    final todayStart = DateTime(now.year, now.month, now.day);
    final rawBase = lastGenerated ?? recurring.startDate;
    final baseDate = lastGenerated == null && rawBase.isBefore(todayStart)
        ? todayStart
        : rawBase;

    DateTime nextDate;
    switch (frequency) {
      case RecurringFrequency.daily:
        nextDate = baseDate.add(Duration(days: interval));
        break;

      case RecurringFrequency.weekly:
        nextDate = baseDate.add(Duration(days: 7 * interval));
        break;

      case RecurringFrequency.monthly:
        // 月度重复：使用指定的日期
        final targetDay = recurring.dayOfMonth ?? baseDate.day;
        var year = baseDate.year;
        var month = baseDate.month + interval;

        // 处理月份溢出
        while (month > 12) {
          month -= 12;
          year += 1;
        }

        // 处理不存在的日期（如2月30日）
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final day = targetDay > daysInMonth ? daysInMonth : targetDay;

        nextDate = DateTime(year, month, day);
        break;

      case RecurringFrequency.yearly:
        // 年度重复
        final targetMonth = recurring.monthOfYear ?? baseDate.month;
        final targetDay = recurring.dayOfMonth ?? baseDate.day;
        var year = baseDate.year + interval;

        // 处理闰年2月29日
        final daysInMonth = DateTime(year, targetMonth + 1, 0).day;
        final day = targetDay > daysInMonth ? daysInMonth : targetDay;

        nextDate = DateTime(year, targetMonth, day);
        break;
    }

    // 如果下一次日期还没到，返回null
    if (nextDate.isAfter(now)) {
      return null;
    }

    // 如果超过结束日期，返回null
    if (recurring.endDate != null && nextDate.isAfter(recurring.endDate!)) {
      return null;
    }

    return nextDate;
  }

  /// 生成待处理的交易记录
  Future<List<Transaction>> generatePendingTransactions() async {
    print('🔧 [RecurringTransactionService] 开始生成待处理的交易记录');

    print('🔧 [RecurringTransactionService] 正在获取所有账本...');
    final ledgers = await repository.getAllLedgers();
    print('✅ [RecurringTransactionService] 获取到 ${ledgers.length} 个账本');

    final generatedTransactions = <Transaction>[];

    for (final ledger in ledgers) {
      print('🔧 [RecurringTransactionService] 处理账本: ${ledger.name} (id=${ledger.id})');

      // 获取所有启用的周期交易
      print('🔧 [RecurringTransactionService] 正在获取周期交易...');
      final allRecurring = await repository.getAllRecurringTransactions();
      print('✅ [RecurringTransactionService] 获取到 ${allRecurring.length} 个周期交易');

      final recurringList = allRecurring
          .where((r) => r.ledgerId == ledger.id && r.enabled)
          .toList();
      print('📋 [RecurringTransactionService] 账本 ${ledger.name} 中有 ${recurringList.length} 个启用的周期交易');

      for (final recurring in recurringList) {
        print('🔧 [RecurringTransactionService] 处理周期交易: id=${recurring.id}');
        // 循环生成所有缺失的交易记录
        var currentRecurring = recurring;
        while (true) {
          final nextDate = calculateNextDate(currentRecurring);
          if (nextDate == null) break;

          // 生成交易记录
          final transactionId = await repository.addTransaction(
            ledgerId: currentRecurring.ledgerId,
            type: currentRecurring.type,
            amount: currentRecurring.amount,
            categoryId: currentRecurring.categoryId,
            accountId: currentRecurring.accountId,
            toAccountId: currentRecurring.toAccountId,
            happenedAt: nextDate,
            note: currentRecurring.note,
          );

          // 更新最后生成日期
          await repository.updateLastGeneratedDate(
            currentRecurring.id,
            nextDate,
          );

          // 使用流式查询获取生成的交易（取第一个）
          final transactionsWithCategory =
              await repository.transactionsWithCategoryAll(ledgerId: ledger.id).first;
          final matchedTransactions = transactionsWithCategory
              .where((e) => e.t.id == transactionId)
              .toList();
          final transaction = matchedTransactions.isNotEmpty
              ? matchedTransactions.first.t
              : null;

          if (transaction != null) {
            generatedTransactions.add(transaction);
          }

          // 重新读取更新后的重复交易记录，用于下一次循环
          final updatedList = await repository.getAllRecurringTransactions();
          final matchedRecurring =
              updatedList.where((r) => r.id == currentRecurring.id).toList();
          if (matchedRecurring.isEmpty) break;
          final updatedRecurring = matchedRecurring.first;
          currentRecurring = updatedRecurring;
        }
      }
    }

    return generatedTransactions;
  }

  /// 获取重复交易的描述文字
  String getFrequencyDescription(
    RecurringTransaction recurring,
    String Function(RecurringFrequency, int) translator,
  ) {
    final frequency = RecurringFrequency.fromString(recurring.frequency);
    return translator(frequency, recurring.interval);
  }

  /// 获取下一次生成时间的描述
  String? getNextGenerationDescription(
    RecurringTransaction recurring,
    String Function(DateTime) formatter,
  ) {
    final nextDate = calculateNextDate(recurring);
    if (nextDate == null) return null;
    return formatter(nextDate);
  }
}
