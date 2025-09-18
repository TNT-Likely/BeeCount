import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as s;
import '../config.dart';
import '../cloud/cloud_service_config.dart';
import '../cloud/cloud_service_store.dart';
import '../utils/logger.dart';
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

// ====== 云服务动态配置 ======

// 内置配置（不展示真实 URL/Key）
final builtinCloudConfigProvider = Provider<CloudServiceConfig>((ref) {
  return CloudServiceConfig.builtinDefault(
    url: AppConfig.supabaseUrl,
    key: AppConfig.supabaseAnonKey,
  );
});

final cloudServiceStoreProvider =
    Provider<CloudServiceStore>((_) => CloudServiceStore());

// 当前激活配置（Future，因需读 SharedPreferences）
final activeCloudConfigProvider =
    FutureProvider<CloudServiceConfig>((ref) async {
  final builtin = ref.watch(builtinCloudConfigProvider);
  final store = ref.watch(cloudServiceStoreProvider);
  return store.loadActive(builtin);
});

// 首次全量上传标记
final firstFullUploadPendingProvider = FutureProvider<bool>((ref) async {
  final store = ref.watch(cloudServiceStoreProvider);
  return store.isFirstFullUploadPending();
});

// 已保存（未必激活）的自定义配置（用于 UI 在默认模式下展示"可启用"）
final storedCustomCloudConfigProvider =
    FutureProvider<CloudServiceConfig?>((ref) async {
  final store = ref.watch(cloudServiceStoreProvider);
  return store.loadCustom();
});

// Supabase Client Provider：
// 1) 自定义配置 -> 创建独立 client 实例（不依赖全局 initialize）
// 2) 内置配置 -> 若启动时已 initialize 则使用单例；否则返回 null
final supabaseClientProvider = Provider<s.SupabaseClient?>((ref) {
  final activeAsync = ref.watch(activeCloudConfigProvider);
  if (!activeAsync.hasValue) return null;
  final cfg = activeAsync.value!;
  if (!cfg.valid) return null;
  if (cfg.builtin) {
    if (AppConfig.hasSupabase) {
      return s.Supabase.instance.client;
    }
    return null;
  }
  // 自定义：创建独立 client（避免多次 initialize 冲突）
  logI('cloudCfg', '使用自定义 Supabase Client (${cfg.obfuscatedUrl()})');
  return s.SupabaseClient(
    cfg.supabaseUrl!,
    cfg.supabaseAnonKey!,
    // 使用 implicit 流程，避免需要 PKCE asyncStorage（便于动态创建客户端）
    authOptions:
        const s.AuthClientOptions(authFlowType: s.AuthFlowType.implicit),
  );
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
