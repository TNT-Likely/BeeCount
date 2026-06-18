import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../ai/core/prompt_builder.dart';
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
  static const _shakeBillingControlChannel =
      MethodChannel('com.tntlikely.beecount/shake_billing_control');

  final ProviderContainer _container;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// AI 调用超时后尚未收到延迟响应的截图数
  int _pendingTimeoutCount = 0;

  /// 记录 Dart 关键阶段（闪退后仍可通过日志查看）
  void _logStage(String stage) {
    logger.info('DartStage', stage);
    print('🐛 [DartStage] $stage');
  }

  // 防重复处理
  final Set<String> _processedPaths = {};
  String? _lastProcessedPath;
  int _lastProcessedTime = 0;

  /// 兜底本地化文案（后台恢复期取不到 PlatformDispatcher.locale 时使用）
  late final AppLocalizations _defaultL10n = lookupAppLocalizations(
      const Locale('zh', 'CN'));

  /// 安全获取本地化文案。后台 Activity 重建过渡期可能取不到 locale，兜底用默认值。
  AppLocalizations _safeL10n() {
    try {
      return lookupAppLocalizations(PlatformDispatcher.instance.locale);
    } catch (_) {
      return _defaultL10n;
    }
  }

  AutoBillingService(this._container) {
    _initNotifications();
    _loadProcessedScreenshots();
    // 恢复 Engine 挂起时未能送达的通知
    flushPendingNotification();
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

    // 同 _showNotification:通知子系统任何异常都不允许影响记账主流程
    try {
      await _notificationsPlugin.initialize(initSettings);
    } catch (e) {
      logger.warning('AutoBilling', '通知初始化失败(仅影响进度通知,不影响记账): $e');
    }
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
  /// [showProgressNotifications] 是否显示中间进度通知（默认true）。
  ///   摇一摇路径传 false，只保留最终结果通知横幅。
  /// 返回：交易记录ID，失败返回null
  Future<int?> processScreenshot(
    String imagePath, {
    bool showNotification = true,
    bool showProgressNotifications = true,
  }) async {
    _logStage('process_screenshot_start');
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

    const notificationId = 1001;
    const resultNotificationId = 1101;

    // 超时后仍需等待 AI 延迟响应，故在 try 外保留引用
    Future<BookkeepingResult>? pendingAiFuture;

    try {
      // 检查文件是否存在
      final file = File(imagePath);

      // 如果文件不存在,可能需要短暂等待
      // (无障碍服务直接截图时文件已就绪,ContentObserver 可能需要等待)
      if (!await file.exists()) {
        logger.info('AutoBilling', '文件尚未就绪，开始等待',
            '路径=$imagePath, 超时=${AutoBillingConfig.fileWaitTimeout}ms');

        if (showNotification && showProgressNotifications) {
          final l10n =
              _safeL10n();
          await _showNotification(
            id: notificationId,
            title: l10n.autoBillingNotifyDetectedTitle,
            body: l10n.autoBillingNotifyWaitingFileBody,
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
          logger.error('AutoBilling', '截图文件等待超时',
              '路径=$imagePath, 等待时间=${waitTime}ms, 文件存在=${await file.exists()}');
          if (showNotification) {
            final l10n = _safeL10n();
            await _showFinalNotification(
              progressId: notificationId,
              finalId: 1101,
              capturePath: imagePath,
              title: l10n.autoBillingNotifyFileUnavailableTitle,
              body: l10n.autoBillingNotifyFileUnavailableBody,
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
          final l10n = _safeL10n();
          await _showFinalNotification(
            progressId: notificationId,
            finalId: 1101,
            capturePath: imagePath,
            title: l10n.aiNotConfiguredNotificationTitle,
            body: l10n.aiNotConfiguredNotificationBody,
          );
        }
        return null;
      }

      // 更新通知：开始识别（摇一摇路径不显示进度通知）
      if (showNotification && showProgressNotifications) {
        final l10n =
            _safeL10n();
        await _showNotification(
          id: notificationId,
          title: l10n.autoBillingNotifyRecognizingScreenshotTitle,
          body: l10n.autoBillingNotifyVisionAnalyzingBody,
        );
      }

      // AI 视觉识别 + 多笔保存(全部委托 AiBookkeeper)
      final ledgerId = await _resolveLedgerId();
      if (ledgerId == null) {
        logger.error('AutoBilling', '无可用账本');
        if (showNotification) {
          final l10n = _safeL10n();
          await _showFinalNotification(
            progressId: notificationId,
            finalId: 1101,
            capturePath: imagePath,
            title: l10n.autoBillingNotifyNoLedgerTitle,
            body: l10n.autoBillingNotifyNoLedgerBody,
          );
        }
        await _markAsProcessed(imagePath);
        return null;
      }

      _logStage('ai_vision_start');
      final aiStartTime = DateTime.now().millisecondsSinceEpoch;
      logger.info('AutoBilling', '开始 AI 视觉识别 + 落库');

      final autoAddAttachment =
          _container.read(smartBillingAutoAttachmentProvider);
      final autoAddAttachmentFn = autoAddAttachment
          ? (txId, _) async {
              try {
                final attachmentService =
                    _container.read(attachmentServiceProvider);
                await attachmentService.saveAttachment(
                  transactionId: txId,
                  sourceFile: file,
                  index: 0,
                  urgent: true,
                );
                _container
                    .read(attachmentListRefreshProvider.notifier)
                    .state++;
              } catch (e, st) {
                logger.error('AutoBilling', '保存截图附件失败', e, st);
              }
            }
          : null;

      // 分离 AI Future 引用，超时后仍需等待其延迟响应
      pendingAiFuture = _container.read(aiBookkeeperProvider).fromImage(
        image: file,
        ledgerId: ledgerId,
        billGuard: PromptBuilder.billGuardForImage,
        billingTypes: const [
          TagSeedService.billingTypeImage,
          TagSeedService.billingTypeAi,
        ],
        l10n: _safeL10n(),
        // 多笔截图(罕见,但 AI 可能识别出一张账单页里的多笔)时,每笔都挂
        // 同一张原图,与相册路径行为对齐。
        //
        // 走 urgent 模式:跳过 FlutterImageCompress(platform channel,后台冻
        // 结时会卡)和 _getImageInfo,用 sync File.copy 几十 ms 内完成。
        // 这样 attachment 在 perform() return 前就写完,不依赖用户开 app。
        onSaved: autoAddAttachmentFn,
      );

      final result = await pendingAiFuture!.timeout(const Duration(seconds: 15));

      _logStage('ai_vision_complete');
      final aiElapsed = DateTime.now().millisecondsSinceEpoch - aiStartTime;
      logger.info('AutoBilling', 'AI 识别 + 落库完成',
          '耗时=${aiElapsed}ms, 成功=${result.savedCount} 笔, 失败=${result.failedCount}');

      // 不管成败,这张截图都不再处理
      await _markAsProcessed(imagePath);

      if (!result.success) {
        if (showNotification) {
          final l10n = _safeL10n();
          await _showFinalNotification(
            progressId: notificationId,
            finalId: resultNotificationId,
            capturePath: imagePath,
            title: l10n.autoBillingNotifyRecognizeFailedTitle,
            body: l10n.autoBillingNotifyRecognizeFailedBody,
          );
        }
        return null;
      }

      _logStage('post_processor_start');
      _container.read(statsRefreshProvider.notifier).state++;
      await PostProcessor.runC(_container, ledgerId: ledgerId, tags: true);
      _logStage('post_processor_done');

      if (showNotification) {
        _logStage('show_final_notification');
        final l10n = _safeL10n();
        await _showFinalNotification(
          progressId: notificationId,
          finalId: resultNotificationId,
          capturePath: imagePath,
          title: _successTitle(result, l10n),
          body: _successBody(result, l10n),
        );
      }
      logger.info('AutoBilling', '自动记账成功',
          'ids=${result.transactionIds}, 总金额=${result.totalAbsAmount}');
      return result.firstTransactionId;
    } on TimeoutException {
      _logStage('ai_vision_timeout');
      logger.warning('AutoBilling', 'AI 识别超时', '等待延迟响应: $imagePath');
      if (showNotification) {
        await _showFinalNotification(
          progressId: notificationId,
          finalId: resultNotificationId,
          capturePath: imagePath,
          title: '蜜蜂记账',
          body: '⏳ 识别耗时较长，请稍等！',
        );
      }
      _pendingTimeoutCount++;
      _handleDelayedResponse(
        imagePath: imagePath,
        aiFuture: pendingAiFuture!,
        finalId: resultNotificationId,
        showNotification: showNotification,
      );
      return null;
    } catch (e, stackTrace) {
      _logStage('process_screenshot_error');
      print('❌ 处理截图失败: $e');
      logger.error('AutoBilling', '处理截图失败', {
        'path': imagePath,
        'error': e.toString(),
        'stage': '未知阶段',
      }, stackTrace);
      if (showNotification) {
        final l10n = _safeL10n();
        try {
          await _showFinalNotification(
            progressId: notificationId,
            finalId: resultNotificationId,
            capturePath: imagePath,
            title: l10n.autoBillingNotifyProcessFailedTitle,
            body: l10n.autoBillingNotifyProcessFailedBody(e.toString()),
          );
        } catch (_) {
          // 通知失败不影响流程
        }
      }
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
  /// [showProgressNotifications] 是否显示中间进度通知（默认true）。
  ///   摇一摇路径传 false，只保留最终结果通知横幅。
  /// 返回：交易记录ID，失败返回null
  Future<int?> processText(
    String text, {
    bool showNotification = true,
    bool showProgressNotifications = true,
  }) async {
    final totalStartTime = DateTime.now().millisecondsSinceEpoch;
    print('📝 [AutoBilling] 开始处理文本: $text');

    try {
      const notificationId = 1002;
      const resultNotificationId = 1102;
      final l10n = _safeL10n();

      // 兜底:AI text 未配置 → 系统通知,引导用户去配置
      if (!await AIProviderManager.isCapabilityConfigured(
          AICapabilityType.text)) {
        logger.warning('AutoBilling', 'AI text 未配置,跳过文本记账');
        if (showNotification) {
          await _showNotification(
            id: notificationId,
            title: l10n.aiNotConfiguredNotificationTitle,
            body: l10n.aiNotConfiguredNotificationBody,
          );
        }
        return null;
      }

      // 显示"正在识别"通知（摇一摇路径不显示进度通知）
      if (showNotification && showProgressNotifications) {
        await _showNotification(
          id: notificationId,
          title: l10n.autoBillingNotifyRecognizingTextTitle,
          body: l10n.autoBillingNotifyTextAnalyzingBody,
        );
      }

      // AI 文本提取 + 多笔保存(全部委托 AiBookkeeper)
      final ledgerId = await _resolveLedgerId();
      if (ledgerId == null) {
        if (showNotification) {
          await _showFinalNotification(
            progressId: notificationId,
            finalId: resultNotificationId,
            title: l10n.autoBillingNotifyNoLedgerTitle,
            body: l10n.autoBillingNotifyNoLedgerBody,
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
        l10n: l10n,
      );

      if (!result.success) {
        if (showNotification) {
          await _showFinalNotification(
            progressId: notificationId,
            finalId: resultNotificationId,
            title: l10n.autoBillingNotifyRecognizeFailedTitle,
            body: l10n.autoBillingNotifyNoAmountBody,
          );
        }
        return null;
      }

      _container.read(statsRefreshProvider.notifier).state++;
      await PostProcessor.runC(_container, ledgerId: ledgerId, tags: true);

      if (showNotification) {
        await _showFinalNotification(
          progressId: notificationId,
          finalId: resultNotificationId,
          title: _successTitle(result, l10n),
          body: _successBody(result, l10n),
        );
      }
      return result.firstTransactionId;
    } catch (e) {
      logger.error('AutoBilling', '文本处理失败', e);
      if (showNotification) {
        final l10n =
            _safeL10n();
        await _showNotification(
          id: 1002,
          title: l10n.autoBillingNotifyProcessFailedTitle,
          body: l10n.autoBillingNotifyProcessFailedBody(e.toString()),
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
  String _successTitle(BookkeepingResult result, AppLocalizations l10n) {
    if (result.isMulti) {
      return l10n.autoBillingNotifySuccessMultiTitle(result.savedCount);
    }
    return l10n.autoBillingNotifySuccessSingleTitle(
        result.totalAbsAmount.toStringAsFixed(2));
  }

  /// 通知正文统一格式
  String _successBody(BookkeepingResult result, AppLocalizations l10n) {
    if (result.isMulti) {
      return l10n.autoBillingNotifySuccessMultiBody(
          result.totalAbsAmount.toStringAsFixed(2));
    }
    final note = result.firstBill?.note;
    return (note != null && note.isNotEmpty)
        ? l10n.autoBillingNotifySuccessSingleBodyNote(note)
        : l10n.autoBillingNotifySuccessSingleBodyDefault;
  }

  /// 取消摇一摇进度横幅（Android native 已发，Flutter 负责在结果到来时移除）
  Future<void> cancelShakeProgressBanner() async {
    await _notificationsPlugin.cancel(9101);
  }

  /// 处理 AI 超时后的延迟响应。
  ///
  /// [aiFuture] 是 [fromImage] 的原生 Future，即便外层 .timeout() 已触发，
  /// 它仍在后台运行。等 AI 最终响应后发送结果通知。
  ///
  /// 如果有多个待处理的延迟响应，通知正文末尾追加「（剩余 N 张待识别）」。
  void _handleDelayedResponse({
    required String imagePath,
    required Future<BookkeepingResult> aiFuture,
    required int finalId,
    required bool showNotification,
  }) {
    // 安全网：60 秒后如果 AI 仍无响应（Dio 20s 超时意外失效的极端情况），
    // 强制完成并通知用户，避免「⏳ 识别耗时较长」永久挂起
    aiFuture
        .timeout(const Duration(seconds: 60))
        .then((result) async {
      _pendingTimeoutCount--;
      await _markAsProcessed(imagePath);

      if (showNotification) {
        final l10n = _safeL10n();
        final suffix = _pendingTimeoutCount > 0
            ? '（剩余 $_pendingTimeoutCount 张待识别）'
            : '';

        if (result.success) {
          // 刷新统计 & 触发同步（fromImage 已落库，PostProcessor 需手动跑）
          try {
            final ledgerId = await _resolveLedgerId();
            if (ledgerId != null) {
              // ignore: invalid_use_of_visible_for_testing_member
              _container.read(statsRefreshProvider.notifier).state++;
              await PostProcessor.runC(_container,
                  ledgerId: ledgerId, tags: true);
            }
          } catch (_) {}
        }

        await _showFinalNotification(
          progressId: finalId,
          finalId: finalId,
          capturePath: imagePath,
          title: result.success
              ? _successTitle(result, l10n)
              : l10n.autoBillingNotifyRecognizeFailedTitle,
          body: (result.success
                      ? _successBody(result, l10n)
                      : l10n.autoBillingNotifyRecognizeFailedBody) +
              suffix,
        );
      }

      if (result.success) {
        logger.info('AutoBilling', '延迟响应：自动记账成功',
            'ids=${result.transactionIds}');
      }
    }).catchError((e, st) {
      _pendingTimeoutCount--;
      logger.error('AutoBilling', '延迟响应处理失败', '$e', st);
      // 连兜底也失败了 → 不能再让「⏳ 识别耗时较长」挂在那
      if (showNotification) {
        final l10n = _safeL10n();
        _showFinalNotification(
          progressId: finalId,
          finalId: finalId,
          capturePath: imagePath,
          title: l10n.autoBillingNotifyProcessFailedTitle,
          body: l10n.autoBillingNotifyProcessFailedBody('识别超时，请稍后重试'),
        );
      }
    });
  }

  /// 显示通知。
  ///
  /// 通知失败**绝不向外抛**:通知只是进度提示,记账主流程不能因它中断。
  /// iOS 27 起对未授权通知的应用调 show() 会抛 PlatformException(Error 2003,
  /// "Source is not authorized"),而 iOS ≤26 同场景是静默不弹 —— 不隔离的话
  /// 截图还没进 AI 识别就在"开始识别"通知处整链失败(#322)。
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
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(id, title, body, details);
    } catch (e) {
      logger.warning('AutoBilling',
          '通知发送失败(未授权通知时属预期,不中断记账流程): $e');
    }
  }

  /// 显示「最终结果」通知（横幅弹出）。
  ///
  /// [capturePath] 为截屏文件路径。传入后优先通过原生 MethodChannel 发送，
  /// 同时取消原生侧对应截图的 15s 超时定时器。不传时走原有降级链路。
  Future<void> _showFinalNotification({
    required int progressId,
    required int finalId,
    required String title,
    required String body,
    String? capturePath,
  }) async {
    // 优先走 captureResult（取消原生超时 + 原生通知）
    if (capturePath != null) {
      try {
        await _shakeBillingControlChannel.invokeMethod('captureResult', {
          'path': capturePath,
          'title': title,
          'body': body,
        });
        logger.info('AutoBilling', '原生结果通知已发送', 'title=$title');
        return;
      } catch (e) {
        logger.debug('AutoBilling', '原生通知发送失败，降级到 Flutter 通知: $e');
      }
    }

    // 降级：Flutter 本地通知
    try {
      const androidDetails = AndroidNotificationDetails(
        'shake_result',
        '摇一摇记账结果',
        channelDescription: '摇一摇自动记账最终结果通知',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(finalId, title, body, details);
      return;
    } catch (e) {
      logger.warning('AutoBilling', 'Flutter 通知也失败，保存待发送通知', '$e');
    }

    // 兜底：Engine 被 ROM 挂起时两种方式都失败，
    // 保存到 SharedPreferences，下次启动时恢复展示
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_notification_title', title);
      await prefs.setString('pending_notification_body', body);
      logger.info('AutoBilling', '待发送通知已保存到 SharedPreferences');
    } catch (e) {
      logger.error('AutoBilling', '保存待发送通知失败', e);
    }
  }

  /// 检查并显示待发送的通知（应用启动时调用）
  Future<void> flushPendingNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final title = prefs.getString('pending_notification_title');
      final body = prefs.getString('pending_notification_body');
      if (title == null || body == null) return;

      await prefs.remove('pending_notification_title');
      await prefs.remove('pending_notification_body');
      logger.info('AutoBilling', '恢复待发送通知: $title');

      await _notificationsPlugin.show(
        9102, title, body, const NotificationDetails(
          android: AndroidNotificationDetails(
            'shake_result',
            '摇一摇记账结果',
            channelDescription: '摇一摇自动记账最终结果通知',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      logger.error('AutoBilling', '恢复待发送通知失败', e);
    }
  }

  /// 释放资源(AI 服务无 native handle,不需要 dispose,保留方法以备后续添加)
  void dispose() {}
}
