import 'dart:io';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../ai/providers/ai_provider_config.dart';
import '../../ai/providers/ai_provider_manager.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../providers/ai_chat_providers.dart';
import '../ai/bookkeeping_result.dart';
import '../attachment_service.dart';
import '../billing/post_processor.dart';
import '../data/tag_seed_service.dart';
import '../system/logger_service.dart';
import 'auto_billing_config.dart';

/// 自动记账服务 - 通用核心逻辑
/// Android和iOS共用的OCR识别和自动记账逻辑
class AutoBillingService {
  static const _ledgerIdKey = 'current_ledger_id';
  static const _processedScreenshotsKey = 'processed_screenshots';

  final ProviderContainer _container;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 防重复处理
  final Set<String> _processedPaths = {};
  String? _lastProcessedPath;
  int _lastProcessedTime = 0;

  AutoBillingService(this._container) {
    _initNotifications();
    _loadProcessedScreenshots();
  }

  /// 解析当前账本 ID(Provider → SharedPreferences → 数据库默认)。
  Future<int?> _resolveLedgerId() async {
    try {
      final id = _container.read(currentLedgerIdProvider);
      return id;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getInt(_ledgerIdKey);
    if (fromPrefs != null) return fromPrefs;
    final repo = _container.read(repositoryProvider);
    final ledgers = await repo.getAllLedgers();
    if (ledgers.isEmpty) return null;
    final fallback = ledgers.first.id;
    await prefs.setInt(_ledgerIdKey, fallback);
    return fallback;
  }

  /// 初始化通知
  Future<void> _initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  /// 加载已处理的截图列表
  Future<void> _loadProcessedScreenshots() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_processedScreenshotsKey) ?? [];
    _processedPaths.addAll(list);

