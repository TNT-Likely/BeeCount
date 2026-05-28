import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/db.dart';
import '../data/repositories/local/local_repository.dart';
import '../data/repositories/base_repository.dart';
import '../cloud/sync/change_tracker.dart';
import '../services/system/logger_service.dart';
import '../utils/shared_ledger_picker_filter.dart';
import 'shared_ledger_providers.dart';
import 'sync_providers.dart';

// 数据库Provider
final databaseProvider = Provider<BeeDatabase>((ref) {
  final db = BeeDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// 仓储Provider — 一律 LocalRepository(本地优先 + ChangeTracker 推 BeeCount Cloud)。
// 历史上还有过 CloudRepository(数据全存 Supabase),但 BeeCount Cloud 上线后
// 整条范式从「云优先」迁到「本地优先 + 推送」,Cloud* 仓库整组随之删掉。
final repositoryProvider = Provider<BaseRepository>((ref) {
  final db = ref.watch(databaseProvider);

  // 仅 BeeCount Cloud 后端激活时注入 ChangeTracker(记录增量变更供同步引擎推送)。
  // 其它备份后端(iCloud / WebDAV / S3 / Supabase)走快照备份路径,不需要变更追踪。
  final config = ref.watch(activeCloudConfigProvider).valueOrNull;
  final tracker = (config?.type == CloudBackendType.beecountCloud && config!.valid)
      ? ChangeTracker(db)
      : null;
  logger.info('RepositoryProvider', '✅ LocalRepository (changeTracker=${tracker != null})');
  return LocalRepository(db, changeTracker: tracker);
});

// 记住当前账本：启动时加载，切换时持久化
final currentLedgerIdProvider = StateProvider<int>((ref) => 1);

// 获取当前账本的详细信息
final currentLedgerProvider = FutureProvider<Ledger?>((ref) async {
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final repo = ref.watch(repositoryProvider);

  return await repo.getLedgerById(ledgerId);
});

// 获取指定账本的详细信息
final ledgerByIdProvider = FutureProvider.family<Ledger?, int>((ref, ledgerId) async {
  final repo = ref.watch(repositoryProvider);

  return await repo.getLedgerById(ledgerId);
});

// 获取所有账本列表（Stream版本）
final ledgersStreamProvider = StreamProvider<List<Ledger>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchLedgers();
});

final _currentLedgerPersist = Provider<void>((ref) {
  // load on first read
  () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('current_ledger_id');
      if (saved != null) {
        final st = ref.read(currentLedgerIdProvider);
        if (st != saved) {
          ref.read(currentLedgerIdProvider.notifier).state = saved;
        }
      }
    } catch (_) {}
  }();
  // persist on change
  ref.listen<int>(currentLedgerIdProvider, (prev, next) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_ledger_id', next);
    } catch (_) {}
  });
});

// 当账本切换时，顺便触发一次设置页状态刷新（确保"我的"页及时反映）
final _ledgerChangeListener = Provider<void>((ref) {
  // 激活持久化监听
  ref.read(_currentLedgerPersist);
  ref.listen<int>(currentLedgerIdProvider, (prev, next) {
    ref.read(syncStatusRefreshProvider.notifier).state++;
  });
});

// 确保监听器被激活
final appInitProvider = FutureProvider<void>((ref) async {
  // 读取以激活监听
  ref.read(_ledgerChangeListener);
});

// 分类Provider
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  // 同步代数 bump 后重算，让 web 改分类能立即反映到 mobile。
  ref.watch(syncGenerationProvider);
  final repo = ref.watch(repositoryProvider);
  return await repo.getAllCategories();
});

// 分类与交易笔数组合Provider（响应式版本）
// 使用 autoDispose 在页面关闭时自动取消订阅
final categoriesWithCountProvider = StreamProvider.autoDispose<List<({Category category, int transactionCount})>>((ref) {
  final repo = ref.watch(repositoryProvider);
  // §7 决策 v25:Owner 资源不再 mirror 主表,管理页直接读主 Categories
  // 自然只看到用户自己 user-global 行,无需过滤。
  return repo.watchCategoriesWithCount();
});

// 虚拟转账分类Provider（全局缓存，用于获取转账图标）
final transferCategoryProvider = FutureProvider<Category>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return await repo.getTransferCategory();
});

// 重复交易Provider（按账本过滤）
// 注意：此 provider 已废弃，请使用 allRecurringTransactionsProvider 并在业务层过滤
final recurringTransactionsProvider = FutureProvider.family<List<RecurringTransaction>, int>((ref, ledgerId) async {
  final repo = ref.watch(repositoryProvider);
  final all = await repo.watchRecurringTransactionsByLedger(ledgerId).first;
  return all;
});

// 所有重复交易Provider（不限账本）
final allRecurringTransactionsProvider = StreamProvider.autoDispose<List<RecurringTransaction>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchAllRecurringTransactions();
});

// 账户Provider（按账本过滤）
final accountsStreamProvider = StreamProvider.family<List<Account>, int>((ref, ledgerId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchAccountsForLedger(ledgerId);
});

// v1.15.0: 所有账户Provider（不限账本）
final allAccountsStreamProvider = StreamProvider<List<Account>>((ref) {
  final repo = ref.watch(repositoryProvider);
  logger.info('AllAccountsStream', '使用的 Repository 类型: ${repo.runtimeType}');
  final stream = repo.watchAllAccounts();
  return stream;
});

// §7 v25:tx 反查账户 — 综合考虑 accountId int + accountSyncIdOverride。
// Editor 在共享账本下记的 tx,accountId 是 null,override 是 Owner's syncId,
// 走 SharedLedgerAccounts 表反查 → 转 synthetic Account 返回。
final accountForTxProvider =
    FutureProvider.family<Account?, ({int? accountId, String? syncIdOverride})>(
        (ref, key) async {
  ref.watch(syncGenerationProvider);
  // §7 共享账本:WS shared_resource_change 推送时也强制重算,跟 picker /
  // 洞察 等其它 widget 监听同一个 tick 一致;否则共享账户改名 tx 列表
  // 不刷新。
  ref.watch(sharedResourceRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  if (key.accountId != null && key.accountId! >= 0) {
    return await repo.getAccount(key.accountId!);
  }
  final ov = key.syncIdOverride;
  if (ov == null || ov.isEmpty) return null;
  final shared = await repo.getSharedAccountBySyncId(ov);
  if (shared == null) return null;
  return Account(
    // 用 syntheticIdForSyncId 而不是 -1 — 跟 picker / 详情页路径统一,
    // 避免不同 syncId 全部撞到同一个 id。
    id: syntheticIdForSyncId(shared.syncId),
    ledgerId: 0,
    name: shared.name,
    type: shared.accountType,
    currency: shared.currency,
    initialBalance: shared.initialBalance ?? 0.0,
    createdAt: null,
    updatedAt: null,
    sortOrder: 0,
    creditLimit: shared.creditLimit,
    billingDay: shared.billingDay,
    paymentDueDay: shared.paymentDueDay,
    bankName: shared.bankName,
    cardLastFour: shared.cardLastFour,
    note: shared.note,
    syncId: shared.syncId,
  );
});

// 获取单个账户信息
final accountByIdProvider = FutureProvider.family<Account?, int>((ref, accountId) async {
  ref.watch(syncGenerationProvider);
  final repo = ref.watch(repositoryProvider);
  return await repo.getAccount(accountId);
});