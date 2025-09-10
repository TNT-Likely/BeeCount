import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers.dart';

/// 统一处理本地变更后的同步逻辑：
/// - 始终先标记本地变更（使缓存失效）
/// - 若开启自动同步：先上传，上传完成后刷新同步状态；支持后台静默（不阻塞UI）
/// - 若未开启自动同步：立即刷新同步状态（应显示“本地较新”）
Future<void> handleLocalChange(WidgetRef ref,
    {required int ledgerId, bool background = true}) async {
  // 失效缓存
  final sync = ref.read(syncServiceProvider);
  try {
    sync.markLocalChanged(ledgerId: ledgerId);
  } catch (_) {}

  // 检查是否自动同步
  bool auto = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    auto = prefs.getBool('auto_sync') ?? false;
  } catch (_) {}

  if (auto) {
    if (background) {
      final refresh = ref.read(syncStatusRefreshProvider.notifier);
      // 背景静默上传：完成后再刷新一次状态
      Future(() async {
        try {
          await sync.uploadCurrentLedger(ledgerId: ledgerId);
          refresh.state++;
        } catch (_) {}
      });
    } else {
      try {
        await sync.uploadCurrentLedger(ledgerId: ledgerId);
      } catch (_) {}
      ref.read(syncStatusRefreshProvider.notifier).state++;
    }
  } else {
    // 未开启自动同步：立刻刷新，显示“本地较新”
    ref.read(syncStatusRefreshProvider.notifier).state++;
  }
}
