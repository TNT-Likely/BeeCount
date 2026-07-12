import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../providers/ai_chat_providers.dart';
import '../providers/ai_config_providers.dart';
import '../providers/voice_billing_providers.dart';
import '../services/system/logger_service.dart';
import '../ai/providers/ai_provider_manager.dart';
import '../ai/providers/ai_provider_config.dart';
import '../services/billing/post_processor.dart';
import '../services/data/tag_seed_service.dart';
import '../widgets/ui/ui.dart';
import '../styles/tokens.dart';

/// 语音记账帮助类
class VoiceBillingHelper {
  /// 启动语音记账
  static Future<void> startVoiceBilling(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);

    try {
      // 0. 确保 AI 配置已加载完成（修复首次使用报错问题）
      await ref.read(aiConfigProvider.notifier).ensureLoaded();
      // 确保语音记账设置（触发方式 / 静音阈值）已加载
      await ref.read(voiceBillingSettingsProvider.notifier).ensureLoaded();

      // 检查AI是否启用
      final aiConfig = ref.read(aiConfigProvider);
      if (!aiConfig.enabled) {
        if (!context.mounted) return;
        showToast(context, l10n.fabActionVoiceDisabled);
        return;
      }

      // 检查语音能力对应的服务商是否已配置 API Key（使用新的 Provider 系统）
      final speechProvider = await AIProviderManager.getProviderForCapability(
        AICapabilityType.speech,
      );
      if (speechProvider == null || !speechProvider.isValid) {
        if (!context.mounted) return;
        showToast(context, l10n.fabActionVoiceDisabled);
        return;
      }

      // 1. 检查并请求麦克风权限
      var status = await Permission.microphone.status;
      logger.info('VoiceBilling', '======== 语音记账权限检查 ========');
      logger.info('VoiceBilling', '当前麦克风权限状态: $status');
      logger.info('VoiceBilling', '权限详情:');
      logger.info('VoiceBilling', '  - isGranted: ${status.isGranted}');
      logger.info('VoiceBilling', '  - isDenied: ${status.isDenied}');
      logger.info('VoiceBilling',
          '  - isPermanentlyDenied: ${status.isPermanentlyDenied}');
      logger.info('VoiceBilling', '  - isRestricted: ${status.isRestricted}');
      logger.info('VoiceBilling', '  - isLimited: ${status.isLimited}');
      logger.info('VoiceBilling', '  - isProvisional: ${status.isProvisional}');

      // iOS 特殊处理：如果被限制（设备管理策略），引导用户检查设备设置
      if (status.isRestricted) {
        logger.warning('VoiceBilling', '麦克风权限被设备管理策略限制');
        if (!context.mounted) return;
        showToast(context, '设备管理策略限制了麦克风权限');
        return;
      }

      // Android 特殊处理：如果权限被永久拒绝，引导用户去设置
      if (status.isPermanentlyDenied) {
        logger.info('VoiceBilling', 'Android 权限被永久拒绝，弹出引导对话框');
        if (!context.mounted) return;
        final shouldOpenSettings = await AppDialog.confirm<bool>(
          context,
          title: l10n.voiceRecordingPermissionDeniedTitle,
          message: l10n.voiceRecordingPermissionDeniedMessage,
          okLabel: l10n.commonGoSettings,
          cancelLabel: l10n.commonCancel,
        );

        if (shouldOpenSettings == true) {
          logger.info('VoiceBilling', '用户选择前往设置');
          await openAppSettings();
        }
        return;
      }

      // 如果权限未授予，请求权限（iOS 和 Android 首次都会弹出系统对话框）
      if (!status.isGranted) {
        logger.info('VoiceBilling', '权限未授予，发起权限请求...');
        status = await Permission.microphone.request();
        logger.info('VoiceBilling', '请求后的权限状态: $status');
        logger.info('VoiceBilling', '  - isGranted: ${status.isGranted}');
        logger.info('VoiceBilling', '  - isDenied: ${status.isDenied}');

        if (!status.isGranted) {
          logger.warning('VoiceBilling', '用户拒绝了权限请求');
          if (!context.mounted) return;
          // 用户拒绝后，显示提示
          showToast(context, l10n.voiceRecordingPermissionDenied);
          return;
        }
      }

      logger.info('VoiceBilling', '✓ 麦克风权限已授予，准备开始录音');
      logger.info('VoiceBilling', '================================');

      // 2. 创建录音器
      final recorder = AudioRecorder();

      // 3. 准备录音文件路径（WAV，兼容传统 STT /audio/transcriptions）
      final tempDir = await getTemporaryDirectory();
      final audioPath =
          '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      // 4. 显示录音对话框（按用户配置的触发方式：自动检测 / 按住说话）
      if (!context.mounted) return;
      final settings = ref.read(voiceBillingSettingsProvider);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _VoiceRecordingDialog(
          audioPath: audioPath,
          recorder: recorder,
          triggerMode: settings.triggerMode,
          silenceTimeoutMs: settings.silenceTimeoutMs,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showToast(context, l10n.voiceRecordingStartFailed(e.toString()));
    }
  }
}

