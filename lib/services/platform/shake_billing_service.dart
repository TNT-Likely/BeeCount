import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../automation/auto_billing_service.dart';

/// 摇一摇自动记账服务（仅Android）
///
/// 管理无障碍截屏的接收、队列处理、保活服务联动，以及与系统无障碍设置的交互。
/// 与 [ScreenshotMonitorService] 职责分离 — 截图监听走 ContentObserver，
/// 摇一摇走 AccessibilityService，互不干扰。
class ShakeBillingService {
  static const _accessibilityChannel = MethodChannel('com.tntlikely.beecount/accessibility_billing');
  static const _keepAliveChannel = MethodChannel('com.tntlikely.beecount/keep_alive');
  static const _shakeBillingControlChannel = MethodChannel('com.tntlikely.beecount/shake_billing_control');
  // 共享截图通道，用于无障碍设置查询（Android 端注册在 MainActivity）
  static const _screenshotChannel = MethodChannel('com.tntlikely.beecount/screenshot');

  static const _shakeBillingEnabledKey = 'shake_billing_enabled';
  static const _keepAliveEnabledKey = 'keep_alive_enabled';

  final ProviderContainer _container;
  late final AutoBillingService _autoBillingService;

  /// 保活服务是否已启用（内存状态，与摇一摇开关联动）
  bool _isKeepAliveEnabled = false;

  /// 摇一摇自动记账是否已启用（内存状态，避免后台异步事件中的竞态条件）
  bool _isShakeBillingEnabled = false;

  // ── 顺序处理队列（避免后台攒的多个截图同时触发 AI 造成通知轰炸） ──
  final _captureQueue = <String>[];
  bool _isProcessingCapture = false;

  // 单例模式
  static ShakeBillingService? _instance;

  factory ShakeBillingService(ProviderContainer container) {
    _instance ??= ShakeBillingService._internal(container);
    return _instance!;
  }

  ShakeBillingService._internal(this._container) {
    _autoBillingService = AutoBillingService(_container);
    _setupMethodCallHandler();
  }

  /// 设置方法调用处理器
  void _setupMethodCallHandler() {
    print('📳 [ShakeBilling] 初始化方法调用处理器');

    // 摇一摇无障碍截屏监听通道
    _accessibilityChannel.setMethodCallHandler((call) async {
      print('📳 [ShakeBilling] 收到无障碍方法调用: ${call.method}');
      if (call.method == 'onAccessibilityCapture') {
        final data = call.arguments as String;
        print('📳 [ShakeBilling] 无障碍截屏数据: $data');
        await _handleAccessibilityCapture(data);
      } else if (call.method == 'onAccessibilityServiceInterrupted') {
        print('⚠️ [ShakeBilling] 无障碍服务被系统中断');
        // Flutter 侧无需特殊处理，UI 会在 App resume 时刷新状态
      }
    });
  }

  // ── 摇一摇自动记账开关 ──

