import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/db.dart';
import 'data/repository.dart';
import 'theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'cloud/auth.dart';
import 'cloud/sync.dart';
import 'cloud/supabase_auth.dart';
import 'cloud/supabase_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as s;

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// 可变主色（个性化换装使用）
final primaryColorProvider = StateProvider<Color>((ref) => BeeTheme.honeyGold);

// 是否隐藏金额显示
final hideAmountsProvider = StateProvider<bool>((ref) => false);

// 主题色持久化初始化：
// - 启动时加载保存的主色
// - 监听主色变化并写入本地
final primaryColorInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getInt('primaryColor');
  if (saved != null) {
    ref.read(primaryColorProvider.notifier).state = Color(saved);
  }
  ref.listen<Color>(primaryColorProvider, (prev, next) async {
    await prefs.setInt('primaryColor', next.value);
  });
});

final databaseProvider = Provider<BeeDatabase>((ref) {
  final db = BeeDatabase();
  // fire-and-forget seed
  db.ensureSeed();
  ref.onDispose(() => db.close());
  return db;
});

final repositoryProvider = Provider<BeeRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BeeRepository(db);
});

// 统计：账本数量
final ledgerCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(repositoryProvider);
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

// 同步状态（根据 ledgerId 与刷新 tick 缓存），避免因 UI 重建重复拉取
final syncStatusProvider =
    FutureProvider.family.autoDispose<SyncStatus, int>((ref, ledgerId) async {
  final sync = ref.watch(syncServiceProvider);
  // 依赖 tick，使得手动刷新时重新获取；否则保持缓存
  ref.watch(syncStatusRefreshProvider);
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  final status = await sync.getStatus(ledgerId: ledgerId);
  // 写入最近一次成功值，供 UI 在刷新期间显示旧值，避免闪烁
  ref.read(lastSyncStatusProvider(ledgerId).notifier).state = status;
  return status;
});

// 最近一次同步状态缓存（按 ledgerId）
final lastSyncStatusProvider =
    StateProvider.family<SyncStatus?, int>((ref, ledgerId) => null);

// 自动同步开关：值与设置
final autoSyncValueProvider = FutureProvider.autoDispose<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return prefs.getBool('auto_sync') ?? false;
});

class AutoSyncSetter {
  AutoSyncSetter(this._ref);
  final Ref _ref;
  Future<void> set(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync', v);
    // 使缓存失效，触发读取最新值
    _ref.invalidate(autoSyncValueProvider);
  }
}

final autoSyncSetterProvider = Provider<AutoSyncSetter>((ref) {
  return AutoSyncSetter(ref);
});

// Auth 与 Sync 抽象：未配置时使用 Noop/LocalOnly；配置后使用 Supabase
final supabaseClientProvider = Provider<s.SupabaseClient?>((ref) {
  if (AppConfig.supabaseUrl.isEmpty || AppConfig.supabaseAnonKey.isEmpty) {
    return null;
  }
  return s.Supabase.instance.client;
});

final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return NoopAuthService();
  return SupabaseAuthService(client);
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final db = ref.watch(databaseProvider);
  final repo = ref.watch(repositoryProvider);
  final auth = ref.watch(authServiceProvider);
  if (client == null) return LocalOnlySyncService();
  return SupabaseSyncService(client: client, db: db, repo: repo, auth: auth);
});

// 用于触发设置页同步状态的刷新（每次 +1 即可触发 FutureBuilder 重新获取）
final syncStatusRefreshProvider = StateProvider<int>((ref) => 0);

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

// 当账本切换时，顺便触发一次设置页状态刷新（确保“我的”页及时反映）
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

// Currently selected month (first day), default to now
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

// 视角：'month' 或 'year'
final selectedViewProvider = StateProvider<String>((ref) => 'month');

// 导入任务进度：用于显示“后台导入中”状态与进度
class ImportProgress {
  final bool running;
  final int total;
  final int done;
  final int ok;
  final int fail;
  const ImportProgress({
    required this.running,
    required this.total,
    required this.done,
    required this.ok,
    required this.fail,
  });
  ImportProgress copyWith({
    bool? running,
    int? total,
    int? done,
    int? ok,
    int? fail,
  }) =>
      ImportProgress(
        running: running ?? this.running,
        total: total ?? this.total,
        done: done ?? this.done,
        ok: ok ?? this.ok,
        fail: fail ?? this.fail,
      );
  static const empty =
      ImportProgress(running: false, total: 0, done: 0, ok: 0, fail: 0);
}

final importProgressProvider =
    StateProvider<ImportProgress>((ref) => ImportProgress.empty);
