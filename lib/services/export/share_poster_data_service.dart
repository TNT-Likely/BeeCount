/// 分享海报数据计算服务
library;

import '../../data/repositories/base_repository.dart';
import '../../utils/month_range.dart';
import '../ui/avatar_service.dart';
import 'share_poster_types.dart';

/// 海报数据计算服务
class SharePosterDataService {
  final BaseRepository repository;

  const SharePosterDataService(this.repository);

  /// 计算年度总结海报数据
  Future<YearSummaryPosterData> calculateYearSummary({
    required int ledgerId,
    required int year,
  }) async {
    // 时间范围:年 = 12 个自定义周期(design D4),[start, end) 半开
    final ledger = await repository.getLedgerById(ledgerId);
    final sd = (ledger?.monthStartDay ?? 1).clamp(1, 28);
    final yr = yearRangeFor(year, sd);
    final startDate = yr.start;
    final endDate = yr.end;

    // 1. 获取指定年份的所有交易记录(用于计算天数和笔数)
    final yearTransactions = await repository.getTransactionsByLedger(ledgerId);

    // 筛选出当年(周期口径)的交易
    final yearTxs = yearTransactions.where((tx) {
      return !tx.happenedAt.isBefore(startDate) && tx.happenedAt.isBefore(endDate);
    }).toList();

    // 计算记账天数(按日期去重)
    final recordDays = yearTxs.map((tx) {
      final date = tx.happenedAt;
      return DateTime(date.year, date.month, date.day);
    }).toSet().length;

    final recordCount = yearTxs.length;

    // 2. 计算总收入和总支出
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    final Map<int, double> monthlyExpenses = {};

    // 遍历12个月
    for (int month = 1; month <= 12; month++) {
      final monthStart = DateTime(year, month, 1);

      final (income, expense) = await repository.monthlyTotals(
        ledgerId: ledgerId,
        month: monthStart,
      );

      totalIncome += income;
      totalExpense += expense;
      monthlyExpenses[month] = expense;
    }

    // 3. 找出最高支出月份
    int? maxExpenseMonth;
    double? maxExpenseAmount;
    if (monthlyExpenses.isNotEmpty) {
      final maxEntry = monthlyExpenses.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      maxExpenseMonth = maxEntry.key;
      maxExpenseAmount = maxEntry.value;
    }

    // 4. 计算TOP分类
    final expenseCategories = await repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'expense',
      start: startDate,
      end: endDate,
    );

