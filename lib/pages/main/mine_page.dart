import '../shared/scaffold/widgets/page_scaffold.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../l10n/app_localizations.dart';
import 'mine/widgets/mine_profile.dart';
import 'mine/bindings/mine_cloud.dart';
import 'mine/bindings/mine_actions.dart';
import '../../providers/github_star_provider.dart';
import '../../services/export/share_poster_service.dart';
import '../../utils/website_urls.dart';
import '../shared/widgets/feature_dot.dart';
import '../settings/help_center_page.dart';
import '../settings/data_management_page.dart';
import '../settings/appearance_settings_page.dart';
import '../settings/smart_billing_page.dart';
import '../settings/automation_page.dart';
import '../settings/about_page.dart';
import '../report/annual_report_page.dart';
import '../donation/donation_page.dart';

class MinePage extends ConsumerWidget {
  const MinePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    void open(Widget page) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    Widget row(String title, String subtitle, String icon, VoidCallback onTap,
            {bool highlight = false}) =>
        BeeMenuRow(
            title: title,
            subtitle: subtitle,
            onTap: onTap,
            leading: highlight
                ? FeatureDot(
                    anchor: 'personalize', child: BeeLineIcon(icon, size: 19))
                : BeeLineIcon(icon, size: 19));
    Widget group(String label, List<Widget> rows) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(4, 21, 4, 10),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).hintColor))),
          BeeSurface(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 12, endIndent: 12),
                  rows[i]
                ]
              ]))
        ]);
    final stars = ref.watch(githubStarCountProvider).valueOrNull ??
        githubStarFallbackCount;
    return V4PageScaffold(
        profileHeaderSkin: true,
        backgroundColor: BeeCardTheme.of(context).canvas,
        body: Column(children: [
          BeePageHeader(title: l.mineTitle, actions: [
            BeeIconButton(
                label: l.commonSettings,
                icon: const BeeLineIcon('Settings2'),
                onPressed: () => open(const AppearanceSettingsPage()))
          ]),
          Expanded(
              child: ListView(
                  padding: EdgeInsets.fromLTRB(
                      17, 0, 17, 84 + MediaQuery.viewPaddingOf(context).bottom),
                  children: [
                const MineProfileBinding(),
                group(l.v4MineCloudGroup, [const MineCloudBinding()]),
                group(l.v4MineFeaturesGroup, [
                  row(l.smartBilling, l.smartBillingDesc, 'Sparkles',
                      () => open(const SmartBillingPage())),
                  row(l.dataManagement, l.dataManagementDesc, 'Database',
                      () => open(const DataManagementPage())),
                  row(l.automation, l.automationDesc, 'Clock',
                      () => open(const AutomationPage())),
                  row(l.appearanceSettings, l.appearanceSettingsDesc, 'Palette',
                      () => open(const AppearanceSettingsPage()),
                      highlight: true)
                ]),
                group(l.v4MineHelpGroup, [
                  row(l.about, l.aboutDesc, 'Info',
                      () => open(const AboutPage())),
                  row(l.mineHelp, l.mineHelpSubtitle, 'CircleHelp', () async {
                    if (kHelpCenterInApp) {
                      open(const HelpCenterPage());
                    } else {
                      await tryOpenMineUrl(Uri.parse(
                          WebsiteUrls.docs(Localizations.localeOf(context))));
                    }
                  })
                ]),
                group(l.v4MineSupportGroup, [
                  if (Platform.isIOS)
                    row(l.donationTitle, l.donationEntrySubtitle, 'Heart',
                        () => open(const DonationPage())),
                  row(
                      l.mineSupportAuthor,
                      l.mineSupportAuthorSubtitle(stars.toString()),
                      'Star',
                      () => showMineGitHubStarGuide(context)),
                  row(
                      l.annualReportTitle,
                      l.annualReportEntrySubtitle,
                      'ChartNoAxesCombined',
                      () => open(const AnnualReportPage())),
                  row(
                      l.mineShareApp,
                      l.mineShareWithFriends,
                      'Share2',
                      () => SharePosterService.showPosterCarouselPreview(
                          context)),
                  row(l.mineCopyPromoText, l.mineCopyPromoSubtitle, 'Copy',
                      () async {
                    await Clipboard.setData(
                        ClipboardData(text: l.shareGuidanceCopyText));
                    if (context.mounted) {
                      showBeeToast(context, l.shareGuidanceCopied,
                          tone: BeeTone.success);
                    }
                  }),
                  if (Platform.isIOS)
                    row(l.mineRateApp, l.mineRateAppSubtitle, 'Star',
                        () => rateMineApp(context)),
                ])
              ]))
        ]));
  }
}
