import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/providers/ai_constants.dart';
import '../ai/providers/ai_provider_manager.dart';
import '../services/system/logger_service.dart';

/// 语音记账触发方式
enum VoiceTriggerMode {
  /// 自动检测：录音后靠静音检测自动判定说完
  auto,

  /// 按住说话：长按录音、松手结束（类似微信发语音）
  holdToTalk,
}

/// 触发方式与字符串互转（用于持久化与多设备同步）
extension VoiceTriggerModeCodec on VoiceTriggerMode {
  String get storageValue {
    switch (this) {
      case VoiceTriggerMode.auto:
        return 'auto';
      case VoiceTriggerMode.holdToTalk:
        return 'hold_to_talk';
    }
  }

  static VoiceTriggerMode fromStorage(String? value) {
    switch (value) {
      case 'hold_to_talk':
        return VoiceTriggerMode.holdToTalk;
      case 'auto':
      default:
        return VoiceTriggerMode.auto;
    }
  }
}

/// 语音记账设置数据
class VoiceBillingSettings {
  /// 触发方式
  final VoiceTriggerMode triggerMode;

  /// 自动检测模式下的静音判定阈值（毫秒）
  final int silenceTimeoutMs;

  const VoiceBillingSettings({
    this.triggerMode = VoiceTriggerMode.auto,
    this.silenceTimeoutMs = defaultSilenceTimeoutMs,
  });

  /// 默认静音阈值（毫秒）：从历史的 800ms 放宽到 1500ms，对自然停顿更友好
  static const int defaultSilenceTimeoutMs = 1500;

  /// 静音阈值可调下限（毫秒）
  static const int minSilenceTimeoutMs = 500;

  /// 静音阈值可调上限（毫秒）
  static const int maxSilenceTimeoutMs = 4000;

  VoiceBillingSettings copyWith({
    VoiceTriggerMode? triggerMode,
    int? silenceTimeoutMs,
  }) {
    return VoiceBillingSettings(
      triggerMode: triggerMode ?? this.triggerMode,
      silenceTimeoutMs: silenceTimeoutMs ?? this.silenceTimeoutMs,
    );
  }
}

/// 语音记账设置 Notifier
class VoiceBillingSettingsNotifier extends StateNotifier<VoiceBillingSettings> {
  final Completer<void> _loadCompleter = Completer<void>();

  VoiceBillingSettingsNotifier() : super(const VoiceBillingSettings()) {
    _load();
  }

  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = VoiceTriggerModeCodec.fromStorage(
      prefs.getString(AIConstants.keyVoiceTriggerMode),
    );
    final timeout = _clampTimeout(
      prefs.getInt(AIConstants.keyVoiceSilenceTimeoutMs) ??
          VoiceBillingSettings.defaultSilenceTimeoutMs,
    );

    // 先完成 Completer,再做 mounted 检查：否则 notifier 若在加载完成前被 dispose,
    // 早退会跳过 complete,导致 ensureLoaded() 的 future 永不完成、调用方永久挂起。
    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
    if (!mounted) return;
    state = VoiceBillingSettings(triggerMode: mode, silenceTimeoutMs: timeout);
  }

  static int _clampTimeout(int value) => value.clamp(
        VoiceBillingSettings.minSilenceTimeoutMs,
        VoiceBillingSettings.maxSilenceTimeoutMs,
      );

  /// 设置触发方式
  Future<void> setTriggerMode(VoiceTriggerMode mode) async {
    state = state.copyWith(triggerMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AIConstants.keyVoiceTriggerMode, mode.storageValue);
    _notifyConfigChanged();
  }

  /// 设置静音判定阈值（毫秒），自动夹取到合法区间
  Future<void> setSilenceTimeoutMs(int value) async {
    final clamped = _clampTimeout(value);
    state = state.copyWith(silenceTimeoutMs: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AIConstants.keyVoiceSilenceTimeoutMs, clamped);
    _notifyConfigChanged();
  }

  Future<void> reload() => _load();

  void _notifyConfigChanged() {
    try {
      AIProviderManager.onConfigChanged?.call();
    } catch (e, st) {
      logger.warning('VoiceBillingSettings', 'onConfigChanged 触发失败: $e', st);
    }
  }
}

final voiceBillingSettingsProvider =
    StateNotifierProvider<VoiceBillingSettingsNotifier, VoiceBillingSettings>(
        (ref) {
  return VoiceBillingSettingsNotifier();
});
