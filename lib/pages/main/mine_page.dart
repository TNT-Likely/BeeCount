import '../../presentation/v4/bindings/mine_profile.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../providers/theme_providers.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;
import '../../cloud/sync_service.dart';
import '../cloud/cloud_service_page.dart';
import '../../services/system/logger_service.dart';
import '../settings/help_center_page.dart';
import '../../services/export/share_poster_service.dart';
import '../../l10n/app_localizations.dart';
import '../cloud/cloud_sync_page.dart';
import '../cloud/beecount_cloud_sync_page.dart';
import '../../utils/website_urls.dart';
import '../../providers/github_star_provider.dart';
import '../settings/data_management_page.dart';
import '../settings/appearance_settings_page.dart';
import '../settings/smart_billing_page.dart';
import '../settings/automation_page.dart';
import '../settings/about_page.dart';
import '../report/annual_report_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_review/in_app_review.dart';
import '../../utils/ui_scale_extensions.dart';
import '../donation/donation_page.dart';

class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authServiceProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context), // ⭐ 使用 Token
      body: Column(
        children: [
          PrimaryHeader(
            showBack: false,
            title: AppLocalizations.of(context).mineTitle,
            compact: true,
            showTitleSection: true,
            content: MineProfileBinding(),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                BeeTokens.cardDivider(context, indent: 0),
                SizedBox(height: 8.0.scaled(context, ref)),
                // 云同步与备份
                Consumer(builder: (sectionContext, sectionRef, _) {
                  final activeCfg = sectionRef.watch(activeCloudConfigProvider);

                  return SectionCard(
                    margin: EdgeInsets.fromLTRB(
                        12.0.scaled(sectionContext, sectionRef),
                        0,
                        12.0.scaled(sectionContext, sectionRef),
                        0),
                    child: Column(
                      children: [
                        // 云服务 —— BeeCount Cloud 模式下 subtitle 带上
                        // server 版本号(从 fetchServerVersion 拉的 FutureProvider),
                        // 一眼看到 cloud 哪版。其它模式没版本概念,保留原文案。
                        Consumer(builder: (ctx, r, _) {
                          final cloudVersion = r
                              .watch(beecountCloudServerVersionProvider)
                              .valueOrNull;
                          return AppListTile(
                            leading: Icons.cloud_queue_outlined,
                            title: AppLocalizations.of(sectionContext)
                                .mineCloudService,
                            subtitle: activeCfg.when(
                              loading: () => AppLocalizations.of(sectionContext)
                                  .mineCloudServiceLoading,
                              error: (e, _) =>
                                  '${AppLocalizations.of(sectionContext).commonError}: $e',
                              data: (cfg) {
                                switch (cfg.type) {
                                  case CloudBackendType.local:
                                    return AppLocalizations.of(sectionContext)
                                        .mineCloudServiceOffline;
                                  case CloudBackendType.webdav:
                                    return AppLocalizations.of(sectionContext)
                                        .mineCloudServiceWebDAV;
                                  case CloudBackendType.icloud:
                                    return 'iCloud';
                                  case CloudBackendType.supabase:
                                    return AppLocalizations.of(sectionContext)
                                        .mineCloudServiceCustom;
                                  case CloudBackendType.s3:
                                    return 'S3';
                                  case CloudBackendType.beecountCloud:
                                    return cloudVersion != null &&
                                            cloudVersion.isNotEmpty
                                        ? 'BeeCount Cloud v$cloudVersion'
                                        : 'BeeCount Cloud';
                                }
                              },
                            ),
                            onTap: () async {
                              await Navigator.of(sectionContext).push(
                                MaterialPageRoute(
                                    builder: (_) => const CloudServicePage()),
                              );
                            },
                          );
                        }),
                        // 同步状态
                        Builder(
                          builder: (ctx) {
                            return authAsync.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.all(16.0),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              ),
                              error: (e, _) => Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  '${AppLocalizations.of(sectionContext).commonError}: $e',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                              data: (auth) => FutureBuilder<CloudUser?>(
                                future: auth.currentUser,
                                builder: (ctx, snap) {
                                  if (snap.hasError) {
                                    return Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        '${AppLocalizations.of(sectionContext).commonError}: ${snap.error}',
                                        style:
                                            const TextStyle(color: Colors.red),
                                      ),
                                    );
                                  }

                                  final user = snap.data;
                                  final cloudConfig = sectionRef
                                      .watch(activeCloudConfigProvider);
                                  final isLocalMode = cloudConfig.hasValue &&
                                      cloudConfig.value!.type ==
                                          CloudBackendType.local;
                                  final isICloudMode = cloudConfig.hasValue &&
                                      cloudConfig.value!.type ==
                                          CloudBackendType.icloud;
                                  // iCloud 使用系统账号，不需要登录；其他云服务需要登录
                                  final canUseCloud = !isLocalMode &&
                                      (isICloudMode || user != null);
                                  final asyncSt = sectionRef
                                      .watch(syncStatusProvider(ledgerId));
                                  final cached = sectionRef
                                      .watch(lastSyncStatusProvider(ledgerId));
                                  final st = asyncSt.asData?.value ?? cached;

                                  // 计算简化的同步状态显示
                                  String subtitle = '';
                                  bool showCheckIcon = false;
                                  final isFirstLoad = st == null;
                                  final refreshing = asyncSt.isLoading;

                                  if (!isFirstLoad) {
                                    switch (st.diff) {
                                      case SyncDiff.notLoggedIn:
                                        subtitle =
                                            AppLocalizations.of(sectionContext)
                                                .mineSyncNotLoggedIn;
                                        break;
                                      case SyncDiff.notConfigured:
                                        subtitle =
                                            AppLocalizations.of(sectionContext)
                                                .mineSyncNotConfigured;
                                        break;
                                      case SyncDiff.noRemote:
                                        subtitle =
                                            AppLocalizations.of(sectionContext)
                                                .mineSyncNoRemote;
                                        break;
                                      case SyncDiff.inSync:
                                        subtitle =
                                            AppLocalizations.of(sectionContext)
                                                .mineSyncInSyncSimple;
                                        showCheckIcon = true;
                                        break;
                                      case SyncDiff.localNewer:
                                        subtitle =
                                            AppLocalizations.of(sectionContext)
                                                .mineSyncLocalNewerSimple;
                                        break;
                                      case SyncDiff.cloudNewer:
                                        subtitle =
                                            AppLocalizations.of(sectionContext)
                                                .mineSyncCloudNewerSimple;
                                        break;
                                      case SyncDiff.different:
                                        subtitle =
                                            AppLocalizations.of(sectionContext)
                                                .mineSyncDifferent;
                                        break;
                                      case SyncDiff.error:
                                        subtitle =
                                            AppLocalizations.of(sectionContext)
                                                .mineSyncError;
                                        break;
                                    }
                                  }

                                  return Column(
                                    children: [
                                      BeeTokens.cardDivider(sectionContext),
                                      AppListTile(
                                        leading: Icons.cloud_sync_outlined,
                                        title:
                                            AppLocalizations.of(sectionContext)
                                                .mineSyncTitle,
                                        subtitle: isFirstLoad ? null : subtitle,
                                        enabled: !isLocalMode,
                                        trailing: (canUseCloud &&
                                                (isFirstLoad || refreshing))
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2))
                                            : showCheckIcon
                                                ? Icon(Icons.check_circle,
                                                    color: sectionRef.watch(
                                                        primaryColorProvider),
                                                    size: 20)
                                                : Icon(Icons.chevron_right,
                                                    color: BeeTokens.iconTertiary(
                                                        context), // ⭐ 使用 Token
                                                    size: 20),
                                        onTap: () async {
                                          // BeeCount Cloud 专属页跟老的
                                          // iCloud/WebDAV/Supabase 页语义完全不同,
                                          // 路由按 config.type 分叉,避免 UI 里
                                          // 大段 if-else 分支。
                                          final cfg = ref
                                              .read(activeCloudConfigProvider)
                                              .valueOrNull;
                                          final isBeeCount = cfg != null &&
                                              cfg.type ==
                                                  CloudBackendType
                                                      .beecountCloud;
                                          await Navigator.of(sectionContext)
                                              .push(
                                            MaterialPageRoute(
                                                builder: (_) => isBeeCount
                                                    ? const BeeCountCloudSyncPage()
                                                    : const CloudSyncPage()),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
                // 功能管理
                SizedBox(height: 8.0.scaled(context, ref)),
                SectionCard(
                  margin: EdgeInsets.fromLTRB(12.0.scaled(context, ref), 0,
                      12.0.scaled(context, ref), 0),
                  child: Column(
                    children: [
                      // 智能记账(共享账本入口已移到"账本管理"页 PrimaryHeader)
                      AppListTile(
                        leading: Icons.auto_awesome_outlined,
                        title: AppLocalizations.of(context).smartBilling,
                        subtitle: AppLocalizations.of(context).smartBillingDesc,
                        trailing: Icon(Icons.chevron_right,
                            color: BeeTokens.iconTertiary(context),
                            size: 20), // ⭐ 使用 Token
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SmartBillingPage()),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 数据管理
                      AppListTile(
                        leading: Icons.storage_outlined,
                        title: AppLocalizations.of(context).dataManagement,
                        subtitle:
                            AppLocalizations.of(context).dataManagementDesc,
                        trailing: Icon(Icons.chevron_right,
                            color: BeeTokens.iconTertiary(context),
                            size: 20), // ⭐ 使用 Token
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const DataManagementPage()),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 预算管理 已挪到「账本管理 → 长按某账本 → 预算管理」
                      // (每个账本独立预算,放在账本菜单内语义更匹配)。
                      // 自动化功能
                      AppListTile(
                        leading: Icons.schedule_outlined,
                        title: AppLocalizations.of(context).automation,
                        subtitle: AppLocalizations.of(context).automationDesc,
                        trailing: Icon(Icons.chevron_right,
                            color: BeeTokens.iconTertiary(context),
                            size: 20), // ⭐ 使用 Token
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AutomationPage()),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 外观设置
                      AppListTile(
                        leading: Icons.palette_outlined,
                        // 新功能红点的中间一级:这一行亮是为了把用户往外观
                        // 设置里引(终点是皮肤页)。见 FeatureHighlight。
                        dotAnchor: 'personalize',
                        title: AppLocalizations.of(context).appearanceSettings,
                        subtitle:
                            AppLocalizations.of(context).appearanceSettingsDesc,
                        trailing: Icon(Icons.chevron_right,
                            color: BeeTokens.iconTertiary(context),
                            size: 20), // ⭐ 使用 Token
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AppearanceSettingsPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // 帮助与信息
                SizedBox(height: 8.0.scaled(context, ref)),
                SectionCard(
                  margin: EdgeInsets.fromLTRB(12.0.scaled(context, ref), 0,
                      12.0.scaled(context, ref), 0),
                  child: Column(
                    children: [
                      AppListTile(
                        leading: Icons.info_outline,
                        title: AppLocalizations.of(context).about,
                        subtitle: AppLocalizations.of(context).aboutDesc,
                        trailing: Icon(Icons.chevron_right,
                            color: BeeTokens.iconTertiary(context), size: 20),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AboutPage()),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 使用帮助:默认 App 内嵌 WebView(embed 模式)。
                      // 审核兜底:kHelpCenterInApp 改 false 重新打包即回退外部浏览器
                      AppListTile(
                        leading: Icons.help_outline,
                        title: AppLocalizations.of(context).mineHelp,
                        subtitle: AppLocalizations.of(context).mineHelpSubtitle,
                        onTap: () async {
                          if (kHelpCenterInApp) {
                            await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const HelpCenterPage()));
                          } else {
                            final locale = Localizations.localeOf(context);
                            await _tryOpenUrl(
                                Uri.parse(WebsiteUrls.docs(locale)));
                          }
                        },
                      ),
                    ],
                  ),
                ),
                // 支持我们
                SizedBox(height: 8.0.scaled(context, ref)),
                SectionCard(
                  margin: EdgeInsets.fromLTRB(12.0.scaled(context, ref), 0,
                      12.0.scaled(context, ref), 0),
                  child: Column(
                    children: [
                      // 仅在iOS显示打赏入口
                      if (Platform.isIOS) ...[
                        Consumer(
                          builder: (context, ref, _) {
                            final primaryColor =
                                ref.watch(primaryColorProvider);
                            return AppListTile(
                              leading: Icons.favorite,
                              leadingWidget: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.favorite_border,
                                  color: primaryColor,
                                ),
                              ),
                              title: AppLocalizations.of(context).donationTitle,
                              subtitle: AppLocalizations.of(context)
                                  .donationEntrySubtitle,
                              trailing: Icon(Icons.chevron_right,
                                  color: BeeTokens.iconTertiary(context),
                                  size: 20),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const DonationPage()),
                                );
                              },
                            );
                          },
                        ),
                        BeeTokens.cardDivider(context),
                      ],
                      // GitHub Star
                      Consumer(
                        builder: (context, ref, _) {
                          final starCountAsync =
                              ref.watch(githubStarCountProvider);
                          final starCount = starCountAsync.valueOrNull ??
                              githubStarFallbackCount;
                          return AppListTile(
                            leading: Icons.star_outline,
                            title:
                                AppLocalizations.of(context).mineSupportAuthor,
                            subtitle: AppLocalizations.of(context)
                                .mineSupportAuthorSubtitle(
                                    starCount.toString()),
                            onTap: () => _showGitHubStarGuide(context),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 年度账单
                      AppListTile(
                        leading: Icons.auto_graph_rounded,
                        title: AppLocalizations.of(context).annualReportTitle,
                        subtitle: AppLocalizations.of(context)
                            .annualReportEntrySubtitle,
                        trailing: Icon(Icons.chevron_right,
                            color: BeeTokens.iconTertiary(context), size: 20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AnnualReportPage()),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 分享海报
                      AppListTile(
                        leading: Icons.ios_share_rounded,
                        title: AppLocalizations.of(context).mineShareApp,
                        subtitle:
                            AppLocalizations.of(context).mineShareWithFriends,
                        trailing: Icon(Icons.chevron_right,
                            color: BeeTokens.iconTertiary(context), size: 20),
                        onTap: () {
                          // 打开海报轮播预览对话框（支持年度、月度、总览3种海报）
                          SharePosterService.showPosterCarouselPreview(context);
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 复制推广文案
                      AppListTile(
                        leading: Icons.content_copy_rounded,
                        title: AppLocalizations.of(context).mineCopyPromoText,
                        subtitle:
                            AppLocalizations.of(context).mineCopyPromoSubtitle,
                        onTap: () async {
                          final l10n = AppLocalizations.of(context);
                          await Clipboard.setData(
                            ClipboardData(text: l10n.shareGuidanceCopyText),
                          );
                          if (context.mounted) {
                            showToast(context, l10n.shareGuidanceCopied);
                          }
                        },
                      ),
                      // 只在iOS上显示评分入口（Android还未上架）
                      if (Platform.isIOS) ...[
                        BeeTokens.cardDivider(context),
                        AppListTile(
                          leading: Icons.star_border_rounded,
                          title: AppLocalizations.of(context).mineRateApp,
                          subtitle:
                              AppLocalizations.of(context).mineRateAppSubtitle,
                          onTap: () => _rateApp(context),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: BeeDimens.p16.scaled(context, ref)),
                // 底部留白，避免被悬浮 Tab 栏遮挡
                SizedBox(
                    height: 56 +
                        12 +
                        MediaQuery.of(context).viewPadding.bottom +
                        16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _tryOpenUrl(Uri url) async {
  try {
    // 方式1: 默认外部应用打开
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return true;
    }

    // 方式2: 浏览器内打开
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
      return true;
    }

    // 方式3: 平台默认方式
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
      return true;
    }

    logger.error('MinePage', '无法打开URL: $url');
    return false;
  } catch (e) {
    logger.error('MinePage', '打开URL失败: $url', e);
    return false;
  }
}

/// 显示 GitHub Star 引导弹窗
void _showGitHubStarGuide(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final screenHeight = MediaQuery.of(context).size.height;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.githubStarGuideTitle),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.5,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.githubStarGuideContent,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              // 引导图片
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/github_star_guide.png',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _tryOpenUrl(Uri.parse('https://github.com/TNT-Likely/BeeCount'));
          },
          child: Text(l10n.githubStarGuideButton),
        ),
      ],
    ),
  );
}

/// 请求应用评分
///
/// iOS系统对原生评分弹窗有限制：
/// 1. 每365天最多弹出3次
/// 2. 模拟器上不显示
/// 3. 用户可在系统设置中禁用
///
/// 因此直接打开App Store评分页面更可靠
Future<void> _rateApp(BuildContext context) async {
  try {
    final InAppReview inAppReview = InAppReview.instance;

    // 直接打开应用商店评分页面（更可靠，不受系统限制）
    if (Platform.isIOS) {
      await inAppReview.openStoreListing(
        appStoreId: '6754611670', // BeeCount的App Store ID
      );
      logger.info('MinePage', '已打开App Store评分页面');
    } else {
      // Android会自动打开Google Play（如果已上架）
      await inAppReview.openStoreListing();
      logger.info('MinePage', '已打开Google Play评分页面');
    }
  } catch (e) {
    logger.error('MinePage', '打开评分失败', e);
    // 失败时不显示错误提示，静默失败
  }
}

/// 昵称编辑弹窗。独立 StatefulWidget 自己持有 controller、在 dispose() 释放,
/// 把 controller 的生命周期绑到弹窗本身 —— 弹窗(含 TextField)整棵子树卸载后
/// 才释放,彻底规避调用方在退场动画期间提前 dispose 造成的 "used after disposed"。
