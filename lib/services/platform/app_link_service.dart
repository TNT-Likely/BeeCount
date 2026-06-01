import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/base_repository.dart';
import '../../providers/database_providers.dart';
import '../automation/auto_billing_service.dart';
import '../billing/post_processor.dart';
import '../system/logger_service.dart';

/// AppLink 动作类型
enum AppLinkAction {
  /// 语音记账
  voice,

  /// 图片记账（从相册选择）
  image,

  /// 拍照记账
  camera,

  /// AI 小助手
  aiChat,

  /// 自动记账（带参数）
  add,

  /// 自动记账（从文本）
  autoBilling,

  /// 快速记账（从相册）
  quickBilling,

  /// 手动记账（从小组件快捷入口）
  newTransaction,

  /// 未知
  unknown,
}

/// 自动记账参数
class AddTransactionParams {
  final double amount;
  final String type; // expense, income, transfer
  final String? category;
  final String? note;
  final String? account;
  final String? toAccount;
  final List<String>? tags;
  final DateTime? date;
  final bool silent;

  const AddTransactionParams({
    required this.amount,
    this.type = 'expense',
    this.category,
    this.note,
    this.account,
    this.toAccount,
    this.tags,
    this.date,
    this.silent = false,
  });

  factory AddTransactionParams.fromQueryParams(Map<String, String> params) {
    final amountStr = params['amount'];
    if (amountStr == null || amountStr.isEmpty) {
      throw ArgumentError('amount is required');
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      throw ArgumentError('amount must be a positive number');
    }

    // 解析日期
    DateTime? date;
    final dateStr = params['date'];
    if (dateStr != null && dateStr.isNotEmpty) {
      date = DateTime.tryParse(dateStr);
    }

    // 解析标签
    List<String>? tags;
    final tagsStr = params['tags'];
    if (tagsStr != null && tagsStr.isNotEmpty) {
      tags = tagsStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    }

    return AddTransactionParams(
      amount: amount,
      type: params['type'] ?? 'expense',
      category: params['category'],
      note: params['note'],
      account: params['account'],
      toAccount: params['to_account'],
      tags: tags,
      date: date,
      silent: params['silent'] == '1' || params['silent'] == 'true',
    );
  }
}

/// AppLink 处理结果
class AppLinkResult {
  final bool success;
  final String? message;
  final int? transactionId;

  const AppLinkResult({
    required this.success,
    this.message,
    this.transactionId,
  });

  factory AppLinkResult.success({String? message, int? transactionId}) =>
      AppLinkResult(success: true, message: message, transactionId: transactionId);

  factory AppLinkResult.failure(String message) =>
      AppLinkResult(success: false, message: message);
}

/// AppLink 服务
///
/// 处理所有 beecount:// 开头的链接
///
/// 支持的链接格式:
/// - beecount://voice - 语音记账
/// - beecount://image - 图片记账（从相册）
/// - beecount://camera - 拍照记账
/// - beecount://ai-chat - AI 小助手
/// - beecount://new?type=expense - 手动记账（支出/收入）
/// - beecount://add?amount=100&type=expense&category=餐饮 - 自动记账
/// - beecount://auto-billing?text=... - 文本自动记账（兼容旧版）
/// - beecount://quick-billing - 快速记账（兼容旧版）
///
/// 同时监听 iOS AppIntents EventChannel 处理快捷指令传入的图片
class AppLinkService {
  final ProviderContainer _container;
  late final AutoBillingService _autoBillingService;

  /// iOS AppIntents 事件通道（用于接收快捷指令传入的图片路径）
  static const EventChannel _eventChannel =
      EventChannel('com.beecount.app_intents/events');

  /// iOS AppIntents 方法通道(回调 Swift,告知后台处理已完成可以放 perform 返回)
  static const MethodChannel _methodChannel =
      MethodChannel('com.beecount.app_intents');

  /// AppIntents 事件订阅
  StreamSubscription<dynamic>? _appIntentSubscription;

  /// 导航回调，由外部设置
  void Function(AppLinkAction action, {AddTransactionParams? params})? onNavigate;

  /// Toast 回调，由外部设置
  void Function(String message)? onShowToast;

  AppLinkService(this._container) {
    _autoBillingService = AutoBillingService(_container);
    _initAppIntentsListener();
  }

