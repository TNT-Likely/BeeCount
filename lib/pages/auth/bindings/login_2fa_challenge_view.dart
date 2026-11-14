import 'package:flutter/material.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/theme_providers.dart';
import '../../../styles/tokens.dart';

/// 2FA 输码对话框 — 当 BeeCountCloudAuthService.signInWithEmail 收到 server 的
/// requires_2fa=true 响应时,通过 [BeeCountCloudProvider.globalTwoFactorHandler]
/// 注册的回调把它弹出来,让用户输 6 位 TOTP 或 recovery code。
///
/// 失败 → 内部调 [TwoFactorChallengeRequest.verify] 拿 server 错误消息,就地
/// 展示让用户重试,**不会跳走 / 关闭**。成功 → 关闭并 pop true。用户取消 → pop false。
///
/// 设计文档:.docs/2fa-design.md(第 4.6 节)。
class Login2FAChallengeDialog extends ConsumerStatefulWidget {
  final TwoFactorChallengeRequest request;

  const Login2FAChallengeDialog({super.key, required this.request});

  /// 用法:`final ok = await Login2FAChallengeDialog.show(context, request);`
  static Future<bool> show(
    BuildContext context,
    TwoFactorChallengeRequest request,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Login2FAChallengeDialog(request: request),
    );
    return result ?? false;
  }

  @override
  ConsumerState<Login2FAChallengeDialog> createState() =>
      _Login2FAChallengeDialogState();
}

class _Login2FAChallengeDialogState
    extends ConsumerState<Login2FAChallengeDialog> {
  late final TextEditingController _codeController;
  String _method = 'totp';
  bool _verifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    final methods = widget.request.availableMethods;
    if (!methods.contains('totp') && methods.isNotEmpty) {
      _method = methods.first;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_verifying) return;
    final raw = _codeController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) return;
    setState(() {
      _verifying = true;
      _errorMessage = null;
    });
    try {
      final err = await widget.request.verify(_method, raw);
      if (!mounted) return;
      if (err == null) {
        // 验证通过 → 关闭对话框,handler resolve true
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = err;
          _verifying = false;
          _codeController.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _verifying = false;
      });
    }
  }

  void _onCancel() {
    if (_verifying) return;
    Navigator.of(context).pop(false);
  }

  bool get _canSubmit {
    if (_verifying) return false;
    final raw = _codeController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (_method == 'totp') return raw.length == 6;
    final stripped = raw.replaceAll('-', '');
    return stripped.length >= 6;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeTwoFactorChallengeDialog(
      title: l.twofaChallengeTitle,
      email: widget.request.email,
      method: _method,
      totpLabel: l.twofaMethodTotp,
      recoveryLabel: l.twofaMethodRecovery,
      totpHint: l.twofaTotpInputPlaceholder,
      recoveryHint: l.twofaRecoveryInputPlaceholder,
      cancelLabel: l.commonCancel,
      verifyLabel: l.twofaVerifyButton,
      controller: _codeController,
      hasRecovery: widget.request.availableMethods.contains('recovery_code'),
      verifying: _verifying,
      canSubmit: _canSubmit,
      errorMessage: _errorMessage,
      primaryColor: ref.watch(primaryColorProvider),
      foregroundColor: BeeTokens.textPrimary(context),
      secondaryColor: BeeTokens.textSecondary(context),
      hintColor: BeeTokens.textTertiary(context),
      onMethodChanged: (method) => setState(() {
        _method = method;
        _codeController.clear();
        _errorMessage = null;
      }),
      onCodeChanged: (_) => setState(() => _errorMessage = null),
      onSubmit: _onSubmit,
      onCancel: _onCancel,
    );
  }
}
