import 'share_card_controls.dart';
import 'package:beecount_business_ui/support.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../pages/settings/help_center_page.dart';
import '../../../pages/settings/log_center_page.dart';
import '../../../pages/settings/privacy_policy_page.dart';
import '../../../services/marketing/product_promos.dart';
import '../../../utils/website_urls.dart';
import '../../../widgets/biz/bee_icon.dart';
import '../gallery/component_gallery_page.dart';
import 'support_frame.dart';
import 'support_platform.dart';

class SupportAboutControls extends ConsumerStatefulWidget {
  const SupportAboutControls({super.key});
  @override
  ConsumerState<SupportAboutControls> createState() =>
      _SupportAboutControlsState();
}

class _SupportAboutControlsState extends ConsumerState<SupportAboutControls> {
  String? version;
  bool versionFailed = false;
  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final value = await ref.read(supportPlatformProvider).version();
      if (mounted) setState(() => version = value);
    } catch (_) {
      if (mounted) setState(() => versionFailed = true);
    }
  }

  void _story() {
    final l = AppLocalizations.of(context);
    showDialog(
        context: context,
        builder: (context) => BeeDialog(
                title: Text(l.aboutDeveloperStoryTitle),
                content: SingleChildScrollView(
                    child: Text(l.aboutDeveloperStory,
                        style: TextStyle(
                            height: 1.7,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.commonConfirm))
                ]));
  }

  void _page(Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  String _hex(Color c) => [c.r, c.g, c.b]
      .map((v) => ((v * 255).round() & 0xff).toRadixString(16).padLeft(2, '0'))
      .join();
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        locale = Localizations.localeOf(context),
        platform = ref.watch(supportPlatformProvider),
        primary = ref.watch(primaryColorProvider);
    final simplified =
        locale.languageCode == 'zh' && locale.countryCode != 'TW';
    Future<bool> open(String url) => platform.open(Uri.parse(url));
    BeeSupportAction social(String name, String id, String url,
            {String? asset, String icon = 'Globe'}) =>
        BeeSupportAction(
            key: ValueKey('support-social-$id'),
            title: name,
            leading: asset == null
                ? BeeLineIcon(icon, size: 23, color: primary)
                : SvgPicture.asset(asset,
                    width: 23,
                    height: 23,
                    colorFilter: Theme.of(context).brightness ==
                                Brightness.dark &&
                            {'github', 'douyin'}.contains(id)
                        ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                        : null),
            onTap: () => open(url));
    final loading = ref.watch(checkUpdateLoadingProvider),
        progress = ref.watch(updateProgressProvider);
    final products = [
      (beeAssetsPromo(context), buildPromoTexts(context, l.aboutBeeAssets)),
      (beeDnsPromo(context), buildPromoTexts(context, l.aboutBeeDNS))
    ];
    return SupportFrame(
        title: l.aboutPageTitle,
        subtitle: l.aboutPageSubtitle,
        body: BeePageBody(eager: true, children: [
          BeeSupportBrand(
              logo: BeeIcon(color: primary, size: 80),
              title: l.appName,
              version: version ??
                  (versionFailed ? l.commonError : l.aboutPageLoadingVersion),
              onStory: _story,
              description: l.v4SharePosterOpenSourceBody,
              tag: '${l.appPromoTagOpenSource} · ${l.appPromoTagFree}',
              sourceLabel: l.v4SharePosterOpenSourceAction,
              recommendLabel: l.v4SharePosterRecommend,
              onSource: () => open('https://github.com/TNT-Likely/BeeCount'),
              onRecommend: () => showDialog<void>(
                  context: context,
                  builder: (_) => const ShareCardDialog(type: 'app')),
              socials: [
                social(l.aboutWebsite, 'website', WebsiteUrls.home(locale)),
                social('GitHub', 'github',
                    'https://github.com/TNT-Likely/BeeCount',
                    asset: 'assets/icons/social/github.svg'),
                if (!simplified)
                  social(l.aboutTelegram, 'telegram', 'https://t.me/beecount',
                      asset: 'assets/icons/social/telegram.svg'),
                social(l.aboutXiaohongshu, 'xiaohongshu',
                    'https://xhslink.com/m/8K1ekg7EFOq',
                    asset: 'assets/icons/social/xiaohongshu.svg'),
                social(l.aboutDouyin, 'douyin',
                    'https://v.douyin.com/YG7tUweYYyQ/',
                    asset: 'assets/icons/social/douyin.svg'),
              ]),
          BeeSupportActions(actions: [
            if (!platform.isIOS && !platform.isGooglePlay)
              BeeSupportAction(
                  key: const ValueKey('support-update'),
                  title: loading
                      ? l.mineCheckUpdateDetecting
                      : progress.isActive
                          ? l.mineUpdateDownloadTitle
                          : l.mineCheckUpdate,
                  subtitle: loading
                      ? l.mineCheckUpdateSubtitleDetecting
                      : progress.isActive
                          ? progress.status
                          : null,
                  leading: const BeeLineIcon('RefreshCw'),
                  trailing: loading || progress.isActive
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loading ? null : progress.progress))
                      : null,
                  onTap: loading || progress.isActive
                      ? null
                      : () async {
                          final container =
                              ProviderScope.containerOf(context, listen: false);
                          await platform.checkUpdate(context,
                              setLoading: (value) => container
                                  .read(checkUpdateLoadingProvider.notifier)
                                  .state = value,
                              setProgress: (value, status) => container
                                      .read(updateProgressProvider.notifier)
                                      .state =
                                  status.isEmpty
                                      ? UpdateProgress.idle()
                                      : UpdateProgress.active(value, status));
                        }),
            BeeSupportAction(
                key: const ValueKey('support-development'),
                title: l.aboutSupportDevelopment,
                subtitle: l.aboutSupportDevelopmentSubtitle,
                leading: const BeeLineIcon('Heart'),
                onTap: () => open(locale.languageCode == 'zh'
                    ? 'https://github.com/TNT-Likely/BeeCount/blob/main/docs/donate/README_ZH.md'
                    : 'https://github.com/TNT-Likely/BeeCount/blob/main/docs/donate/README_EN.md')),
            BeeSupportAction(
                key: const ValueKey('support-feedback'),
                title: l.mineFeedback,
                subtitle: l.mineFeedbackSubtitle,
                leading: const BeeLineIcon('MessageSquare'),
                onTap: () =>
                    open('https://github.com/TNT-Likely/BeeCount/issues')),
            BeeSupportAction(
                key: const ValueKey('support-logs'),
                title: l.logCenterTitle,
                subtitle: l.logCenterSubtitle,
                leading: const BeeLineIcon('Bug'),
                onTap: () => _page(const LogCenterPage())),
          ]),
          if (kDebugMode)
            BeeSupportActions(actions: [
              BeeSupportAction(
                  key: const ValueKey('support-gallery'),
                  title: 'V4 组件验收',
                  subtitle: '基础组件与业务组件 · 仅调试版',
                  leading: const BeeLineIcon('PanelsTopLeft'),
                  onTap: () => _page(const ComponentGalleryPage()))
            ]),
          BeeSupportText(title: l.aboutRelatedProducts, children: [
            const SizedBox(height: 8),
            for (final product in products)
              BeeMenuRow(
                  key: ValueKey('support-product-${product.$1.appStoreId}'),
                  title: product.$1.title,
                  subtitle: product.$1.subtitle,
                  leading: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.asset(product.$1.logoAsset,
                          errorBuilder: (_, error, stack) =>
                              const BeeLineIcon('PanelsTopLeft'))),
                  onTap: () =>
                      platform.product(context, product.$1, product.$2))
          ]),
          Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
            TextButton(
                key: const ValueKey('support-changelog'),
                onPressed: () => _page(HelpCenterPage(
                    title: l.aboutChangelog,
                    initialUrl: WebsiteUrls.changelogEmbed(locale,
                        dark: Theme.of(context).brightness == Brightness.dark,
                        primaryHex: _hex(primary)))),
                child: Text(l.aboutChangelog)),
            TextButton(
                key: const ValueKey('support-privacy'),
                onPressed: () => _page(const PrivacyPolicyPage()),
                child: Text(l.aboutPrivacyPolicy))
          ]),
          if (simplified)
            Text('浙ICP备2025214907号-2A',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).hintColor)),
        ]));
  }
}
