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

// For now, always use default ledger id 1
final currentLedgerIdProvider = StateProvider<int>((ref) => 1);

// Currently selected month (first day), default to now
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

// 视角：'month' 或 'year'
final selectedViewProvider = StateProvider<String>((ref) => 'month');
