import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as s;
import '../providers.dart';
import '../cloud/auth.dart';
import '../widgets/ui/ui.dart';
import '../utils/logger.dart';
import '../l10n/app_localizations.dart';

enum AuthMode { login, signup }

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, this.initialMode = AuthMode.login});
  final AuthMode initialMode;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final pwd2Ctrl = TextEditingController();
  String? errorText;
  String? infoText;
  bool busy = false;
  late bool isSignup;
  bool _showPwd = false;
  bool _showPwd2 = false;
  void _switchMode(bool toSignup) {
    setState(() {
      isSignup = toSignup;
      errorText = null;
      infoText = null;
    });
  }

  AuthService get auth => ref.read(authServiceProvider);

  @override
  void initState() {
    super.initState();
    isSignup = widget.initialMode == AuthMode.signup;
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    pwdCtrl.dispose();
    pwd2Ctrl.dispose();
    super.dispose();
  }

  bool isValidEmail(String s) {
    final t = s.trim();
    final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRe.hasMatch(t);
  }

  bool isValidPassword(String s) {
    if (s.length < 6) return false;
    final hasAlpha = RegExp(r'[A-Za-z]').hasMatch(s);
    final hasDigit = RegExp(r'\d').hasMatch(s);
    return hasAlpha && hasDigit;
  }

  String? _supabaseCode(Object e) {
    try {
      if (e is s.AuthApiException) return e.code;
      if (e is s.AuthException) return null;
    } catch (_) {}
    final txt = e.toString().toLowerCase();
    final m = RegExp(r'code:\s*([a-z0-9_\-]+)').firstMatch(txt);
    return m?.group(1);
  }

  String friendlyAuthError(Object e) {
    final code = _supabaseCode(e);
    if (code != null) {
      switch (code) {
        case 'invalid_credentials':
          return AppLocalizations.of(context).authErrorInvalidCredentials;
        case 'email_address_not_confirmed':
        case 'email_not_confirmed':
          return AppLocalizations.of(context).authErrorEmailNotConfirmed;
        case 'over_email_send_rate_limit':
          return AppLocalizations.of(context).authErrorRateLimit;
      }
    }
    final msg = e.toString().toLowerCase();
    if (msg.contains('email') &&
        msg.contains('not') &&
        msg.contains('confirmed')) {
      return AppLocalizations.of(context).authErrorEmailNotConfirmed;
    }
    if (msg.contains('invalid') &&
        (msg.contains('login') ||
            msg.contains('credential') ||
            msg.contains('password'))) {
      return AppLocalizations.of(context).authErrorInvalidCredentials;
    }
    if (msg.contains('rate') && msg.contains('limit')) {
      return AppLocalizations.of(context).authErrorRateLimit;
    }
    if (msg.contains('network') || msg.contains('timeout')) {
      return AppLocalizations.of(context).authErrorNetworkIssue;
    }
    return AppLocalizations.of(context).authErrorLoginFailed;
  }

  String friendlySignupError(Object e) {
    final code = _supabaseCode(e);
    if (code != null) {
      switch (code) {
        case 'email_address_invalid':
          return AppLocalizations.of(context).authErrorEmailInvalid;
        case 'user_already_exists':
        case 'email_address_exists':
          return AppLocalizations.of(context).authErrorEmailExists;
        case 'weak_password':
          return AppLocalizations.of(context).authErrorWeakPassword;
        case 'over_email_send_rate_limit':
          return AppLocalizations.of(context).authErrorRateLimit;
      }
    }
    final lower = e.toString().toLowerCase();
    if (lower.contains('weak') ||
        (lower.contains('password') && lower.contains('at least'))) {
      return AppLocalizations.of(context).authErrorWeakPassword;
    }
    if (lower.contains('already') && lower.contains('registered')) {
      return AppLocalizations.of(context).authErrorEmailExists;
    }
    if (lower.contains('rate') && lower.contains('limit')) {
      return AppLocalizations.of(context).authErrorRateLimit;
    }
    if (lower.contains('network') || lower.contains('timeout')) {
      return AppLocalizations.of(context).authErrorNetworkIssue;
    }
    return AppLocalizations.of(context).authErrorSignupFailed;
  }

  String friendlyActionError(Object e, {required String action}) {
    final code = _supabaseCode(e);
    if (code != null) {
      switch (code) {
        case 'user_not_found':
          return AppLocalizations.of(context).authErrorUserNotFound(action);
        case 'over_email_send_rate_limit':
          return AppLocalizations.of(context).authErrorRateLimit;
        case 'email_address_not_confirmed':
        case 'email_not_confirmed':
          return AppLocalizations.of(context).authErrorEmailNotVerified(action);
      }
    }
    final lower = e.toString().toLowerCase();
    if (lower.contains('email') &&
        lower.contains('not') &&
        lower.contains('confirm')) {
      return AppLocalizations.of(context).authErrorEmailNotVerified(action);
    }
    if (lower.contains('rate') && lower.contains('limit')) {
      return AppLocalizations.of(context).authErrorRateLimit;
    }
    if (lower.contains('network') || lower.contains('timeout')) {
      return AppLocalizations.of(context).authErrorNetworkIssue;
    }
    return AppLocalizations.of(context).authErrorActionFailed(action);
  }

  // 恢复流程改为登录后回到“我的”页由其触发，不再在登录页内执行

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(title: isSignup ? AppLocalizations.of(context).authSignup : AppLocalizations.of(context).authLogin, showBack: true),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ChoiceChip(
                              selected: !isSignup,
                              label: Text(AppLocalizations.of(context).authLogin),
                              selectedColor: theme.colorScheme.primary,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: theme.colorScheme.primary,
                                width: (!isSignup) ? 0 : 1,
                              ),
                              labelStyle: TextStyle(
                                color: (!isSignup)
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.primary,
                                fontWeight: (!isSignup)
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              onSelected: (v) => _switchMode(false),
                              checkmarkColor: theme.colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              selected: isSignup,
                              label: Text(AppLocalizations.of(context).authSignup),
                              selectedColor: theme.colorScheme.primary,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: theme.colorScheme.primary,
                                width: (isSignup) ? 0 : 1,
                              ),
                              labelStyle: TextStyle(
                                color: (isSignup)
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.primary,
                                fontWeight: (isSignup)
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              onSelected: (v) => _switchMode(true),
                              checkmarkColor: theme.colorScheme.onPrimary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(labelText: AppLocalizations.of(context).authEmail),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: pwdCtrl,
                          obscureText: !_showPwd,
                          decoration: InputDecoration(
                            labelText: isSignup ? AppLocalizations.of(context).authPasswordRequirement : AppLocalizations.of(context).authPassword,
                            suffixIcon: IconButton(
                              icon: Icon(_showPwd
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () =>
                                  setState(() => _showPwd = !_showPwd),
                            ),
                          ),
                        ),
                        if (isSignup) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: pwd2Ctrl,
                            obscureText: !_showPwd2,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).authConfirmPassword,
                              suffixIcon: IconButton(
                                icon: Icon(_showPwd2
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () =>
                                    setState(() => _showPwd2 = !_showPwd2),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              errorText!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        if (infoText != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              infoText!,
                              style: const TextStyle(color: Colors.green),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: isSignup
                              ? OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: radius),
                                    foregroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    side: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          final email = emailCtrl.text.trim();
                                          final pwd = pwdCtrl.text;
                                          final pwd2 = pwd2Ctrl.text;
                                          logI('auth', '开始注册：邮箱=$email');
                                          if (!isValidEmail(email)) {
                                            setState(
                                                () => errorText = 'AppLocalizations.of(context).authInvalidEmail');
                                            return;
                                          }
                                          if (!isValidPassword(pwd)) {
                                            setState(() => errorText =
                                                'AppLocalizations.of(context).authPasswordRequirementShort');
                                            return;
                                          }
                                          if (pwd != pwd2) {
                                            setState(
                                                () => errorText = AppLocalizations.of(context).authPasswordMismatch);
                                            return;
                                          }
                                          setState(() {
                                            busy = true;
                                            errorText = null;
                                            infoText = null;
                                          });
                                          try {
                                            await auth.signUpWithEmail(
                                                email: email, password: pwd);
                                            if (!context.mounted) return;
                                            logI('auth',
                                                '注册成功，已发送验证邮件：邮箱=$email');
                                            Navigator.of(context)
                                                .pushReplacement(
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const SignupSuccessPage()),
                                            );
                                          } catch (e, stSignup) {
                                            final friendlyMsg = friendlySignupError(e);
                                            final detailedMsg = 'Type: ${e.runtimeType}, Message: $e';
                                            logE(
                                                'auth',
                                                '注册失败：邮箱=$email，用户友好信息=$friendlyMsg，详细错误=$detailedMsg',
                                                e,
                                                stSignup);
                                            setState(() => errorText =
                                                '$friendlyMsg\n\n调试信息: $detailedMsg');
                                          } finally {
                                            if (mounted) {
                                              setState(() => busy = false);
                                            }
                                          }
                                        },
                                  child: busy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : Text(AppLocalizations.of(context).authSignup),
                                )
                              : FilledButton(
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: radius),
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          final email = emailCtrl.text.trim();
                                          final pwd = pwdCtrl.text;
                                          logI('auth', '开始登录：邮箱=$email');
                                          if (!isValidEmail(email)) {
                                            setState(
                                                () => errorText = 'AppLocalizations.of(context).authInvalidEmail');
                                            return;
                                          }
                                          if (!isValidPassword(pwd)) {
                                            setState(() => errorText =
                                                'AppLocalizations.of(context).authPasswordRequirementShort');
                                            return;
                                          }
                                          setState(() {
                                            busy = true;
                                            errorText = null;
                                            infoText = null;
                                          });
                                          try {
                                            await auth.signInWithEmail(
                                                email: email, password: pwd);
                                            if (!context.mounted) return;
                                            logI('auth', '登录成功：邮箱=$email');
                                            ref
                                                .read(syncStatusRefreshProvider
                                                    .notifier)
                                                .state++;
                                            // 登录成功：让“我的”页去检测是否需要恢复
                                            ref
                                                .read(
                                                    restoreCheckRequestProvider
                                                        .notifier)
                                                .state = true;
                                            // 直接切到"我的"页并关闭登录页
                                            ref
                                                .read(bottomTabIndexProvider
                                                    .notifier)
                                                .state = 3; // Mine tab index
                                            final can = Navigator.of(context)
                                                .canPop();
                                            logI('nav',
                                                'login: success -> switch tab to Mine, canPop=$can; pop login');
                                            if (can) {
                                              Navigator.of(context).pop();
                                            }
                                          } catch (e, st) {
                                            final msg = friendlyAuthError(e);
                                            final detailedMsg = 'Type: ${e.runtimeType}, Message: $e';
                                            logE(
                                                'auth',
                                                '登录失败：邮箱=$email，用户友好信息=$msg，详细错误=$detailedMsg',
                                                e,
                                                st);
                                            setState(() => errorText = '$msg\n\n调试信息: $detailedMsg');
                                          } finally {
                                            if (mounted) {
                                              setState(() => busy = false);
                                            }
                                          }
                                        },
                                  child: busy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : Text(AppLocalizations.of(context).authLogin),
                                ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final email = emailCtrl.text.trim();
                                      if (!isValidEmail(email)) {
                                        setState(
                                            () => errorText = 'AppLocalizations.of(context).authInvalidEmail');
                                        return;
                                      }
                                      setState(() {
                                        errorText = null;
                                        infoText = null;
                                        busy = true;
                                      });
                                      try {
                                        await auth.resendEmailVerification(
                                            email: email);
                                        if (!context.mounted) return;
                                        showToast(context, AppLocalizations.of(context).authVerificationEmailResent);
                                        setState(() => infoText = AppLocalizations.of(context).authVerificationEmailResent);
                                      } catch (e) {
                                        final msg = friendlyActionError(e,
                                            action: AppLocalizations.of(context).authResendAction);
                                        if (!context.mounted) return;
                                        showToast(context, msg);
                                        setState(() => errorText = msg);
                                      } finally {
                                        if (mounted) {
                                          setState(() => busy = false);
                                        }
                                      }
                                    },
                              child: Text(AppLocalizations.of(context).authResendVerification),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthPage(initialMode: AuthMode.login);
}

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthPage(initialMode: AuthMode.signup);
}

class SignupSuccessPage extends StatelessWidget {
  const SignupSuccessPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(title: AppLocalizations.of(context).authSignupSuccess, showBack: false),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mark_email_read_outlined,
                        size: 72, color: Colors.green),
                    const SizedBox(height: 12),
                    Text(AppLocalizations.of(context).authVerificationEmailSent),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      child: Text(AppLocalizations.of(context).authBackToMinePage),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 旧的对话框已废弃，改为独立页面展示