/// 语音录音对话框（私有）
class _VoiceRecordingDialog extends ConsumerStatefulWidget {
  final String audioPath;
  final AudioRecorder recorder;

  /// 触发方式：自动检测停顿 / 按住说话
  final VoiceTriggerMode triggerMode;

  /// 自动检测模式下的静音判定阈值（毫秒）
  final int silenceTimeoutMs;

  const _VoiceRecordingDialog({
    required this.audioPath,
    required this.recorder,
    required this.triggerMode,
    required this.silenceTimeoutMs,
  });

  @override
  ConsumerState<_VoiceRecordingDialog> createState() =>
      _VoiceRecordingDialogState();
}

class _VoiceRecordingDialogState extends ConsumerState<_VoiceRecordingDialog> {
  // 静音检测相关阈值（自动检测模式）。抽为常量便于统一调参。
  /// 起始静音判定（开场多少秒无语音则认为"没说话"）
  static const int _kStartSilenceTimeoutSec = 3;

  /// 最长录音时长上限（秒），防止静音检测失效导致永不停止
  static const int _kMaxRecordingSec = 60;

  /// 音量归一化阈值（约 -25dB），超过才计入"有声"
  static const double _kSoundThreshold = 0.58;

  /// 连续多少帧（每帧 100ms）有声才判定"开始说话"
  static const int _kConsecutiveSoundFrames = 5;

  /// 按住说话最短有效时长（毫秒），低于此值视为误触丢弃
  static const int _kMinHoldMs = 500;

  bool _isRecording = false;
  bool _isProcessing = false;
  String? _status;
  String? _recognizedText;
  int _duration = 0;
  double _amplitude = 0.0;
  DateTime? _lastSoundTime;
  bool _hasSpoken = false;
  int _consecutiveSoundCount = 0;
  Timer? _silenceTimer;
  Timer? _amplitudeTimer;

  /// 按住说话：是否正在长按录音
  bool _isHolding = false;

  /// 按住说话：录音是否正在启动中（recorder.start 在途）。
  /// 用于守卫快速「按-松-按」时对同一 recorder 并发调用 start()。
  bool _isStarting = false;

  /// 本次录音开始时间（用于按住说话的最短时长判定）
  DateTime? _recordStartTime;

  bool get _isHoldToTalk => widget.triggerMode == VoiceTriggerMode.holdToTalk;

