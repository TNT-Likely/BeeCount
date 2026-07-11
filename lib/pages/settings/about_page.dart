import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
const _isGooglePlayBuild =
    bool.fromEnvironment('GOOGLE_PLAY', defaultValue: false);

/// 关于页面
class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
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
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    final locale = Localizations.localeOf(context);
    final isSimplifiedZh =
        locale.languageCode == 'zh' && locale.countryCode != 'TW';
    // Telegram 群面向国际用户;简体中文(大陆)访问 Telegram 受限,故仅非简体中文显示。
    final showTelegram = !isSimplifiedZh;

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.aboutPageTitle,
            subtitle: l10n.aboutPageSubtitle,
            showBack: true,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16.0.scaled(context, ref),
                  8.0.scaled(context, ref),
                  16.0.scaled(context, ref),
                  16.0.scaled(context, ref),
                ),
                children: [
                  // ===== 顶部:图标 + 应用名 + 版本号(与原版一致)=====
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 24.0.scaled(context, ref),
                    ),
                    child: Column(
                      children: [
                        BeeIcon(
                          color: primary,
                          size: 80.0.scaled(context, ref),
                        ),
                        SizedBox(height: 16.0.scaled(context, ref)),
                        GestureDetector(
                          onTap: () => _showDeveloperStory(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.appName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
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
                              ? l10n.aboutPageLoadingVersion
                              : _versionDisplay,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: BeeTokens.textSecondary(context),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // ===== 圆形图标按钮行(真实品牌 logo)=====
                  Padding(
                    padding: EdgeInsets.only(bottom: 20.0.scaled(context, ref)),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 22.0.scaled(context, ref),
                      runSpacing: 14.0.scaled(context, ref),
                      children: [
                        _socialButton(
                          context,
                          icon: Icons.language_rounded,
                          label: l10n.aboutWebsite,
                          onTap: () =>
                              _tryOpenUrl(Uri.parse(WebsiteUrls.home(locale))),
                        ),
                        _socialButton(
                          context,
                          svgAsset: 'assets/icons/social/github.svg',
                          label: 'GitHub',
                          onTap: () => _tryOpenUrl(Uri.parse(
                              'https://github.com/TNT-Likely/BeeCount')),
                        ),
                        if (showTelegram)
                          _socialButton(
                            context,
                            svgAsset: 'assets/icons/social/telegram.svg',
                            label: l10n.aboutTelegram,
                            onTap: () =>
                                _tryOpenUrl(Uri.parse('https://t.me/beecount')),
                          ),
                        _socialButton(
                          context,
                          svgAsset: 'assets/icons/social/xiaohongshu.svg',
                          label: l10n.aboutXiaohongshu,
                          onTap: () => _tryOpenUrl(
                              Uri.parse('https://xhslink.com/m/8K1ekg7EFOq')),
                        ),
                        _socialButton(
                          context,
                          svgAsset: 'assets/icons/social/douyin.svg',
                          label: l10n.aboutDouyin,
                          onTap: () => _tryOpenUrl(
                              Uri.parse('https://v.douyin.com/YG7tUweYYyQ/')),
                        ),
                      ],
                    ),
                  ),
                  // ===== 功能卡 =====
                  SectionCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        // iOS 与 Google Play 版本隐藏检查更新(走应用商店分发)
                        if (!Platform.isIOS && !_isGooglePlayBuild) ...[
                          Consumer(builder: (context, ref2, child) {
                            final isLoading =
                                ref2.watch(checkUpdateLoadingProvider);
                            final downloadProgress =
                                ref2.watch(updateProgressProvider);

                            bool showProgress = false;
                            String title = l10n.mineCheckUpdate;
                            String? subtitle;
                            IconData icon = Icons.system_update_alt_outlined;
                            Widget? trailing;

                            if (isLoading) {
                              title = l10n.mineCheckUpdateDetecting;
                              subtitle = l10n.mineCheckUpdateSubtitleDetecting;
                              icon = Icons.hourglass_empty;
                              trailing = const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2));
                            } else if (downloadProgress.isActive) {
                              showProgress = true;
                              title = l10n.mineUpdateDownloadTitle;
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
                                  subtitle: showProgress
                                      ? downloadProgress.status
                                      : subtitle,
                                  trailing: trailing,
                                  onTap: (isLoading || showProgress)
                                      ? null
                                      : () async {
                                          await UpdateService.checkUpdateWithUI(
                                            context,
                                            setLoading: (loading) => ref2
                                                .read(checkUpdateLoadingProvider
                                                    .notifier)
                                                .state = loading,
                                            setProgress: (progress, status) {
                                              if (status.isEmpty) {
                                                ref2
                                                        .read(
                                                            updateProgressProvider
                                                                .notifier)
                                                        .state =
                                                    UpdateProgress.idle();
                                              } else {
                                                ref2
                                                        .read(
                                                            updateProgressProvider
                                                                .notifier)
                                                        .state =
                                                    UpdateProgress.active(
                                                        progress, status);
                                              }
                                            },
                                          );
                                        },
                                ),
                                BeeTokens.cardDivider(context),
                              ],
                            );
                          }),
                        ],
                        AppListTile(
                          leading: Icons.favorite_border,
                          title: l10n.aboutSupportDevelopment,
                          subtitle: l10n.aboutSupportDevelopmentSubtitle,
                          onTap: () async {
                            final lc = locale.languageCode;
                            final docUrl = lc == 'zh'
                                ? 'https://github.com/TNT-Likely/BeeCount/blob/main/docs/donate/README_ZH.md'
                                : 'https://github.com/TNT-Likely/BeeCount/blob/main/docs/donate/README_EN.md';
                            await _tryOpenUrl(Uri.parse(docUrl));
                          },
                        ),
                        BeeTokens.cardDivider(context),
                        AppListTile(
                          leading: Icons.feedback_outlined,
                          title: l10n.mineFeedback,
                          subtitle: l10n.mineFeedbackSubtitle,
                          onTap: () => _tryOpenUrl(Uri.parse(
                              'https://github.com/TNT-Likely/BeeCount/issues')),
                        ),
                        BeeTokens.cardDivider(context),
                        AppListTile(
                          leading: Icons.bug_report_outlined,
                          title: l10n.logCenterTitle,
                          subtitle: l10n.logCenterSubtitle,
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
                  // ===== 相关产品 =====
                  SizedBox(height: 28.0.scaled(context, ref)),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      l10n.aboutRelatedProducts,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: BeeTokens.textSecondary(context),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  _buildProductPromos(context),
                  // ===== 底部:隐私政策文字链接 + 备案号 =====
                  SizedBox(height: 24.0.scaled(context, ref)),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyPage()),
                        );
                      },
                      child: Text(
                        l10n.aboutPrivacyPolicy,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: primary,
                              decoration: TextDecoration.underline,
                              decorationColor: primary,
                            ),
                      ),
                    ),
                  ),
                  if (isSimplifiedZh) ...[
                    SizedBox(height: 12.0.scaled(context, ref)),
                    Center(
                      child: Text(
                        '浙ICP备2025214907号-2A',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: BeeTokens.textTertiary(context),
                              fontSize: 11,
                            ),
                      ),
                    ),
                  ],
                  SizedBox(height: 8.0.scaled(context, ref)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 圆形图标社媒按钮 — 传 [svgAsset](品牌 logo)或 [icon](通用图标)之一。
  /// 图标统一用主题色(logo 形状本身已能辨识平台),和 app 整体视觉呼应。
  Widget _socialButton(
    BuildContext context, {
    String? svgAsset,
    IconData? icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final tint = ref.watch(primaryColorProvider);
    final size = 46.0.scaled(context, ref);
    final glyph = 22.0.scaled(context, ref);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: svgAsset != null
                ? SvgPicture.asset(
                    svgAsset,
                    width: glyph,
                    height: glyph,
                    colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
                  )
                : Icon(icon, color: tint, size: glyph),
          ),
          SizedBox(height: 6.0.scaled(context, ref)),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5.scaled(context, ref),
              color: BeeTokens.textTertiary(context),
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
