import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as s;
import '../../providers.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;
import '../../widgets/ui/ui.dart';
import '../../styles/tokens.dart';
import '../../services/system/logger_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/website_urls.dart';
import '../settings/help_center_page.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  String? errorText;
  bool busy = false;
  bool _showPwd = false;
  bool _rememberAccount = false;

  @override
  void initState() {
    super.initState();
    // 延迟加载凭证，确保 provider 已初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedCredentials();
    });
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final cloudConfig = await ref.read(activeCloudConfigProvider.future);
      String? savedEmail;
      String? savedPassword;
      if (cloudConfig.type == CloudBackendType.supabase) {
        savedEmail = cloudConfig.supabaseEmail;
        savedPassword = cloudConfig.supabasePassword;
      } else if (cloudConfig.type == CloudBackendType.beecountCloud) {
        // BeeCount Cloud：跟 Supabase 一样，勾选"记住账号"时同时存邮箱+密码，
        // 作为 token 失效时的兜底登录途径（见 beecountCloudProviderInstance
        // 里的 fallback signInWithEmail）。
        savedEmail = cloudConfig.beecountCloudEmail;
        savedPassword = cloudConfig.beecountCloudPassword;
      } else {
        return;
      }

      if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
        setState(() {
          emailCtrl.text = savedEmail!;
          if (savedPassword != null && savedPassword.isNotEmpty) {
            pwdCtrl.text = savedPassword;
            _rememberAccount = true;
          }
        });
      }
    } catch (e) {
      logger.warning('auth', '加载保存的账号密码失败: $e');
    }
  }

  Future<void> _saveCredentials(String email, String password) async {
    try {
      final cloudConfig = await ref.read(activeCloudConfigProvider.future);
      final store = ref.read(cloudServiceStoreProvider);

      if (cloudConfig.type == CloudBackendType.supabase) {
        // Supabase 仍旧保留"记住账号"时同时存密码（老 SDK 没有 refresh token 持久化）。
        final updatedConfig = CloudServiceConfig(
          type: cloudConfig.type,
          name: cloudConfig.name,
          supabaseUrl: cloudConfig.supabaseUrl,
          supabaseAnonKey: cloudConfig.supabaseAnonKey,
          supabaseBucket: cloudConfig.supabaseBucket ?? 'beecount-backups',
          supabaseEmail: _rememberAccount ? email : null,
          supabasePassword: _rememberAccount ? password : null,
        );
        await store.saveOnly(updatedConfig);
        ref.invalidate(supabaseConfigProvider);
        ref.invalidate(activeCloudConfigProvider);
        logger.info('auth', 'Supabase 账号密码保存状态：${_rememberAccount ? "已保存" : "已清除"}');
        return;
      }

      if (cloudConfig.type == CloudBackendType.beecountCloud) {
        // BeeCount Cloud：勾选"记住账号"时存邮箱+密码 —— token 机制平时够用，
        // 但 token 失效 / 老版本升级 / 本地 SharedPreferences 被清等场景都靠
        // 这份密码做兜底自动登录。
        final updatedConfig = CloudServiceConfig(
          type: cloudConfig.type,
          name: cloudConfig.name,
          beecountCloudBaseUrl: cloudConfig.beecountCloudBaseUrl,
          beecountCloudApiPrefix: cloudConfig.beecountCloudApiPrefix,
          beecountCloudEmail: _rememberAccount ? email : null,
          beecountCloudPassword: _rememberAccount ? password : null,
        );
        await store.saveOnly(updatedConfig);
        ref.invalidate(beecountCloudConfigProvider);
        ref.invalidate(activeCloudConfigProvider);
        logger.info('auth',
            'BeeCount Cloud 账号密码保存状态：${_rememberAccount ? "已保存" : "已清除"}');
      }
    } catch (e, st) {
      logger.error('auth', '保存账号密码失败', e, st);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    pwdCtrl.dispose();
    super.dispose();
  }

  bool isValidEmail(String s) {
    final t = s.trim();
    final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRe.hasMatch(t);
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

  /// 按当前云后端选注册指引文档的 topic:Supabase / BeeCount Cloud 各跳自己的
  /// 配置文档,其它(含加载中)兜底到云同步概览。
  static String _registerDocTopic(CloudBackendType? type) {
    switch (type) {
      case CloudBackendType.supabase:
        return 'supabase';
      case CloudBackendType.beecountCloud:
        return 'beecount-cloud';
      default:
        return 'overview';
    }
  }

  static String _hex(Color c) => [c.r, c.g, c.b]
      .map((v) => ((v * 255).round() & 0xff).toRadixString(16).padLeft(2, '0'))
      .join();

  /// 打开「注册指引」:按当前云后端拼 embed 文档 URL,复用帮助中心内嵌 WebView
  /// 打开(隐藏外链、跟随暗黑与主题色、域名白名单、离线兜底)。
  void _openRegisterGuide() {
    final type = ref.read(activeCloudConfigProvider).value?.type;
    final url = WebsiteUrls.docsCloudSyncEmbed(
      _registerDocTopic(type),
      Localizations.localeOf(context),
      dark: BeeTokens.isDark(context),
      primaryHex: _hex(ref.read(primaryColorProvider)),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HelpCenterPage(initialUrl: url)),
    );
  }

  // 恢复流程改为登录后回到“我的”页由其触发，不再在登录页内执行

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = ref.watch(primaryColorProvider);
    final radius = BorderRadius.circular(12);

    // 检测云服务类型
    final cloudConfig = ref.watch(activeCloudConfigProvider);
    if (cloudConfig.hasValue && cloudConfig.value!.type == CloudBackendType.webdav) {
      // WebDAV 不需要登录页面
      return Scaffold(
        backgroundColor: BeeTokens.scaffoldBackground(context),
        body: Column(
          children: [
            PrimaryHeader(title: AppLocalizations.of(context).authLogin, showBack: true),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: BeeTokens.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: BeeTokens.isDark(context) ? null : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          AppLocalizations.of(context).webdavConfiguredTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: BeeTokens.textPrimary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context).webdavConfiguredMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: BeeTokens.textSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(AppLocalizations.of(context).commonBack),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(title: AppLocalizations.of(context).authLogin, showBack: true),
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
                      color: BeeTokens.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: BeeTokens.isDark(context) ? null : [
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
                            labelText: AppLocalizations.of(context).authPassword,
                            suffixIcon: IconButton(
                              icon: Icon(_showPwd
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () =>
                                  setState(() => _showPwd = !_showPwd),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _rememberAccount = !_rememberAccount;
                            });
                          },
                          child: Row(
                            children: [
                              Checkbox(
                                value: _rememberAccount,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberAccount = value ?? false;
                                  });
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context).authRememberAccount,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: BeeTokens.textPrimary(context),
                                      ),
                                    ),
                                    Text(
                                      AppLocalizations.of(context).authRememberAccountHint,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: BeeTokens.textSecondary(context),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              errorText!,
                              style: TextStyle(color: BeeTokens.error(context)),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: radius),
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          final email = emailCtrl.text.trim();
                                          final pwd = pwdCtrl.text;
                                          logger.info('auth', '开始登录：邮箱=$email');
                                          if (!isValidEmail(email)) {
                                            setState(() => errorText =
                                                AppLocalizations.of(context)
                                                    .authInvalidEmail);
                                            return;
                                          }
                                          // 不再本地校验密码强度:密码规则由服务端决定,
                                          // App 不二次猜测(否则会把服务端能登录的合法
                                          // 密码挡在门外,见 issue #358)。
                                          setState(() {
                                            busy = true;
                                            errorText = null;
                                          });
                                          try {
                                            final auth = await ref.read(authServiceProvider.future);
                                            await auth.signInWithEmail(
                                                email: email, password: pwd);
                                            if (!context.mounted) return;
                                            logger.info('auth', '登录成功：邮箱=$email');

                                            // Save credentials if "remember account" is checked
                                            await _saveCredentials(email, pwd);

                                            // 刷新认证服务和同步服务以触发状态更新
                                            ref.invalidate(authServiceProvider);
                                            ref.invalidate(syncServiceProvider);

                                            // 刷新同步状态
                                            ref
                                                .read(syncStatusRefreshProvider
                                                    .notifier)
                                                .state++;
                                            // 直接切到"我的"页并关闭登录页
                                            ref
                                                .read(bottomTabIndexProvider
                                                    .notifier)
                                                .state = 3; // Mine tab index
                                            final can = Navigator.of(context)
                                                .canPop();
                                            logger.info('nav',
                                                'login: success -> switch tab to Mine, canPop=$can; pop login');
                                            if (can) {
                                              Navigator.of(context).pop();
                                            }
                                          } catch (e, st) {
                                            final msg = friendlyAuthError(e);
                                            final detailedMsg = 'Type: ${e.runtimeType}, Message: $e';
                                            logger.error(
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
                        const SizedBox(height: 16),
                        Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openRegisterGuide,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                    text: AppLocalizations.of(context)
                                        .authNoAccountYet,
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color: BeeTokens.textSecondary(context),
                                    ),
                                  ),
                                  TextSpan(
                                    text: AppLocalizations.of(context)
                                        .authViewRegisterGuide,
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color: primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ),
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

/// 对外暴露的就是 LoginPage —— 登录一件事。注册走不通(server 禁自助注册,
/// Supabase 官网注册 or 管理员后台加账号),内部也没有 SignupPage / VerifyPage。
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => const AuthPage();
}
