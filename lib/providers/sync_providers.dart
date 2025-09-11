import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as s;
import '../config.dart';
import '../cloud/auth.dart';
import '../cloud/sync.dart';
import '../cloud/supabase_auth.dart';
import '../cloud/supabase_sync.dart';
import 'database_providers.dart';

// 同步状态（根据 ledgerId 与刷新 tick 缓存），避免因 UI 重建重复拉取
final syncStatusProvider =
    FutureProvider.family.autoDispose<SyncStatus, int>((ref, ledgerId) async {
  final sync = ref.watch(syncServiceProvider);
  // 依赖 tick，使得手动刷新时重新获取；否则保持缓存
  ref.watch(syncStatusRefreshProvider);
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  // 显式清理缓存，确保"刷新同步状态（临时）"能强制重新拉取
  try {
    sync.markLocalChanged(ledgerId: ledgerId);
  } catch (_) {}
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

// 登录后请求"我的"页弹窗检查云端备份（一次性标记）
final restoreCheckRequestProvider = StateProvider<bool>((ref) => false);