  /// 初始化 iOS AppIntents 监听器
  void _initAppIntentsListener() {
    if (!Platform.isIOS) return;

    logger.info('AppLink', '初始化 AppIntents 监听器');

    _appIntentSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is String) {
          logger.info('AppLink', '收到 AppIntent 事件: $event');
          _handleAppIntent(event);
        }
      },
      onError: (error) {
        logger.error('AppLink', 'AppIntent 事件监听错误', error);
      },
      onDone: () {
        logger.info('AppLink', 'AppIntent 事件流关闭');
      },
    );
  }

  /// 处理 AppIntent 事件
  Future<void> _handleAppIntent(String event) async {
    try {
      final data = jsonDecode(event) as Map<String, dynamic>;
      final action = data['action'] as String?;

      logger.info('AppLink', 'AppIntent action: $action');

      if (action == 'auto-billing') {
        final imagePath = data['imagePath'] as String?;
        if (imagePath != null && imagePath.isNotEmpty) {
          logger.info('AppLink', '处理快捷指令图片: $imagePath');
          await _handleScreenshotBilling(imagePath);
        } else {
          logger.warning('AppLink', 'auto-billing 未提供图片路径');
        }
      } else {
        logger.warning('AppLink', '未知的 AppIntent action: $action');
      }
    } catch (e, st) {
      logger.error('AppLink', '解析 AppIntent 事件失败', e, st);
    }
  }

  /// 处理快捷指令截图记账
  Future<void> _handleScreenshotBilling(String imagePath) async {
    try {
      await _autoBillingService.processScreenshot(
        imagePath,
        showNotification: true,
      );
      logger.info('AppLink', '快捷指令截图记账完成');
    } catch (e, st) {
      logger.error('AppLink', '快捷指令截图记账失败', e, st);
    } finally {
      // iOS: 通知 Swift AppIntent 处理完成,可以放 perform() 返回了。
      // 不发这个信号的话 perform() 会一直 await(直到 25s 超时),iOS 在 30s
      // 后台窗口内会 kill 进程,「成功」通知发不出去。
      if (Platform.isIOS) {
        try {
          await _methodChannel.invokeMethod('notifyBillingComplete');
        } catch (e) {
          logger.warning('AppLink', '通知 Swift 完成信号失败: $e');
        }
      }
    }
  }

  /// 解析 URI 获取动作类型
  static AppLinkAction parseAction(Uri uri) {
    final host = uri.host.toLowerCase();
    switch (host) {
      case 'voice':
        return AppLinkAction.voice;
      case 'image':
        return AppLinkAction.image;
      case 'camera':
        return AppLinkAction.camera;
      case 'ai-chat':
      case 'aichat':
      case 'ai':
        return AppLinkAction.aiChat;
      case 'add':
        return AppLinkAction.add;
      case 'new':
        return AppLinkAction.newTransaction;
      case 'auto-billing':
        return AppLinkAction.autoBilling;
      case 'quick-billing':
        return AppLinkAction.quickBilling;
      default:
        return AppLinkAction.unknown;
    }
  }

  /// 处理 URL
  Future<AppLinkResult> handleUrl(Uri uri) async {
    logger.info('AppLink', '收到URL: $uri');

    final action = parseAction(uri);
    final queryParams = uri.queryParameters;

    switch (action) {
      case AppLinkAction.voice:
        logger.info('AppLink', '打开语音记账');
        onNavigate?.call(AppLinkAction.voice);
        return AppLinkResult.success(message: '打开语音记账');

      case AppLinkAction.image:
        logger.info('AppLink', '打开图片记账');
        onNavigate?.call(AppLinkAction.image);
        return AppLinkResult.success(message: '打开图片记账');

      case AppLinkAction.camera:
        logger.info('AppLink', '打开拍照记账');
        onNavigate?.call(AppLinkAction.camera);
        return AppLinkResult.success(message: '打开拍照记账');

      case AppLinkAction.aiChat:
        logger.info('AppLink', '打开AI小助手');
        onNavigate?.call(AppLinkAction.aiChat);
        return AppLinkResult.success(message: '打开AI小助手');

      case AppLinkAction.add:
        logger.info('AppLink', '自动记账: $queryParams');
        return await _handleAddTransaction(queryParams);

      case AppLinkAction.newTransaction:
        final type = queryParams['type'] ?? 'expense';
        logger.info('AppLink', '打开手动记账: type=$type');
        onNavigate?.call(AppLinkAction.newTransaction, params: AddTransactionParams(amount: 0, type: type));
        return AppLinkResult.success(message: '打开手动记账');

      case AppLinkAction.autoBilling:
        // 兼容旧版
        return await _handleAutoBilling(queryParams);

      case AppLinkAction.quickBilling:
        // 兼容旧版，等同于图片记账
        onNavigate?.call(AppLinkAction.image);
        return AppLinkResult.success(message: '打开图片记账');

      case AppLinkAction.unknown:
        logger.warning('AppLink', '未知的action: ${uri.host}');
        return AppLinkResult.failure('未知的操作: ${uri.host}');
    }
  }

  /// 处理自动记账（带参数）
  Future<AppLinkResult> _handleAddTransaction(Map<String, String> params) async {
    try {
      final repo = _container.read(repositoryProvider);

      // 冷启动早期 _currentLedgerPersist 可能还没把上次选中的账本从
      // SharedPreferences 恢复出来,currentLedgerId 还是默认值 1 —— 先显式
      // 校准一次,避免 deep-link 把交易记到错误账本。
      await _restoreCurrentLedgerId();

      // 必须 await .future:冷启动时 currentLedgerProvider 还在 loading,
      // 用 .valueOrNull 会拿到 null 而误判"无账本"导致静默失败(issue #162)。
      final currentLedger = await _container.read(currentLedgerProvider.future);

      if (currentLedger == null) {
        logger.warning('AppLink',
            '自动记账失败:未找到当前账本 (ledgerId=${_container.read(currentLedgerIdProvider)})');
        return AppLinkResult.failure('请先选择账本');
      }

      final ledgerId = currentLedger.id;
      final type = params['type'] ?? 'expense';

      // —— 完整性校验 —— 金额无效 / 缺分类 / 分类不存在 → 不记账,返回具体原因
      // (由上层用 toast 提醒用户)。转账没有分类概念,只校验金额。
      final parsedAmount = double.tryParse(params['amount'] ?? '');
      if (parsedAmount == null || parsedAmount <= 0) {
        logger.warning('AppLink', '已拦截:金额无效 (amount=${params['amount']})');
        return AppLinkResult.failure('未记账:请填写有效金额');
      }
      if (type != 'transfer') {
        final categoryName = params['category'];
        if (categoryName == null || categoryName.isEmpty) {
          logger.warning('AppLink', '已拦截:缺少分类');
          return AppLinkResult.failure('未记账:请指定分类');
        }
        final matched = await _findCategoryId(
            repo, categoryName, type == 'income' ? 'income' : 'expense');
        if (matched == null) {
          logger.warning('AppLink', '已拦截:分类「$categoryName」不存在');
          return AppLinkResult.failure('未记账:分类「$categoryName」不存在');
        }
      }

      // —— 参数齐全:自动记账(原逻辑)——
      final txParams = AddTransactionParams.fromQueryParams(params);

      // 解析分类
      int? categoryId;
      if (txParams.category != null) {
        categoryId = await _findCategoryId(
          repo,
          txParams.category!,
          txParams.type == 'income' ? 'income' : 'expense',
        );
      }

      // 解析账户（不存在则自动创建）
      int? accountId;
      if (txParams.account != null) {
        accountId = await _findOrCreateAccountId(repo, txParams.account!, ledgerId);
      }

      // 解析转入账户（不存在则自动创建）
      int? toAccountId;
      if (txParams.type == 'transfer' && txParams.toAccount != null) {
        toAccountId = await _findOrCreateAccountId(repo, txParams.toAccount!, ledgerId);
      }

      // 创建交易
      final transactionId = await repo.addTransaction(
        ledgerId: ledgerId,
        type: txParams.type,
        amount: txParams.amount.abs(),
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        happenedAt: txParams.date ?? DateTime.now(),
        note: txParams.note,
      );

      // 关联标签
      if (txParams.tags != null && txParams.tags!.isNotEmpty) {
        final tagIds = <int>[];
        for (final tagName in txParams.tags!) {
          final tag = await repo.getTagByName(tagName);
          if (tag != null) {
            tagIds.add(tag.id);
          } else {
            // 创建新标签
            final newTagId = await repo.createTag(name: tagName);
            tagIds.add(newTagId);
          }
        }
        if (tagIds.isNotEmpty) {
          await repo.updateTransactionTags(
            transactionId: transactionId,
            tagIds: tagIds,
          );
        }
      }

      logger.info('AppLink', '自动记账成功: id=$transactionId, amount=${txParams.amount}');

      // 统一后处理：刷新UI + 触发云同步
      final hasTags = txParams.tags != null && txParams.tags!.isNotEmpty;
      await PostProcessor.runC(_container, ledgerId: ledgerId, tags: hasTags);

      if (!txParams.silent) {
        final typeText = txParams.type == 'income' ? '收入' : (txParams.type == 'transfer' ? '转账' : '支出');
        onShowToast?.call('已记录 $typeText ${txParams.amount.toStringAsFixed(2)} 元');
      }

      return AppLinkResult.success(
        message: '记账成功',
        transactionId: transactionId,
      );
    } on ArgumentError catch (e) {
      logger.warning('AppLink', '参数错误: $e');
      return AppLinkResult.failure('参数错误: ${e.message}');
    } catch (e, st) {
      logger.error('AppLink', '自动记账失败', e, st);
      return AppLinkResult.failure('记账失败: $e');
    }
  }

  /// 从持久化恢复上次选中的账本 id。
  ///
  /// 冷启动通过 deep-link 触发记账时,Splash 的 `_currentLedgerPersist` 恢复
  /// 逻辑可能还没跑完(它是 fire-and-forget,不被 await),currentLedgerId 还
  /// 停在默认值 1。这里显式、幂等地校准一次,确保记到用户真正选中的账本。
  Future<void> _restoreCurrentLedgerId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('current_ledger_id');
      if (saved != null &&
          _container.read(currentLedgerIdProvider) != saved) {
        _container.read(currentLedgerIdProvider.notifier).state = saved;
      }
    } catch (_) {
      // 恢复失败不致命,退回当前(可能为默认)账本。
    }
  }

  /// 处理旧版文本自动记账
  Future<AppLinkResult> _handleAutoBilling(Map<String, String> params) async {
    String? text = params['text'];

    if (text != null && text.isNotEmpty) {
      // 将逗号还原为换行符
      text = text.replaceAll(',', '\n');
      logger.info('AppLink', '从URL参数读取文本，长度: ${text.length}');

      try {
        await _autoBillingService.processText(
          text,
          showNotification: true,
        );
        return AppLinkResult.success(message: '文本处理完成');
      } catch (e, st) {
        logger.error('AppLink', '文本记账失败', e, st);
        return AppLinkResult.failure('文本记账失败: $e');
      }
    } else {
      logger.warning('AppLink', 'auto-billing 未提供文本');
      return AppLinkResult.failure('未提供文本内容');
    }
  }

  /// 根据名称查找分类ID
  Future<int?> _findCategoryId(BaseRepository repo, String name, String kind) async {
    final categories = kind == 'income'
        ? await repo.getTopLevelCategories('income')
        : await repo.getTopLevelCategories('expense');

    for (final cat in categories) {
      if (cat.name == name) {
        return cat.id;
      }
      // 检查子分类
      final subCats = await repo.getSubCategories(cat.id);
      for (final sub in subCats) {
        if (sub.name == name) {
          return sub.id;
        }
      }
    }
    return null;
  }

  /// 根据名称查找账户ID，不存在则创建
  Future<int?> _findOrCreateAccountId(BaseRepository repo, String name, int ledgerId) async {
    final accounts = await repo.getAllAccounts();
    for (final acc in accounts) {
      if (acc.name == name) {
        return acc.id;
      }
    }
    // 账户不存在，自动创建
    logger.info('AppLink', '账户 "$name" 不存在，自动创建');
    final newAccountId = await repo.createAccount(
      ledgerId: ledgerId,
      name: name,
    );
    return newAccountId;
  }

  /// 释放资源
  void dispose() {
    _appIntentSubscription?.cancel();
    _appIntentSubscription = null;
    _autoBillingService.dispose();
  }
}

