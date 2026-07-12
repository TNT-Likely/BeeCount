import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers.dart';
import '../../cloud/sync/sync_engine.dart';
import '../attachment_service.dart';
import '../system/logger_service.dart';

/// 数据变更后的统一后处理服务
///
/// 两类方法：
/// - `run` 系列：交易创建后使用，刷新统计 + 可选刷新标签/附件 + 同步
/// - `sync` 系列：其他数据变更后使用（分类、账户等），仅同步
class PostProcessor {
  // ============ 交易后完整处理 ============

  /// UI 层使用（WidgetRef）
  static Future<void> run(
    WidgetRef ref, {
    required int ledgerId,
    bool tags = false,
    bool attachments = false,
  }) async {
    ref.read(statsRefreshProvider.notifier).state++;
    if (tags) ref.read(tagListRefreshProvider.notifier).state++;
    if (attachments) ref.read(attachmentListRefreshProvider.notifier).state++;
    await _doSync(ref, ledgerId);
  }

  /// 后台服务使用（ProviderContainer）
  static Future<void> runC(
    ProviderContainer c, {
    required int ledgerId,
    bool tags = false,
    bool attachments = false,
  }) async {
    c.read(statsRefreshProvider.notifier).state++;
    if (tags) c.read(tagListRefreshProvider.notifier).state++;
    if (attachments) c.read(attachmentListRefreshProvider.notifier).state++;
    await _doSyncC(c, ledgerId);
  }

  /// Provider 内部使用（Ref）
  static Future<void> runR(
    Ref ref, {
    required int ledgerId,
    bool tags = false,
    bool attachments = false,
  }) async {
    ref.read(statsRefreshProvider.notifier).state++;
    if (tags) ref.read(tagListRefreshProvider.notifier).state++;
    if (attachments) ref.read(attachmentListRefreshProvider.notifier).state++;
    await _doSyncR(ref, ledgerId);
  }

  // ============ 仅同步 ============

  /// UI 层使用（WidgetRef）
  static Future<void> sync(WidgetRef ref, {required int ledgerId}) =>
      _doSync(ref, ledgerId);

  /// 后台服务使用（ProviderContainer）
  static Future<void> syncC(ProviderContainer c, {required int ledgerId}) =>
      _doSyncC(c, ledgerId);

  /// Provider 内部使用（Ref）
  static Future<void> syncR(Ref ref, {required int ledgerId}) =>
      _doSyncR(ref, ledgerId);

  // ============ 云端下载后处理（仅刷新，不触发同步） ============

  /// 云端下载后的处理：刷新统计和UI状态，但不触发同步上传
  /// UI 层使用（WidgetRef）
  static void runAfterDownload(WidgetRef ref) {
    ref.read(statsRefreshProvider.notifier).state++;
    ref.read(syncStatusRefreshProvider.notifier).state++;
    ref.read(ledgerListRefreshProvider.notifier).state++;
    ref.read(tagListRefreshProvider.notifier).state++;
    ref.read(attachmentListRefreshProvider.notifier).state++;
    logger.info('PostProcessor', '云端下载后刷新完成');
  }

  /// 云端下载后的处理：刷新统计和UI状态，但不触发同步上传
  /// 后台服务使用（ProviderContainer）
  static void runAfterDownloadC(ProviderContainer c) {
    c.read(statsRefreshProvider.notifier).state++;
    c.read(syncStatusRefreshProvider.notifier).state++;
    c.read(ledgerListRefreshProvider.notifier).state++;
    c.read(tagListRefreshProvider.notifier).state++;
    c.read(attachmentListRefreshProvider.notifier).state++;
    logger.info('PostProcessor', '云端下载后刷新完成');
  }

  // ============ 内部同步实现 ============

