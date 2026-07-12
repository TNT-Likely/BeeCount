import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db.dart';
import '../providers.dart';

/// 当前选中的日历月份（默认当前月）
final calendarSelectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// 当前选中的日期（默认 null，未选中任何日期）
final calendarSelectedDateProvider = StateProvider<DateTime?>((ref) => null);

/// 获取指定月份的每日统计
/// 参数: (ledgerId, month)
final dailyTotalsByMonthProvider = FutureProvider.autoDispose
    .family<Map<String, (double, double)>, ({int ledgerId, DateTime month})>(
  (ref, params) async {
    // 监听刷新触发器
    ref.watch(calendarRefreshProvider);

    final repo = ref.watch(repositoryProvider);
    return repo.getDailyTotalsByMonth(
      ledgerId: params.ledgerId,
      month: params.month,
    );
  },
);

/// 获取选中日期的交易详情
/// 参数: (ledgerId, date)
final transactionsByDateProvider = FutureProvider.autoDispose.family<
    List<
        ({
          Transaction t,
          Category? category,
          List<Tag> tags,
          List<TransactionAttachment> attachments,
          Account? account,
        })>,
    ({int ledgerId, DateTime date})>(
  (ref, params) async {
    // 监听刷新触发器
    ref.watch(calendarRefreshProvider);

    final repo = ref.watch(repositoryProvider);
    return repo.getTransactionsByDate(
      ledgerId: params.ledgerId,
      date: params.date,
    );
  },
);

/// 获取指定月份有交易的日期列表
/// 参数: (ledgerId, month)
final transactionDatesByMonthProvider = FutureProvider.autoDispose
    .family<List<String>, ({int ledgerId, DateTime month})>(
  (ref, params) async {
    // 监听刷新触发器
    ref.watch(calendarRefreshProvider);

    final repo = ref.watch(repositoryProvider);
    return repo.getTransactionDatesByMonth(
      ledgerId: params.ledgerId,
      month: params.month,
    );
  },
);

/// 获取指定时间范围的交易列表（用于当月交易列表）
/// 参数: (ledgerId, startDate, endDate)
final monthTransactionsProvider = FutureProvider.autoDispose.family<
    List<
        ({
          Transaction t,
          Category? category,
          List<Tag> tags,
          List<TransactionAttachment> attachments,
          Account? account,
        })>,
    ({int ledgerId, DateTime startDate, DateTime endDate})>(
  (ref, params) async {
    // 监听刷新触发器
    ref.watch(calendarRefreshProvider);

    final repo = ref.watch(repositoryProvider);

    // 查询时间范围内的所有交易
    final transactions = await repo.getTransactionsByDateRange(
      ledgerId: params.ledgerId,
      startDate: params.startDate,
      endDate: params.endDate,
    );

    return transactions;
  },
);

/// 日历刷新触发器（添加/删除交易后触发）
final calendarRefreshProvider = StateProvider<int>((ref) => 0);