  /// 摇一摇自动记账是否已启用
  ///
  /// 注意：摇一摇使用无障碍截图存私有目录，不依赖相册权限，
  /// 因此不受 Google Play 构建限制，与截图监听独立判断。
  Future<bool> isShakeBillingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_shakeBillingEnabledKey) ?? false;
  }

  /// 启用摇一摇自动记账（同时自动开启保活服务）
  Future<void> enableShakeBilling() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('仅支持 Android 平台');
    }

    // 先设置内存状态（同步操作，无竞态风险）
    _isShakeBillingEnabled = true;

    try {
      await _shakeBillingControlChannel.invokeMethod('enableShake');
    } catch (e) {
      print('⚠️ [ShakeBilling] 通知 Android 启用摇一摇失败: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shakeBillingEnabledKey, true);
    print('✅ [ShakeBilling] 摇一摇自动记账已启用');

    // 同步启用保活服务（五层保活机制）
    try {
      await enableKeepAlive();
      _isKeepAliveEnabled = true;
    } catch (e) {
      print('⚠️ [ShakeBilling] 启用保活服务失败（不影响摇一摇）: $e');
    }
  }

  /// 禁用摇一摇自动记账（同步关闭保活服务）
  Future<void> disableShakeBilling() async {
    // 先设置内存状态（同步操作，阻止后续无障碍截屏入队）
    _isShakeBillingEnabled = false;

    try {
      await _shakeBillingControlChannel.invokeMethod('disableShake');
    } catch (e) {
      print('⚠️ [ShakeBilling] 通知 Android 禁用摇一摇失败: $e');
    }

    // 清空待处理的截屏队列，取消正在进行的处理
    _captureQueue.clear();
    _isProcessingCapture = false;
    print('🧹 [ShakeBilling] 已清空截屏处理队列');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shakeBillingEnabledKey, false);
    print('✅ [ShakeBilling] 摇一摇自动记账已禁用');

    try {
      await disableKeepAlive();
      _isKeepAliveEnabled = false;
    } catch (e) {
      print('⚠️ [ShakeBilling] 关闭保活服务失败: $e');
    }
  }

  /// 处理无障碍截屏数据（摇一摇路径）
  ///
  /// [data] 有两种格式：
  /// - 文件路径（API 31+ takeScreenshot） → 走 processScreenshot
  /// - "text:" 前缀（API 30- 节点文本）  → 走 processText
  ///
  /// 数据先入顺序队列，由 [_processCaptureQueue] 逐个处理，间隔 2 秒，
  /// 防止 App 切后台期间攒的多个截图同时触发 AI 造成通知轰炸。
  Future<void> _handleAccessibilityCapture(String data) async {
    // 内存状态检查 — Engine 重启后状态会丢失，回查持久化配置恢复
    if (!_isShakeBillingEnabled) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _isShakeBillingEnabled = prefs.getBool(_shakeBillingEnabledKey) ?? false;
      } catch (_) {}
      if (!_isShakeBillingEnabled) {
        print('⏭️ [ShakeBilling] 摇一摇已禁用，忽略无障碍截屏');
        _logStage('shake_disabled_ignore');
        return;
      }
      print('♻️ [ShakeBilling] 从持久化配置恢复摇一摇启用状态');
    }

    _captureQueue.add(data);
    if (!_isProcessingCapture) {
      _isProcessingCapture = true;
      await _processCaptureQueue();
    }
  }

  /// 记录 Dart 关键阶段到原生 Logcat（闪退后仍可通过日志查看）
  void _logStage(String stage) {
    print('🐛 [DartStage] $stage');
    try {
      _shakeBillingControlChannel.invokeMethod('logStage', {'stage': stage});
    } catch (_) {}
  }

  /// 顺序消费 [_captureQueue]，每次处理完一个等待 2 秒再处理下一个。
  Future<void> _processCaptureQueue() async {
    _logStage('capture_queue_start');
    while (_captureQueue.isNotEmpty) {
      _logStage('capture_queue_process_item');
      final data = _captureQueue.removeAt(0);
      try {
        if (data.startsWith('text:')) {
          _logStage('process_text');
          final text = data.substring(5);
          if (text.trim().isEmpty) {
            continue;
          }
          await _autoBillingService.processText(text, showProgressNotifications: false);
        } else {
          _logStage('process_screenshot');
          await _autoBillingService.processScreenshot(data, showProgressNotifications: false);
          // 清理私有缓存文件（无障碍截图存在 cacheDir，无存储权限限制）
          try {
            final file = File(data);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}
        }
        _logStage('cancel_progress_notification');
        // AI 出结果了，关闭之前 Kotlin 发的进度通知
        try {
          await _keepAliveChannel.invokeMethod('cancelProgressNotification');
        } catch (_) {}
        _logStage('queue_delay');
        // 每个结果间隔 2 秒，避免 AI 调用和通知同时弹出
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        _logStage('capture_queue_error');
        print('❌ [ShakeBilling] 处理截屏失败: $e');
        // 即使出错也关闭进度通知
        try {
          await _keepAliveChannel.invokeMethod('cancelProgressNotification');
        } catch (_) {}
      }
    }
    _logStage('capture_queue_done');
    _isProcessingCapture = false;
  }

  // ── 后台保活开关 ──

  /// 保活是否已启用
  Future<bool> isKeepAliveEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keepAliveEnabledKey) ?? false;
  }

  /// 启用保活（启动前台保活服务 + 持久化状态）
  Future<void> enableKeepAlive() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('仅支持 Android 平台');
    }
    try {
      await _keepAliveChannel.invokeMethod('startKeepAlive');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keepAliveEnabledKey, true);
      print('✅ [ShakeBilling] 保活服务已启用');
    } catch (e) {
      print('❌ [ShakeBilling] 启用保活服务失败: $e');
      rethrow;
    }
  }

  /// 禁用保活（停止前台保活服务 + 持久化状态）
  Future<void> disableKeepAlive() async {
    if (!Platform.isAndroid) return;
    try {
      await _keepAliveChannel.invokeMethod('stopKeepAlive');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keepAliveEnabledKey, false);
      print('✅ [ShakeBilling] 保活服务已禁用');
    } catch (e) {
      print('❌ [ShakeBilling] 禁用保活服务失败: $e');
      rethrow;
    }
  }

  /// 保活前台服务是否在运行中
  Future<bool> isKeepAliveRunning() async {
    try {
      final result = await _keepAliveChannel.invokeMethod('isKeepAliveRunning');
      return result == true;
    } catch (e) {
      print('❌ [ShakeBilling] 检查保活服务状态失败: $e');
      return false;
    }
  }

  /// 是否已忽略电池优化
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result = await _keepAliveChannel.invokeMethod('isIgnoringBatteryOptimizations');
      return result == true;
    } catch (e) {
      print('❌ [ShakeBilling] 检查电池优化状态失败: $e');
      return false;
    }
  }

  /// 打开系统电池优化设置页面
  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _keepAliveChannel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      print('❌ [ShakeBilling] 打开电池优化设置失败: $e');
    }
  }

  /// 打开自启动管理页面（各 ROM 适配）
  Future<bool> openAutoStartSettings() async {
    try {
      final result = await _keepAliveChannel.invokeMethod('openAutoStartSettings');
      return result == true;
    } catch (e) {
      print('❌ [ShakeBilling] 打开自启动设置失败: $e');
      return false;
    }
  }

  /// 查询保活综合状态
  Future<Map<String, dynamic>> getKeepAliveStatus() async {
    try {
      final result = await _keepAliveChannel.invokeMethod('getKeepAliveStatus');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } catch (e) {
      print('❌ [ShakeBilling] 查询保活状态失败: $e');
    }
    return {};
  }

  // ── 无障碍服务查询（与截图服务共用系统通道） ──

  /// 检查无障碍服务是否已启用
  Future<bool> checkAccessibilityServiceEnabled() async {
    try {
      final result = await _screenshotChannel.invokeMethod('isAccessibilityServiceEnabled');
      return result == true;
    } catch (e) {
      print('📳 [ShakeBilling] 检查无障碍服务状态失败: $e');
      return false;
    }
  }

  /// 打开系统无障碍设置页面
  Future<void> openAccessibilitySettings() async {
    try {
      await _screenshotChannel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      print('📳 [ShakeBilling] 打开无障碍设置失败: $e');
    }
  }

  // ── 通知渠道查询 ──

  /// 获取指定通知渠道的详细信息（用于判断横幅弹窗条件等）
  Future<Map<String, dynamic>> getNotificationChannelInfo(String channelId) async {
    try {
      final result = await _keepAliveChannel.invokeMethod('getNotificationChannelInfo', {
        'channelId': channelId,
      });
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } catch (e) {
      print('📢 [ShakeBilling] 查询通知渠道信息失败: $e');
    }
    return {};
  }

  /// 打开指定通知渠道的系统设置页面
  Future<void> openNotificationChannelSettings(String channelId) async {
    try {
      await _keepAliveChannel.invokeMethod('openNotificationChannelSettings', {
        'channelId': channelId,
      });
    } catch (e) {
      print('📢 [ShakeBilling] 打开通知渠道设置失败: $e');
    }
  }
}