/// 生成 AppLink URL
class AppLinkBuilder {
  static const String scheme = 'beecount';

  /// 语音记账链接
  static String voice() => '$scheme://voice';

  /// 图片记账链接
  static String image() => '$scheme://image';

  /// 拍照记账链接
  static String camera() => '$scheme://camera';

  /// AI 小助手链接
  static String aiChat() => '$scheme://ai-chat';

  /// 新建支出记账链接
  static String newExpense() => '$scheme://new?type=expense';

  /// 新建收入记账链接
  static String newIncome() => '$scheme://new?type=income';

  /// 新建转账记账链接
  static String newTransfer() => '$scheme://new?type=transfer';

  /// 自动记账链接
  static String add({
    required double amount,
    String type = 'expense',
    String? category,
    String? note,
    String? account,
    String? toAccount,
    List<String>? tags,
    DateTime? date,
    bool silent = false,
  }) {
    final params = <String, String>{
      'amount': amount.toString(),
      'type': type,
    };

    if (category != null) params['category'] = category;
    if (note != null) params['note'] = note;
    if (account != null) params['account'] = account;
    if (toAccount != null) params['to_account'] = toAccount;
    if (tags != null && tags.isNotEmpty) params['tags'] = tags.join(',');
    if (date != null) params['date'] = date.toIso8601String();
    if (silent) params['silent'] = '1';

    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$scheme://add?$query';
  }
}
