import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:beecount/widgets/biz/bee_icon.dart';

import '../../providers.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../services/system/update_service.dart';
import '../../services/system/logger_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../utils/website_urls.dart';
import '../../services/marketing/product_promos.dart';
import 'log_center_page.dart';
import 'privacy_policy_page.dart';

/// 是否为 Google Play 版本（通过 CI 构建时 --dart-define=GOOGLE_PLAY=true 注入）
const _isGooglePlayBuild = bool.fromEnvironment('GOOGLE_PLAY', defaultValue: false);

/// 关于页面
class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  String _version = '';
  String _versionDisplay = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await _getAppInfo();
    final versionText = info.version.startsWith('dev-')
        ? '${info.version} (${info.buildNumber})'
        : info.version;
    setState(() {
      _version = info.version;
      _versionDisplay = versionText;
    });
  }

  void _showDeveloperStory(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aboutDeveloperStoryTitle),
        content: SingleChildScrollView(
          child: Text(
            l10n.aboutDeveloperStory,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: BeeTokens.textSecondary(context),
                  height: 1.7,
                ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context).aboutPageTitle,
            subtitle: AppLocalizations.of(context).aboutPageSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 顶部：图标 + 应用名称 + 版本号
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 24.0.scaled(context, ref),
                  ),
                  child: Column(
                    children: [
                      BeeIcon(
                        color: Theme.of(context).colorScheme.primary,
                        size: 80.0.scaled(context, ref),
                      ),
                      SizedBox(height: 16.0.scaled(context, ref)),
                      GestureDetector(
                        onTap: () => _showDeveloperStory(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppLocalizations.of(context).appName,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: BeeTokens.textPrimary(context),
                                  ),
                            ),
                            SizedBox(width: 4.0.scaled(context, ref)),
                            Icon(
                              Icons.help_outline_rounded,
                              size: 18.0.scaled(context, ref),
                              color: BeeTokens.textTertiary(context),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8.0.scaled(context, ref)),
                      Text(
                        _versionDisplay.isEmpty
                            ? AppLocalizations.of(context).aboutPageLoadingVersion
                            : _versionDisplay,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: BeeTokens.textSecondary(context),
                            ),
                      ),
                    ],
                  ),
                ),
                // 联系方式
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      AppListTile(
                        leading: Icons.language_outlined,
                        title: AppLocalizations.of(context).aboutWebsite,
                        onTap: () async {
                          final locale = Localizations.localeOf(context);
                          final url = Uri.parse(WebsiteUrls.home(locale));
                          await _tryOpenUrl(url);
                        },
                      ),
                      const Divider(height: 1, thickness: 0.5),
                      AppListTile(
                        leading: Icons.privacy_tip_outlined,
                        title: AppLocalizations.of(context).aboutPrivacyPolicy,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyPage()),
                          );
                        },
                      ),
                      const Divider(height: 1, thickness: 0.5),
                      AppListTile(
                        leading: Icons.code_outlined,
                        title: AppLocalizations.of(context).aboutGitHubRepo,
                        subtitle: 'github.com/TNT-Likely/BeeCount',
                        onTap: () async {
                          final url = Uri.parse('https://github.com/TNT-Likely/BeeCount');
                          await _tryOpenUrl(url);
                        },
                      ),
                      // 小红书号（仅简体中文显示）
                      if (Localizations.localeOf(context).languageCode == 'zh') ...[
                        const Divider(height: 1, thickness: 0.5),
                        AppListTile(
                          leading: Icons.favorite_outline,
                          title: AppLocalizations.of(context).aboutXiaohongshu,
                          subtitle: '278979339',
                          onTap: () async {
                            final url = Uri.parse('https://xhslink.com/m/8K1ekg7EFOq');
                            await _tryOpenUrl(url);
                          },
                        ),
                        const Divider(height: 1, thickness: 0.5),
                        AppListTile(
                          leading: Icons.music_note_outlined,
                          title: AppLocalizations.of(context).aboutDouyin,
                          subtitle: '75639334477',
                          onTap: () async {
                            final url = Uri.parse('https://v.douyin.com/YG7tUweYYyQ/');
                            await _tryOpenUrl(url);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 8.0.scaled(context, ref)),
                // 功能
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // iOS 平台和 Google Play 版本隐藏检查更新功能（使用应用商店分发）
                      if (!Platform.isIOS && !_isGooglePlayBuild) ...[
                        Consumer(builder: (context, ref2, child) {
                          final isLoading = ref2.watch(checkUpdateLoadingProvider);
                          final downloadProgress = ref2.watch(updateProgressProvider);

                          // 确定显示状态
                          bool showProgress = false;
                          String title = AppLocalizations.of(context).mineCheckUpdate;
                          String? subtitle;
                          IconData icon = Icons.system_update_alt_outlined;
                          Widget? trailing;

                          if (isLoading) {
                            title = AppLocalizations.of(context).mineCheckUpdateDetecting;
                            subtitle =
                                AppLocalizations.of(context).mineCheckUpdateSubtitleDetecting;
                            icon = Icons.hourglass_empty;
                            trailing = const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2));
                          } else if (downloadProgress.isActive) {
                            showProgress = true;
                            title = AppLocalizations.of(context).mineUpdateDownloadTitle;
                            icon = Icons.download_outlined;
                            trailing = SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: downloadProgress.progress,
                                ));
                          }

                          return Column(
                            children: [
                              AppListTile(
                                leading: icon,
                                title: title,
                                subtitle: showProgress ? downloadProgress.status : subtitle,
                                trailing: trailing,
                                onTap: (isLoading || showProgress)
                                    ? null
                                    : () async {
                                        await UpdateService.checkUpdateWithUI(
                                          context,
                                          setLoading: (loading) => ref2
                                              .read(checkUpdateLoadingProvider.notifier)
                                              .state = loading,
                                          setProgress: (progress, status) {
                                            if (status.isEmpty) {
                                              ref2.read(updateProgressProvider.notifier).state =
                                                  UpdateProgress.idle();
                                            } else {
                                              ref2.read(updateProgressProvider.notifier).state =
                                                  UpdateProgress.active(progress, status);
                                            }
                                          },
                                        );
                                      },
                              ),
                              const Divider(height: 1, thickness: 0.5),
                            ],
                          );
                        }),
                      ],
                      AppListTile(
                        leading: Icons.favorite_border,
                        title: AppLocalizations.of(context).aboutSupportDevelopment,
                        subtitle: AppLocalizations.of(context).aboutSupportDevelopmentSubtitle,
                        onTap: () async {
                          final locale = Localizations.localeOf(context).languageCode;
                          final docUrl = locale == 'zh'
                            ? 'https://github.com/TNT-Likely/BeeCount/blob/main/docs/donate/README_ZH.md'
                            : 'https://github.com/TNT-Likely/BeeCount/blob/main/docs/donate/README_EN.md';
                          final url = Uri.parse(docUrl);
                          await _tryOpenUrl(url);
                        },
                      ),
                      const Divider(height: 1, thickness: 0.5),
                      AppListTile(
                        leading: Icons.feedback_outlined,
                        title: AppLocalizations.of(context).mineFeedback,
                        subtitle: AppLocalizations.of(context).mineFeedbackSubtitle,
                        onTap: () async {
                          final url = Uri.parse(
                              'https://github.com/TNT-Likely/BeeCount/issues');
                          await _tryOpenUrl(url);
                        },
                      ),
                      const Divider(height: 1, thickness: 0.5),
                      AppListTile(
                        leading: Icons.bug_report_outlined,
                        title: AppLocalizations.of(context).logCenterTitle,
                        subtitle: AppLocalizations.of(context).logCenterSubtitle,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LogCenterPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // 相关产品
                SizedBox(height: 32.0.scaled(context, ref)),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    AppLocalizations.of(context).aboutRelatedProducts,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: BeeTokens.textSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                // 更多产品 — 2 列 grid 紧凑卡(蜜蜂家当前置)。
                // 数据 + 文案在下方 _buildProductPromos() 里集中维护,
                // 加新产品只要往那个 list push 一项即可。
                _buildProductPromos(context),
                // ICP 备案号（仅简体中文显示）
                if (Localizations.localeOf(context).languageCode == 'zh' &&
                    Localizations.localeOf(context).countryCode != 'TW') ...[
                  SizedBox(height: 24.0.scaled(context, ref)),
                  Center(
                    child: Text(
                      '浙ICP备2025214907号-2A',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BeeTokens.textTertiary(context),
                            fontSize: 11,
                          ),
                    ),
                  ),
                  SizedBox(height: 16.0.scaled(context, ref)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 「更多产品」section — 单列大卡。蜜蜂家当前置。
///
/// ProductPromo 数据从 `lib/services/marketing/product_promos.dart` 集中获取,
/// 多处页面(关于页 / 资产管理页 banner)共用同一份产品信息。
Widget _buildProductPromos(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final products = <(ProductPromo info, ProductPromoTexts texts)>[
    (beeAssetsPromo(context), buildPromoTexts(context, l10n.aboutBeeAssets)),
    (beeDnsPromo(context), buildPromoTexts(context, l10n.aboutBeeDNS)),
  ];
  return Column(
    children: [
      for (var i = 0; i < products.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        ProductPromoCard(info: products[i].$1, texts: products[i].$2),
      ],
    ],
  );
}

// -------- 工具方法：关于与更新 --------
class _AppInfo {
  final String version;
  final String buildNumber;
  final String? commit;
  final String? buildTime;
  const _AppInfo(this.version, this.buildNumber, {this.commit, this.buildTime});
}

// 优先读取 CI 注入的 dart-define（CI_VERSION/GIT_COMMIT/BUILD_TIME），否则回退 PackageInfo
Future<_AppInfo> _getAppInfo() async {
  final p = await PackageInfo.fromPlatform();
  final commit = const String.fromEnvironment('GIT_COMMIT');
  final buildTime = const String.fromEnvironment('BUILD_TIME');
  final ciVersion = const String.fromEnvironment('CI_VERSION');

  // 版本号策略：CI版本优先，本地开发显示 "dev-{pubspec版本}"
  final version =
      ciVersion.isNotEmpty ? ciVersion : 'dev-${p.version}'; // 本地开发版本标识

  return _AppInfo(version, p.buildNumber,
      commit: commit.isEmpty ? null : commit,
      buildTime: buildTime.isEmpty ? null : buildTime);
}

// _BeeDNSCard 已抽到 lib/widgets/biz/product_promo_card.dart 通用化。
// 此处保留 _tryOpenUrl,因为本页其他链接(GitHub / Telegram / TestFlight 等)
// 还在用。

/// 尝试使用多种方式打开URL，提供更好的兼容性
Future<bool> _tryOpenUrl(Uri url) async {
  try {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return true;
    }
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
      return true;
    }
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
      return true;
    }
    logger.error('AboutPage', '无法打开URL: $url');
    return false;
  } catch (e) {
    logger.error('AboutPage', '打开URL失败: $url', e);
    return false;
  }
}
