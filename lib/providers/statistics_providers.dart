import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_providers.dart';

// 统计：账本数量
final ledgerCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(repositoryProvider);
  // 依赖全局统计刷新 tick，确保手动刷新或恢复后能重新计算
  ref.watch(statsRefreshProvider);
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return repo.ledgerCount();
});

// 统计：某账本的记账天数与总笔数
final countsForLedgerProvider = FutureProvider.family
    .autoDispose<({int dayCount, int txCount}), int>((ref, ledgerId) async {
  final repo = ref.watch(repositoryProvider);
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return repo.countsForLedger(ledgerId: ledgerId);
});

// 统计刷新 tick（全局）：每次 +1 触发统计相关 Provider 重新获取
final statsRefreshProvider = StateProvider<int>((ref) => 0);

// 统计：全应用的记账天数与总笔数（跨账本聚合）
final lastCountsAllProvider =
    StateProvider<({int dayCount, int txCount})?>((ref) => null);

final countsAllProvider =
    FutureProvider.autoDispose<({int dayCount, int txCount})>((ref) async {
  final repo = ref.watch(repositoryProvider);
  // 依赖 tick 触发手动刷新
  ref.watch(statsRefreshProvider);
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  final res = await repo.countsAll();
  // 写入最近一次成功值，供 UI 在刷新期间显示旧值
  ref.read(lastCountsAllProvider.notifier).state = res;
  return res;
});

// 统计：当前账本总余额
final currentBalanceProvider =
    FutureProvider.family.autoDispose<double, int>((ref, ledgerId) async {
  final repo = ref.watch(repositoryProvider);
  // 依赖 tick 触发刷新
  ref.watch(statsRefreshProvider);
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return repo.getCurrentBalance(ledgerId: ledgerId);
});