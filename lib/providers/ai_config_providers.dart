import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/providers/ai_constants.dart';
import '../ai/providers/ai_provider_config.dart';
import '../ai/providers/ai_provider_manager.dart';

/// AI 执行策略
enum AIStrategy {
  /// 本地优先
  localFirst,

  /// 云端优先
  cloudFirst,

  /// 仅本地
  localOnly,

  /// 仅云端
  cloudOnly,
}

/// AI 全局配置数据类
///
/// 只管理全局开关和策略设置，服务商配置由 AIProviderManager 管理
class AIConfigData {
  /// AI 增强是否启用
  final bool enabled;

  /// 是否使用视觉模型（上传图片）
  final bool useVision;

  /// 执行策略
  final AIStrategy strategy;

  const AIConfigData({
    this.enabled = false,
    this.useVision = true,
    this.strategy = AIStrategy.cloudFirst,
  });

  /// 复制并修改
  AIConfigData copyWith({
    bool? enabled,
    bool? useVision,
    AIStrategy? strategy,
  }) {
    return AIConfigData(
      enabled: enabled ?? this.enabled,
      useVision: useVision ?? this.useVision,
      strategy: strategy ?? this.strategy,
    );
  }
}

/// AI 全局配置 Notifier
///
/// 只管理全局开关和策略设置，服务商配置由 AIProviderManager 管理
class AIConfigNotifier extends StateNotifier<AIConfigData> {
  /// 加载完成标志
  final Completer<void> _loadCompleter = Completer<void>();

  AIConfigNotifier() : super(const AIConfigData()) {
    _loadFromPrefs();
  }

  /// 确保配置已加载完成
  ///
  /// 在需要读取配置前调用此方法，确保异步加载已完成
  Future<void> ensureLoaded() => _loadCompleter.future;

  /// 从 SharedPreferences 加载配置
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final strategyStr =
        prefs.getString(AIConstants.keyAiStrategy) ?? 'cloud_first';
    final strategy = _parseStrategy(strategyStr);

    // mounted 检查防 dispose-after-await:server profile_change 触发
    // sync_providers 的 ref.invalidate(aiConfigProvider) 会让老 notifier dispose,
    // 但本方法的 SharedPreferences.getInstance() / 后续 setter 已经在飞,
    // dispose 后再设 state 会抛 "Tried to use AIConfigNotifier after dispose"。
    if (!mounted) return;

    state = AIConfigData(
      enabled: prefs.getBool(AIConstants.keyAiBillExtractionEnabled) ?? false,
      useVision: prefs.getBool(AIConstants.keyAiUseVision) ?? true,
      strategy: strategy,
    );

    // 标记加载完成
    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
  }

  AIStrategy _parseStrategy(String str) {
    switch (str) {
      case 'local_first':
        return AIStrategy.localFirst;
      case 'cloud_first':
        return AIStrategy.cloudFirst;
      case 'local_only':
        return AIStrategy.localOnly;
      case 'cloud_only':
        return AIStrategy.cloudOnly;
      default:
        return AIStrategy.cloudFirst;
    }
  }

  String _strategyToString(AIStrategy strategy) {
    switch (strategy) {
      case AIStrategy.localFirst:
        return 'local_first';
      case AIStrategy.cloudFirst:
        return 'cloud_first';
      case AIStrategy.localOnly:
        return 'local_only';
      case AIStrategy.cloudOnly:
        return 'cloud_only';
    }
  }

  /// 保存配置到 SharedPreferences
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AIConstants.keyAiStrategy, _strategyToString(state.strategy));
    await prefs.setBool(AIConstants.keyAiBillExtractionEnabled, state.enabled);
    await prefs.setBool(AIConstants.keyAiUseVision, state.useVision);
    // 策略 / 账单提取开关 / 图片识别开关也属于 AI 配置 snapshot 的一部分,
    // 同样走 AIProviderManager.onConfigChanged 推到 server。不触发的话
    // web/B 设备只能拉到 providers + binding + prompt,strategy 等设置落不下去。
    try {
      AIProviderManager.onConfigChanged?.call();
    } catch (_) {}
  }

  /// 设置执行策略
  Future<void> setStrategy(AIStrategy strategy) async {
    state = state.copyWith(strategy: strategy);
    await _saveToPrefs();
  }

  /// 设置启用状态
  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _saveToPrefs();
  }

  /// 设置是否使用视觉模型
  Future<void> setUseVision(bool useVision) async {
    state = state.copyWith(useVision: useVision);
    await _saveToPrefs();
  }

  /// 重新加载配置
  Future<void> reload() async {
    await _loadFromPrefs();
  }
}

/// AI 全局配置 Provider
final aiConfigProvider =
    StateNotifierProvider<AIConfigNotifier, AIConfigData>((ref) {
  return AIConfigNotifier();
});

/// AI 是否启用 Provider（简化访问）
final aiEnabledProvider = Provider<bool>((ref) {
  return ref.watch(aiConfigProvider).enabled;
});

// ============================================================
// 新版多服务商架构 Providers
// ============================================================

/// 能力绑定刷新 Provider
final aiCapabilityBindingRefreshProvider = StateProvider<int>((ref) => 0);

/// 能力绑定数据 Provider
final aiCapabilityBindingProvider = FutureProvider<AICapabilityBinding>((ref) async {
  ref.watch(aiCapabilityBindingRefreshProvider);
  return AIProviderManager.getCapabilityBinding();
});

/// 服务商列表刷新 Provider (供能力选择使用)
final aiProviderListForCapabilityRefreshProvider = StateProvider<int>((ref) => 0);

/// 服务商列表 Provider (供能力选择使用)
final aiProviderListForCapabilityProvider = FutureProvider<List<AIServiceProviderConfig>>((ref) async {
  ref.watch(aiProviderListForCapabilityRefreshProvider);
  return AIProviderManager.getProviders();
});