    // 只保留最近N个，避免内存占用过大
    if (_processedPaths.length > AutoBillingConfig.maxProcessedCache) {
      final toRemove =
          _processedPaths.length - AutoBillingConfig.maxProcessedCache;
      _processedPaths.removeAll(_processedPaths.take(toRemove));
      await _saveProcessedScreenshots();
      logger.debug('AutoBilling', '清理已处理缓存',
          '移除=$toRemove, 保留=${AutoBillingConfig.maxProcessedCache}');
    }
  }

  /// 保存已处理的截图列表
  Future<void> _saveProcessedScreenshots() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _processedScreenshotsKey, _processedPaths.toList());
  }

  /// 标记截图已处理
  Future<void> _markAsProcessed(String path) async {
    _processedPaths.add(path);
    await _saveProcessedScreenshots();
  }

  /// 检查截图是否已处理
  bool _isProcessed(String path) {
    return _processedPaths.contains(path);
  }

  /// 核心：处理截图并自动记账
  /// [imagePath] 截图文件路径
  /// [showNotification] 是否显示通知（默认true）
  /// 返回：交易记录ID，失败返回null
  Future<int?> processScreenshot(
    String imagePath, {
    bool showNotification = true,
  }) async {
    final totalStartTime = DateTime.now().millisecondsSinceEpoch;
    print('📸 [AutoBilling] 开始处理截图: $imagePath');
    logger.info('AutoBilling', '开始处理截图', imagePath);

    // 防重复处理: 已处理过的跳过
    if (_isProcessed(imagePath)) {
      print('⚠️ [AutoBilling] 截图已处理过，跳过');
      logger.warning('AutoBilling', '截图已处理过，跳过', imagePath);
      return null;
    }

    // 防重复处理: 配置时间窗口内相同路径只处理一次
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastProcessedPath == imagePath &&
        (now - _lastProcessedTime) < AutoBillingConfig.duplicateCheckWindow) {
      final timeDiff = now - _lastProcessedTime;
      print('⚠️ [AutoBilling] 重复截图，跳过处理 (${timeDiff}ms前已处理)');
      logger.warning('AutoBilling', '重复截图，跳过处理', '${timeDiff}ms前已处理');
      return null;
    }

    _lastProcessedPath = imagePath;
    _lastProcessedTime = now;

    try {
      const notificationId = 1001;

      // 检查文件是否存在
      final file = File(imagePath);

      // 如果文件不存在,可能需要短暂等待
      // (无障碍服务直接截图时文件已就绪,ContentObserver 可能需要等待)
      if (!await file.exists()) {
        print('⏳ 文件尚未就绪,等待最多${AutoBillingConfig.fileWaitTimeout}ms...');
        logger.info('AutoBilling', '文件尚未就绪，开始等待',
            '路径=$imagePath, 超时=${AutoBillingConfig.fileWaitTimeout}ms');

        if (showNotification) {
          await _showNotification(
            id: notificationId,
            title: '✅ 检测到截图',
            body: '正在等待文件写入...',
          );
        }

        final waitStartTime = DateTime.now().millisecondsSinceEpoch;
        var waitTime = 0;
        final maxWait = AutoBillingConfig.fileWaitTimeout;

        while (waitTime < maxWait) {
          if (await file.exists() && await file.length() > 0) {
            print('✅ 文件已就绪，等待时间=${waitTime}ms');
            logger.info('AutoBilling', '文件就绪', '等待时间=${waitTime}ms');
            break;
          }
          await Future.delayed(Duration(milliseconds: AutoBillingConfig.fileCheckInterval));
          waitTime = DateTime.now().millisecondsSinceEpoch - waitStartTime;
        }

        if (!await file.exists() || await file.length() == 0) {
          print('❌ 截图文件等待超时 (${waitTime}ms)');
          logger.error('AutoBilling', '截图文件等待超时',
              '路径=$imagePath, 等待时间=${waitTime}ms, 文件存在=${await file.exists()}');
          if (showNotification) {
            await _showNotification(
              id: notificationId,
              title: '识别失败',
              body: '截图文件不可用',
            );
          }
          return null;
        }
      } else {
        print('✅ 文件已就绪,无需等待');
        logger.debug('AutoBilling', '文件已就绪，无需等待');
      }

      // 兜底:AI vision 未配置 → 系统通知告警,引导用户去设置(后台路径无 UI
      // context,只能 push 系统通知。点击跳转由 deep link 处理,这里先不带
      // payload)
      if (!await AIProviderManager.isCapabilityConfigured(
          AICapabilityType.vision)) {
        logger.warning('AutoBilling', 'AI vision 未配置,跳过自动记账');
        if (showNotification) {
          final l10n = lookupAppLocalizations(
              PlatformDispatcher.instance.locale);
          await _showNotification(
            id: notificationId,
            title: l10n.aiNotConfiguredNotificationTitle,
            body: l10n.aiNotConfiguredNotificationBody,
          );
        }
        return null;
      }

      // 更新通知：开始识别
      if (showNotification) {
        await _showNotification(
          id: notificationId,
          title: '正在识别截图...',
          body: '正在调用 AI 视觉分析支付信息,请稍候',
        );
      }

      // AI 视觉识别 + 多笔保存(全部委托 AiBookkeeper)
      final ledgerId = await _resolveLedgerId();
      if (ledgerId == null) {
        logger.error('AutoBilling', '无可用账本');
        if (showNotification) {
          await _showNotification(
            id: notificationId,
            title: '❌ 自动记账失败',
            body: '无可用账本,请先创建账本',
          );
        }
        await _markAsProcessed(imagePath);
        return null;
      }

      final aiStartTime = DateTime.now().millisecondsSinceEpoch;
      logger.info('AutoBilling', '开始 AI 视觉识别 + 落库');

      final autoAddAttachment =
          _container.read(smartBillingAutoAttachmentProvider);
      final result = await _container.read(aiBookkeeperProvider).fromImage(
        image: file,
        ledgerId: ledgerId,
        billingTypes: const [
          TagSeedService.billingTypeImage,
          TagSeedService.billingTypeAi,
        ],
        l10n: lookupAppLocalizations(PlatformDispatcher.instance.locale),
        // 多笔截图(罕见,但 AI 可能识别出一张账单页里的多笔)时,每笔都挂
        // 同一张原图,与相册路径行为对齐。
        onSaved: autoAddAttachment
            ? (txId, _) async {
                try {
                  final attachmentService =
                      _container.read(attachmentServiceProvider);
                  await attachmentService.saveAttachment(
                    transactionId: txId,
                    sourceFile: file,
                    index: 0,
                  );
                  _container
                      .read(attachmentListRefreshProvider.notifier)
                      .state++;
                } catch (e, st) {
                  logger.error('AutoBilling', '保存截图附件失败', e, st);
                }
              }
            : null,
      );

      final aiElapsed = DateTime.now().millisecondsSinceEpoch - aiStartTime;
      logger.info('AutoBilling', 'AI 识别 + 落库完成',
          '耗时=${aiElapsed}ms, 成功=${result.savedCount} 笔, 失败=${result.failedCount}');

      // 不管成败,这张截图都不再处理
      await _markAsProcessed(imagePath);

      if (!result.success) {
        if (showNotification) {
          await _showNotification(
            id: notificationId,
            title: '❌ 识别失败',
            body: '无法从截图提取账单信息,请检查 AI 配置或图片',
          );
        }
        return null;
      }

      _container.read(statsRefreshProvider.notifier).state++;
      await PostProcessor.runC(_container, ledgerId: ledgerId, tags: true);

      if (showNotification) {
        await _showNotification(
          id: notificationId,
          title: _successTitle(result),
          body: _successBody(result),
        );
      }
      logger.info('AutoBilling', '自动记账成功',
          'ids=${result.transactionIds}, 总金额=${result.totalAbsAmount}');
      return result.firstTransactionId;
    } catch (e, stackTrace) {
      print('❌ 处理截图失败: $e');
      logger.error('AutoBilling', '处理截图失败', {
        'path': imagePath,
        'error': e.toString(),
        'stage': '未知阶段',
      }, stackTrace);
      return null;
    } finally {
      final totalElapsed =
          DateTime.now().millisecondsSinceEpoch - totalStartTime;
      print('⏱️ [性能] 整个流程完成, 总耗时=${totalElapsed}ms');
    }
  }

  /// 核心：直接处理文本并自动记账(快捷指令推荐方式)
  /// [text] 快捷指令传递的识别文本
  /// [showNotification] 是否显示通知（默认true）
  /// 返回：交易记录ID，失败返回null
  Future<int?> processText(
    String text, {
    bool showNotification = true,
  }) async {
    final totalStartTime = DateTime.now().millisecondsSinceEpoch;
    print('📝 [AutoBilling] 开始处理文本: $text');

    try {
      const notificationId = 1002;

      // 兜底:AI text 未配置 → 系统通知,引导用户去配置
      if (!await AIProviderManager.isCapabilityConfigured(
          AICapabilityType.text)) {
        logger.warning('AutoBilling', 'AI text 未配置,跳过文本记账');
        if (showNotification) {
          final l10n = lookupAppLocalizations(
              PlatformDispatcher.instance.locale);
          await _showNotification(
            id: notificationId,
            title: l10n.aiNotConfiguredNotificationTitle,
            body: l10n.aiNotConfiguredNotificationBody,
          );
        }
        return null;
      }

      // 显示"正在识别"通知
      if (showNotification) {
        await _showNotification(
          id: notificationId,
          title: '⏳ 正在识别',
          body: '正在调用 AI 解析支付信息...',
        );
      }

      // AI 文本提取 + 多笔保存(全部委托 AiBookkeeper)
      final ledgerId = await _resolveLedgerId();
      if (ledgerId == null) {
        if (showNotification) {
          await _showNotification(
            id: notificationId,
            title: '❌ 自动记账失败',
            body: '无可用账本,请先创建账本',
          );
        }
        return null;
      }

      final result = await _container.read(aiBookkeeperProvider).fromText(
        text: text,
        ledgerId: ledgerId,
        billingTypes: const [
          TagSeedService.billingTypeImage, // 通知文本场景沿用 image 标签习惯
          TagSeedService.billingTypeAi,
        ],
        l10n: lookupAppLocalizations(PlatformDispatcher.instance.locale),
      );

      if (!result.success) {
        if (showNotification) {
          await _showNotification(
            id: notificationId,
            title: '❌ 识别失败',
            body: '未能识别出金额信息',
          );
        }
        return null;
      }

      _container.read(statsRefreshProvider.notifier).state++;
      await PostProcessor.runC(_container, ledgerId: ledgerId, tags: true);

      if (showNotification) {
        await _showNotification(
          id: notificationId,
          title: _successTitle(result),
          body: _successBody(result),
        );
      }
      return result.firstTransactionId;
    } catch (e) {
      logger.error('AutoBilling', '文本处理失败', e);
      if (showNotification) {
        await _showNotification(
          id: 1002,
          title: '❌ 处理失败',
          body: '错误: $e',
        );
      }
      return null;
    } finally {
      final totalElapsed =
          DateTime.now().millisecondsSinceEpoch - totalStartTime;
      logger.debug('AutoBilling', '文本处理完成', '总耗时=${totalElapsed}ms');
    }
  }

  /// 通知标题统一格式
  String _successTitle(BookkeepingResult result) {
    if (result.isMulti) {
      return '✅ 自动记账成功 ${result.savedCount} 笔';
    }
    return '✅ 自动记账成功 ¥${result.totalAbsAmount.toStringAsFixed(2)}';
  }

  /// 通知正文统一格式
  String _successBody(BookkeepingResult result) {
    if (result.isMulti) {
      return '合计 ¥${result.totalAbsAmount.toStringAsFixed(2)}';
    }
    final note = result.firstBill?.note;
    return (note != null && note.isNotEmpty) ? '备注: $note' : '已自动创建记录';
  }

  /// 显示通知
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'screenshot_ocr',
      '截图识别',
      channelDescription: '截图自动识别通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(id, title, body, details);
  }

  /// 释放资源(AI 服务无 native handle,不需要 dispose,保留方法以备后续添加)
  void dispose() {}
}