  static Future<void> _doSync(WidgetRef ref, int ledgerId) async {
    final sync = ref.read(syncServiceProvider);
    try {
      sync.markLocalChanged(ledgerId: ledgerId);
    } catch (_) {}

    ref.read(syncStatusRefreshProvider.notifier).state++;
    ref.read(ledgerListRefreshProvider.notifier).state++;

    // BeeCount Cloud：始终自动双向同步
    if (sync is SyncEngine) {
      final refresh = ref.read(syncStatusRefreshProvider.notifier);
      Future(() async {
        try {
          await sync.sync(ledgerId: ledgerId.toString());
          refresh.state++;
          logger.info(
              'PostProcessor', 'BeeCount Cloud 自动同步完成', 'ledgerId=$ledgerId');
        } catch (e) {
          logger.error('PostProcessor', 'BeeCount Cloud 自动同步失败', e);
        }
      });
      return;
    }

    // 其他 provider：检查 auto_sync 开关
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('auto_sync') ?? false) {
      final refresh = ref.read(syncStatusRefreshProvider.notifier);
      Future(() async {
        try {
          await sync.uploadCurrentLedger(ledgerId: ledgerId);
          refresh.state++;
          logger.info('PostProcessor', '后台同步完成', 'ledgerId=$ledgerId');
        } catch (e) {
          logger.error('PostProcessor', '后台同步失败', e);
        }
      });
    }
  }

  static Future<void> _doSyncC(ProviderContainer c, int ledgerId) async {
    final sync = c.read(syncServiceProvider);
    try {
      sync.markLocalChanged(ledgerId: ledgerId);
    } catch (_) {}

    c.read(syncStatusRefreshProvider.notifier).state++;
    c.read(ledgerListRefreshProvider.notifier).state++;

    // BeeCount Cloud：始终自动双向同步
    if (sync is SyncEngine) {
      final refresh = c.read(syncStatusRefreshProvider.notifier);
      Future(() async {
        try {
          await sync.sync(ledgerId: ledgerId.toString());
          refresh.state++;
          logger.info(
              'PostProcessor', 'BeeCount Cloud 自动同步完成', 'ledgerId=$ledgerId');
        } catch (e) {
          logger.error('PostProcessor', 'BeeCount Cloud 自动同步失败', e);
        }
      });
      return;
    }

    // 其他 provider：检查 auto_sync 开关
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('auto_sync') ?? false) {
      final refresh = c.read(syncStatusRefreshProvider.notifier);
      Future(() async {
        try {
          await sync.uploadCurrentLedger(ledgerId: ledgerId);
          refresh.state++;
          logger.info('PostProcessor', '后台同步完成', 'ledgerId=$ledgerId');
        } catch (e) {
          logger.error('PostProcessor', '后台同步失败', e);
        }
      });
    }
  }

  static Future<void> _doSyncR(Ref ref, int ledgerId) async {
    final sync = ref.read(syncServiceProvider);
    try {
      sync.markLocalChanged(ledgerId: ledgerId);
    } catch (_) {}

    ref.read(syncStatusRefreshProvider.notifier).state++;
    ref.read(ledgerListRefreshProvider.notifier).state++;

    // BeeCount Cloud：始终自动双向同步
    if (sync is SyncEngine) {
      final refresh = ref.read(syncStatusRefreshProvider.notifier);
      Future(() async {
        try {
          await sync.sync(ledgerId: ledgerId.toString());
          refresh.state++;
          logger.info(
              'PostProcessor', 'BeeCount Cloud 自动同步完成', 'ledgerId=$ledgerId');
        } catch (e) {
          logger.error('PostProcessor', 'BeeCount Cloud 自动同步失败', e);
        }
      });
      return;
    }

    // 其他 provider：检查 auto_sync 开关
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('auto_sync') ?? false) {
      final refresh = ref.read(syncStatusRefreshProvider.notifier);
      Future(() async {
        try {
          await sync.uploadCurrentLedger(ledgerId: ledgerId);
          refresh.state++;
          logger.info('PostProcessor', '后台同步完成', 'ledgerId=$ledgerId');
        } catch (e) {
          logger.error('PostProcessor', '后台同步失败', e);
        }
      });
    }
  }
}
