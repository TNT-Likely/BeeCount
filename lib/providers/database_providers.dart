import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/db.dart';
import '../data/repository.dart';
import 'sync_providers.dart';

// 数据库Provider
final databaseProvider = Provider<BeeDatabase>((ref) {
  final db = BeeDatabase();
  // fire-and-forget seed
  db.ensureSeed();
  ref.onDispose(() => db.close());
  return db;
});

// 仓储Provider
final repositoryProvider = Provider<BeeRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BeeRepository(db);
});

// 记住当前账本：启动时加载，切换时持久化
final currentLedgerIdProvider = StateProvider<int>((ref) => 1);

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
  final db = ref.watch(databaseProvider);
  return await db.select(db.categories).get();
});