    final incomeCategories = await repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'income',
      start: startDate,
      end: endDate,
    );

    // 转换为CategoryTotal并计算占比
    final topExpenseCategories = _convertToCategoryTotals(
      expenseCategories.take(3).toList(),
      totalExpense,
    );

    final topIncomeCategories = _convertToCategoryTotals(
      incomeCategories.take(3).toList(),
      totalIncome,
    );

    // 5. 计算月均收支
    final avgMonthlyExpense = totalExpense / 12;
    final avgMonthlyIncome = totalIncome / 12;

    // 6. 计算结余
    final balance = totalIncome - totalExpense;

    return YearSummaryPosterData(
      year: year,
      recordDays: recordDays,
      recordCount: recordCount,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      topExpenseCategories: topExpenseCategories,
      topIncomeCategories: topIncomeCategories,
      avgMonthlyExpense: avgMonthlyExpense,
      avgMonthlyIncome: avgMonthlyIncome,
      maxExpenseMonth: maxExpenseMonth,
      maxExpenseAmount: maxExpenseAmount,
      balance: balance,
    );
  }

  /// 计算月度总结海报数据
  Future<MonthSummaryPosterData> calculateMonthSummary({
    required int ledgerId,
    required int year,
    required int month,
  }) async {
    // 时间范围:按账本起始日的记账周期 [当月sd日, 次月sd日)。
    // startDate 的 year/month 与标签一致,可直接作 monthlyTotals 的标签参数。
    final ledger = await repository.getLedgerById(ledgerId);
    final sd = (ledger?.monthStartDay ?? 1).clamp(1, 28);
    final range = periodForLabel(year, month, sd);
    final startDate = range.start;
    final endDate = range.end;

    // 上月标签(用于计算环比,monthlyTotals 标签语义)
    final prevMonthStart = DateTime(year, month - 1, 1);

    // 1. 计算本月收入和支出
    final (totalIncome, totalExpense) = await repository.monthlyTotals(
      ledgerId: ledgerId,
      month: startDate,
    );

    // 2. 计算上月支出(用于环比)
    double? expenseChangeRate;
    try {
      final (_, prevExpense) = await repository.monthlyTotals(
        ledgerId: ledgerId,
        month: prevMonthStart,
      );

      if (prevExpense > 0) {
        expenseChangeRate = (totalExpense - prevExpense) / prevExpense;
      }
    } catch (e) {
      // 如果获取上月数据失败,忽略环比
      expenseChangeRate = null;
    }

    // 3. 获取本月的记账笔数
    final monthTransactions = await repository.getTransactionsByLedgerInRange(
      ledgerId: ledgerId,
      start: startDate,
      end: endDate,
    );
    final recordCount = monthTransactions.length;

    // 4. 计算TOP分类
    final expenseCategories = await repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'expense',
      start: startDate,
      end: endDate,
    );

    final incomeCategories = await repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'income',
      start: startDate,
      end: endDate,
    );

    // 转换为CategoryTotal并计算占比
    final topExpenseCategories = _convertToCategoryTotals(
      expenseCategories.take(3).toList(),
      totalExpense,
    );

    final topIncomeCategories = _convertToCategoryTotals(
      incomeCategories.take(3).toList(),
      totalIncome,
    );

    // 5. 计算日均支出
    final daysInMonth = endDate.difference(startDate).inDays;
    final avgDailyExpense = daysInMonth > 0 ? totalExpense / daysInMonth : 0.0;

    // 6. 计算结余
    final balance = totalIncome - totalExpense;

    return MonthSummaryPosterData(
      year: year,
      month: month,
      recordCount: recordCount,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      topExpenseCategories: topExpenseCategories,
      topIncomeCategories: topIncomeCategories,
      avgDailyExpense: avgDailyExpense,
      balance: balance,
      expenseChangeRate: expenseChangeRate,
    );
  }

  /// 计算账本总结海报数据
  Future<LedgerSummaryPosterData> calculateLedgerSummary({
    required int ledgerId,
  }) async {
    // 获取账本统计信息（包含余额和交易数）
    final ledgerStats = await repository.getLedgerStats(ledgerId: ledgerId);
    final recordCount = ledgerStats.transactionCount;

    // 获取账本名称
    final ledger = await repository.getLedgerById(ledgerId);
    final ledgerName = ledger?.name ?? '默认账本';

    // 使用年度序列来计算所有年份的收支
    final yearSeries = await repository.totalsByYearSeries(
      ledgerId: ledgerId,
      type: 'expense',
    );

    // 计算所有年份的收入和支出
    double totalIncome = 0.0;
    double totalExpense = 0.0;

    // 获取所有涉及的年份
    final Set<int> years = {};
    if (yearSeries.isNotEmpty) {
      for (final entry in yearSeries) {
        years.add(entry.year);
      }
    }

    // 为每一年计算收入和支出
    for (final year in years) {
      for (int month = 1; month <= 12; month++) {
        final monthStart = DateTime(year, month, 1);
        final (income, expense) = await repository.monthlyTotals(
          ledgerId: ledgerId,
          month: monthStart,
        );
        totalIncome += income;
        totalExpense += expense;
      }
    }

    // 如果没有年份数据，说明没有交易记录
    if (years.isEmpty) {
      totalIncome = 0.0;
      totalExpense = 0.0;
    }

    // 计算记账天数和日期范围
    int recordDays = 0;
    DateTime? firstRecordDate;
    DateTime? lastRecordDate;

    final countsResult = await repository.getCountsForLedger(ledgerId: ledgerId);
    recordDays = countsResult.dayCount;

    // 获取第一笔和最后一笔交易的时间
    if (recordCount > 0) {
      final firstTx = await repository.getFirstTransactionByLedger(ledgerId);
      final lastTx = await repository.getLastTransactionByLedger(ledgerId);

      if (firstTx != null) {
        firstRecordDate = firstTx.happenedAt;
      }
      if (lastTx != null) {
        lastRecordDate = lastTx.happenedAt;
      }
    }

    // 计算TOP分类 (使用所有时间范围)
    final startDate = DateTime(1970, 1, 1);
    final endDate = DateTime.now().add(const Duration(days: 1));

    final expenseCategories = await repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'expense',
      start: startDate,
      end: endDate,
    );

    final incomeCategories = await repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'income',
      start: startDate,
      end: endDate,
    );

    // 转换为CategoryTotal并计算占比
    final topExpenseCategories = _convertToCategoryTotals(
      expenseCategories.take(3).toList(),
      totalExpense,
    );

    final topIncomeCategories = _convertToCategoryTotals(
      incomeCategories.take(3).toList(),
      totalIncome,
    );

    // 计算结余
    final balance = totalIncome - totalExpense;

    return LedgerSummaryPosterData(
      ledgerName: ledgerName,
      recordDays: recordDays,
      recordCount: recordCount,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      topExpenseCategories: topExpenseCategories,
      topIncomeCategories: topIncomeCategories,
      firstRecordDate: firstRecordDate,
      lastRecordDate: lastRecordDate,
      balance: balance,
    );
  }

  /// 计算用户档案海报数据
  Future<UserProfilePosterData> calculateUserProfile({
    required int ledgerId,
  }) async {
    // 获取用户头像路径
    final avatarPath = await AvatarService.getAvatarPath();

    // 获取当前账本信息
    final ledger = await repository.getLedgerById(ledgerId);
    final ledgerName = ledger?.name ?? '默认账本';

    // 获取所有账本数量
    final allLedgers = await repository.getAllLedgers();
    final ledgerCount = allLedgers.length;

    // 获取当前账本的统计数据
    final countsResult = await repository.getCountsForLedger(ledgerId: ledgerId);
    final recordDays = countsResult.dayCount;

    // 获取当前账本的交易总数
    final ledgerStats = await repository.getLedgerStats(ledgerId: ledgerId);
    final recordCount = ledgerStats.transactionCount;

    // 获取第一笔交易的时间
    DateTime? firstRecordDate;
    if (recordCount > 0) {
      final firstTx = await repository.getFirstTransactionByLedger(ledgerId);
      if (firstTx != null) {
        firstRecordDate = firstTx.happenedAt;
      }
    }

    return UserProfilePosterData(
      avatarPath: avatarPath,
      recordDays: recordDays,
      recordCount: recordCount,
      ledgerCount: ledgerCount,
      ledgerName: ledgerName,
      firstRecordDate: firstRecordDate,
    );
  }

  /// 将仓库数据转换为CategoryTotal列表
  List<CategoryTotal> _convertToCategoryTotals(
    List<({int? id, String name, String? icon, double total})> categories,
    double totalAmount,
  ) {
    if (categories.isEmpty || totalAmount <= 0) {
      return [];
    }

    return categories.map((cat) {
      final percentage = cat.total / totalAmount;
      return CategoryTotal(
        id: cat.id,
        name: cat.name,
        icon: cat.icon,
        total: cat.total,
        percentage: percentage,
      );
    }).toList();
  }
}
