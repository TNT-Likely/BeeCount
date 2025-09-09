import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as s;
import '../providers.dart';
import '../cloud/auth.dart';
import '../widgets/ui/ui.dart';
import '../utils/logger.dart';
import '../services/restore_service.dart';

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
          return '邮箱或密码不正确。';
        case 'email_address_not_confirmed':
        case 'email_not_confirmed':
          return '邮箱未验证，请先到邮箱完成验证再登录。';
        case 'over_email_send_rate_limit':
          return '操作过于频繁，请稍后再试。';
      }
    }
    final msg = e.toString().toLowerCase();
    if (msg.contains('email') &&
        msg.contains('not') &&
        msg.contains('confirmed')) {
      return '邮箱未验证，请先到邮箱完成验证再登录。';
    }
    if (msg.contains('invalid') &&
        (msg.contains('login') ||
            msg.contains('credential') ||
            msg.contains('password'))) {
      return '邮箱或密码不正确。';
    }
    if (msg.contains('rate') && msg.contains('limit')) {
      return '操作过于频繁，请稍后再试。';
    }
    if (msg.contains('network') || msg.contains('timeout')) {
      return '网络异常，请检查网络后重试。';
    }
    return '登录失败，请稍后再试。';
  }

  String friendlySignupError(Object e) {
    final code = _supabaseCode(e);
    if (code != null) {
      switch (code) {
        case 'email_address_invalid':
          return '邮箱地址无效，请检查是否拼写有误。';
        case 'user_already_exists':
        case 'email_address_exists':
          return '该邮箱已注册，请直接登录或重置密码。';
        case 'weak_password':
          return '密码过于简单，请包含字母和数字，长度至少 6 位。';
        case 'over_email_send_rate_limit':
          return '操作过于频繁，请稍后再试。';
      }
    }
    final lower = e.toString().toLowerCase();
    if (lower.contains('weak') ||
        (lower.contains('password') && lower.contains('at least'))) {
      return '密码过于简单，请包含字母和数字，长度至少 6 位。';
    }
    if (lower.contains('already') && lower.contains('registered')) {
      return '该邮箱已注册，请直接登录或重置密码。';
    }
    if (lower.contains('rate') && lower.contains('limit')) {
      return '操作过于频繁，请稍后再试。';
    }
    if (lower.contains('network') || lower.contains('timeout')) {
      return '网络异常，请检查网络后重试。';
    }
    return '注册失败，请稍后再试。';
  }

  String friendlyActionError(Object e, {required String action}) {
    final code = _supabaseCode(e);
    if (code != null) {
      switch (code) {
        case 'user_not_found':
          return '邮箱未注册，无法$action。';
        case 'over_email_send_rate_limit':
          return '操作过于频繁，请稍后再试。';
        case 'email_address_not_confirmed':
        case 'email_not_confirmed':
          return '邮箱未验证，无法$action。';
      }
    }
    final lower = e.toString().toLowerCase();
    if (lower.contains('email') &&
        lower.contains('not') &&
        lower.contains('confirm')) {
      return '邮箱未验证，无法$action。';
    }
    if (lower.contains('rate') && lower.contains('limit')) {
      return '操作过于频繁，请稍后再试。';
    }
    if (lower.contains('network') || lower.contains('timeout')) {
      return '网络异常，请检查网络后重试。';
    }
    return '$action失败，请稍后再试。';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(title: isSignup ? '注册' : '登录', showBack: true),
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
                          color: Colors.black.withOpacity(0.04),
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
                              label: const Text('登录'),
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
                              label: const Text('注册'),
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
                          decoration: const InputDecoration(labelText: '邮箱'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: pwdCtrl,
                          obscureText: !_showPwd,
                          decoration: InputDecoration(
                            labelText: isSignup ? '密码（至少 6 位，需包含字母和数字）' : '密码',
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
                              labelText: '确认密码',
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
                                                () => errorText = '请输入有效的邮箱地址');
                                            return;
                                          }
                                          if (!isValidPassword(pwd)) {
                                            setState(() => errorText =
                                                '密码需包含字母和数字，长度至少 6 位');
                                            return;
                                          }
                                          if (pwd != pwd2) {
                                            setState(
                                                () => errorText = '两次输入的密码不一致');
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
                                            if (!mounted) return;
                                            logI('auth',
                                                '注册成功，已发送验证邮件：邮箱=$email');
                                            Navigator.of(context)
                                                .pushReplacement(
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const SignupSuccessPage()),
                                            );
                                          } catch (e, stSignup) {
                                            logE(
                                                'auth',
                                                '注册失败：邮箱=$email，原因=${friendlySignupError(e)}',
                                                e,
                                                stSignup);
                                            setState(() => errorText =
                                                friendlySignupError(e));
                                          } finally {
                                            if (mounted)
                                              setState(() => busy = false);
                                          }
                                        },
                                  child: busy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Text('注册'),
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
                                                () => errorText = '请输入有效的邮箱地址');
                                            return;
                                          }
                                          if (!isValidPassword(pwd)) {
                                            setState(() => errorText =
                                                '密码需包含字母和数字，长度至少 6 位');
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
                                            if (!mounted) return;
                                            logI('auth', '登录成功：邮箱=$email');
                                            ref
                                                .read(syncStatusRefreshProvider
                                                    .notifier)
                                                .state++;
                                            // 登录后检查是否需要恢复
                                            final check = await RestoreService
                                                .checkNeedRestore(ref);
                                            if (check.needsRestore) {
                                              final ok = await AppDialog.confirm<
                                                          bool>(context,
                                                      title: '发现云端备份',
                                                      message:
                                                          '检测到云端与本地账本不一致，是否恢复到本地？\n(将后台执行并显示进度)') ??
                                                  false;
                                              if (ok) {
                                                Future(() async {
                                                  await RestoreService
                                                      .startBackgroundRestore(
                                                          check.backups, ref);
                                                });
                                              }
                                            }
                                            Navigator.pop(context);
                                          } catch (e, st) {
                                            final msg = friendlyAuthError(e);
                                            logE(
                                                'auth',
                                                '登录失败：邮箱=$email，原因=$msg',
                                                e,
                                                st);
                                            setState(() => errorText = msg);
                                          } finally {
                                            if (mounted)
                                              setState(() => busy = false);
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
                                      : const Text('登录'),
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
                                            () => errorText = '请输入有效的邮箱地址');
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
                                        if (!mounted) return;
                                        showToast(context, '验证邮件已重新发送。');
                                        setState(() => infoText = '验证邮件已重新发送。');
                                      } catch (e) {
                                        final msg = friendlyActionError(e,
                                            action: '重发验证');
                                        if (!mounted) return;
                                        showToast(context, msg);
                                        setState(() => errorText = msg);
                                      } finally {
                                        if (mounted)
                                          setState(() => busy = false);
                                      }
                                    },
                              child: const Text('重发验证邮件'),
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
          const PrimaryHeader(title: '注册成功', showBack: false),
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
                    const Text('验证邮件已发送，请前往邮箱完成验证后再登录。'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      child: const Text('返回我的页面'),
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