  @override
  void initState() {
    super.initState();
    // 自动检测模式：弹窗打开即录音。按住说话模式：等待用户长按再录。
    if (!_isHoldToTalk) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRecording();
      });
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _amplitudeTimer?.cancel();
    widget.recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    try {
      await widget.recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
        ),
        path: widget.audioPath,
      );

      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _isRecording = true;
        _status = l10n.voiceRecordingInProgress;
        _lastSoundTime = now;
        _recordStartTime = now;
      });

      _startTimer();
      _startAmplitudeMonitoring();
      // 仅自动检测模式跑静音检测；按住说话靠松手结束，不做自动截断。
      if (!_isHoldToTalk) {
        _startSilenceDetection();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isHolding = false;
        _status = l10n.voiceRecordingFailed(e.toString());
      });
      // 按住说话分支 UI 不渲染 _status,启动失败时直接 toast 兜底,避免零反馈。
      if (_isHoldToTalk) {
        showToast(context, l10n.voiceRecordingFailed(e.toString()));
      }
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!_isRecording || !mounted) return;
      setState(() => _duration++);
      // 最长录音保护(两模式共用)：静音检测只在自动模式跑,按住说话靠此处兜底,
      // 防止长按几分钟产出超大 WAV、上传超时。
      if (_duration >= _kMaxRecordingSec) {
        if (_hasSpoken || _isHoldToTalk) {
          _stopAndProcess();
        } else {
          final l10n = AppLocalizations.of(context);
          Navigator.of(context).pop();
          showToast(context, l10n.voiceRecordingNoSpeech);
        }
        return;
      }
      _startTimer();
    });
  }

  void _startAmplitudeMonitoring() {
    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!mounted || !_isRecording) {
        timer.cancel();
        return;
      }

      try {
        final amplitude = await widget.recorder.getAmplitude();
        if (!mounted || !_isRecording) {
          timer.cancel();
          return;
        }

        final current = amplitude.current;
        final normalizedAmplitude = ((current + 60) / 60).clamp(0.0, 1.0);

        if (normalizedAmplitude > _kSoundThreshold) {
          _consecutiveSoundCount++;

          setState(() {
            _amplitude = normalizedAmplitude;
          });

          if (_consecutiveSoundCount >= _kConsecutiveSoundFrames) {
            _lastSoundTime = DateTime.now();
            if (!_hasSpoken) {
              setState(() {
                _hasSpoken = true;
              });
              logger.info('VoiceRecording', '检测到用户开始说话');
            }
          }
        } else {
          _consecutiveSoundCount = 0;
          setState(() {
            _amplitude = _amplitude * 0.7;
          });
        }
      } catch (e) {
        // 忽略错误
      }
    });
  }

  void _startSilenceDetection() {
    final startTime = DateTime.now();

    _silenceTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isRecording) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();

      // 注：最长录音上限已统一挪到 _startTimer(两模式共用),此处只管静音判定。

      if (!_hasSpoken) {
        if (now.difference(startTime).inSeconds >= _kStartSilenceTimeoutSec) {
          timer.cancel();
          if (mounted) {
            final l10n = AppLocalizations.of(context);
            Navigator.of(context).pop();
            showToast(context, l10n.voiceRecordingNoSpeech);
          }
        }
      } else {
        final lastSound = _lastSoundTime;
        if (lastSound != null &&
            now.difference(lastSound).inMilliseconds >=
                widget.silenceTimeoutMs) {
          timer.cancel();
          _stopAndProcess();
        }
      }
    });
  }

  /// 按住说话：长按开始录音
  Future<void> _onHoldStart() async {
    // 守卫覆盖「启动中」窗口：快速 按-松-按 时,第二次按下若仅看 _isRecording/
    // _isProcessing 均为 false 会放行,对同一 recorder 并发调 start()。
    if (_isRecording || _isProcessing || _isStarting) return;
    _isStarting = true;
    setState(() => _isHolding = true);
    try {
      await _startRecording();
    } finally {
      _isStarting = false;
    }
    // 竞态修复：录音已启动但启动期间用户已松手，丢弃 orphan 录音。
    // 限定 _isRecording，避免启动失败(catch 已 toast)时再叠一条"过短"提示。
    if (!_isHolding && _isRecording) {
      await _discardRecording();
      // 与正常 <500ms 路径体验一致：丢弃时提示录音过短。
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(context, l10n.voiceRecordingTooShort);
      }
    }
  }

  /// 按住说话：松手结束。录音过短视为误触丢弃，否则送识别。
  Future<void> _onHoldEnd() async {
    if (!_isHolding) return;
    setState(() => _isHolding = false);
    if (!_isRecording) return;

    final start = _recordStartTime;
    final tooShort = start != null &&
        DateTime.now().difference(start).inMilliseconds < _kMinHoldMs;
    if (tooShort) {
      await _discardRecording();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(context, l10n.voiceRecordingTooShort);
      }
      return;
    }
    await _stopAndProcess();
  }

  /// 丢弃当前录音（不送识别），用于按住说话误触场景。
  Future<void> _discardRecording() async {
    _silenceTimer?.cancel();
    _amplitudeTimer?.cancel();
    // mounted 保护：按下→松手→取消三步都发生在 recorder.start() 在途窗口内时,
    // State 可能已 dispose,此处对已卸载的 State 调 setState 会崩溃。
    if (!mounted) {
      _isRecording = false;
      _hasSpoken = false;
      _duration = 0;
    } else {
      setState(() {
        _isRecording = false;
        _hasSpoken = false;
        _duration = 0;
      });
    }
    try {
      await widget.recorder.stop();
    } catch (_) {}
    try {
      await File(widget.audioPath).delete();
    } catch (_) {}
  }

  Future<void> _stopAndProcess() async {
    if (!_isRecording) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _status = l10n.voiceRecordingProcessing;
    });

    try {
      await widget.recorder.stop();

      final audioFile = File(widget.audioPath);
      final currentLedger = await ref.read(currentLedgerProvider.future);
      if (currentLedger == null) {
        throw Exception(l10n.voiceRecordingNoLedger);
      }

      logger.info('VoiceRecording', '调用 AiBookkeeper.fromAudio');
      final bookkeeper = ref.read(aiBookkeeperProvider);
      final response = await bookkeeper.fromAudio(
        audio: audioFile,
        ledgerId: currentLedger.id,
        billingTypes: [
          TagSeedService.billingTypeVoice,
          TagSeedService.billingTypeAi,
        ],
        l10n: l10n,
      );

      if (!mounted) return;

      // 把识别文字立即展示出来,让用户能看到「机器听到了什么」
      if (response.recognizedText != null) {
        setState(() {
          _recognizedText = response.recognizedText;
        });
        logger.info('VoiceRecording', '识别文字: ${response.recognizedText}');
      }

      if (!response.result.success) {
        Navigator.of(context).pop();
        // 识别有文字但没提取出账单 → 展示原文给用户;完全没识别到 → 通用失败
        final msg = response.recognizedText != null
            ? l10n.voiceRecordingNoInfoDetected(response.recognizedText!)
            : l10n.voiceRecordingNoInfo;
        showToast(context, msg);
        return;
      }

      await PostProcessor.run(ref, ledgerId: currentLedger.id, tags: true);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!mounted) return;

      final toast = response.result.isMulti
          ? '${l10n.voiceRecordingSuccess} × ${response.result.savedCount}'
          : l10n.voiceRecordingSuccess;
      showToast(context, toast);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _status = l10n.voiceRecordingRecognizeFailed(e.toString());
      });
    } finally {
      try {
        await File(widget.audioPath).delete();
      } catch (_) {}
    }
  }

  /// 录音振幅可视化圆形（自动检测与按住说话共用）。
  Widget _buildAmplitudeCircle() {
    final primaryColor = ref.watch(primaryColorProvider);
    return SizedBox(
      height: 80,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 60 + (_amplitude * 40),
          height: 60 + (_amplitude * 40),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withValues(alpha: 0.3),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.5),
                blurRadius: 10 + (_amplitude * 20),
                spreadRadius: _amplitude * 10,
              ),
            ],
          ),
          child: Center(
            child: Icon(Icons.mic, size: 30, color: primaryColor),
          ),
        ),
      ),
    );
  }

  /// 识别结果展示块（处理中）。
  Widget _buildRecognizedTextBlock() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BeeTokens.surface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BeeTokens.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.voiceRecordingResultLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: ref.watch(primaryColorProvider),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _recognizedText!,
            style: TextStyle(
              fontSize: 14,
              color: BeeTokens.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 自动检测模式录音中 UI。
  List<Widget> _buildAutoRecordingContent(AppLocalizations l10n) {
    return [
      _buildAmplitudeCircle(),
      const SizedBox(height: 16),
      Text(
        _hasSpoken
            ? l10n.voiceRecordingAutoHintSpoken
            : l10n.voiceRecordingAutoHintWaiting,
        style: TextStyle(
          fontSize: 14,
          color: _hasSpoken
              ? ref.watch(primaryColorProvider)
              : BeeTokens.textSecondary(context),
          fontWeight: _hasSpoken ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        l10n.voiceRecordingDuration(_duration),
        style: TextStyle(fontSize: 12, color: BeeTokens.textSecondary(context)),
      ),
    ];
  }

  /// 按住说话模式 UI（长按按钮 + 提示）。
  List<Widget> _buildHoldToTalkContent(AppLocalizations l10n) {
    final primaryColor = ref.watch(primaryColorProvider);
    return [
      if (_isRecording) ...[
        _buildAmplitudeCircle(),
        const SizedBox(height: 8),
        Text(
          l10n.voiceRecordingDuration(_duration),
          style:
              TextStyle(fontSize: 12, color: BeeTokens.textSecondary(context)),
        ),
        const SizedBox(height: 16),
      ] else
        const SizedBox(height: 8),
      // 用 Listener 监听原始指针按下/抬起，比 LongPress 手势更适合"按住说话"。
      Listener(
        onPointerDown: (_) => _onHoldStart(),
        onPointerUp: (_) => _onHoldEnd(),
        onPointerCancel: (_) => _onHoldEnd(),
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isHolding
                ? primaryColor
                : primaryColor.withValues(alpha: 0.15),
          ),
          child: Icon(
            Icons.mic,
            size: 40,
            color: _isHolding ? BeeTokens.textOnPrimary(context) : primaryColor,
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        _isRecording
            ? l10n.voiceRecordingReleaseToFinish
            : l10n.voiceRecordingHoldToTalk,
        style: TextStyle(
          fontSize: 14,
          color: _isRecording ? primaryColor : BeeTokens.textSecondary(context),
          fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.voiceRecordingTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isProcessing) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status ?? l10n.voiceRecordingProcessing),
            if (_recognizedText != null) ...[
              const SizedBox(height: 16),
              _buildRecognizedTextBlock(),
            ],
          ] else if (_isHoldToTalk) ...[
            ..._buildHoldToTalkContent(l10n),
          ] else if (_isRecording) ...[
            ..._buildAutoRecordingContent(l10n),
          ] else ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status ?? l10n.voiceRecordingPreparing),
          ],
        ],
      ),
      actions: [
        // 自动检测模式提供「完成」按钮手动结束；按住说话靠松手结束，不需要。
        if (_isRecording && !_isHoldToTalk)
          TextButton(
            onPressed: _stopAndProcess,
            child: Text(l10n.commonFinish),
          ),
        if (!_isProcessing)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
      ],
    );
  }
}
