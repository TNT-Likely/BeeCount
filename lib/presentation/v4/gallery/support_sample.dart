import 'package:beecount_business_ui/support.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// Synthetic, controlled component states; no native/website/payment calls.
class SupportSample extends StatefulWidget {
  const SupportSample({super.key});
  @override
  State<SupportSample> createState() => _SupportSampleState();
}

class _SupportSampleState extends State<SupportSample> {
  String event = 'QA support callbacks';
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    void feedback(String value) => setState(() => event = 'QA · $value');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSurface(child: Text(event)),
      const SizedBox(height: 12),
      BeeSupportBrand(
          logo: Image.asset('assets/logo2.png', width: 34, height: 34),
          title: l.appName,
          version: 'QA 4.0',
          socials: const [],
          onStory: () => feedback(l.aboutDeveloperStoryTitle),
          description: l.v4SharePosterOpenSourceBody,
          tag: '${l.appPromoTagOpenSource} · ${l.appPromoTagFree}',
          sourceLabel: l.v4SharePosterOpenSourceAction,
          onSource: () => feedback(l.v4SharePosterOpenSourceAction),
          recommendLabel: l.v4SharePosterRecommend,
          onRecommend: () => feedback(l.v4SharePosterRecommend)),
      const SizedBox(height: 12),
      BeeSupportText(
          title: l.aboutPageTitle,
          description: l.aboutPageSubtitle,
          icon: const BeeLineIcon('Info')),
      const SizedBox(height: 12),
      BeeSupportActions(actions: [
        BeeSupportAction(
            title: l.mineCheckUpdate,
            leading: const BeeLineIcon('RefreshCw'),
            onTap: () => feedback(l.mineCheckUpdate)),
        BeeSupportAction(
            title: l.aboutPrivacyPolicy,
            leading: const BeeLineIcon('ShieldCheck'),
            onTap: () => feedback(l.aboutPrivacyPolicy))
      ]),
      const SizedBox(height: 12),
      BeeSupportShortcut(
          title: l.shortcutVoice,
          description: l.shortcutVoiceDesc,
          url: 'beecount://voice',
          icon: const BeeLineIcon('Mic'),
          onCopy: () => feedback(l.shortcutUrlCopied)),
      const SizedBox(height: 12),
      BeeDonationOptions(
          options: const [
            BeeDonationOption(
                id: 'qa', title: 'QA coffee', price: 'QA 6.00', emoji: '☕')
          ],
          onDonate: (_) => feedback(l.donationTitle),
          loading: false,
          emptyLabel: l.donationNoProducts,
          busyId: null),
      const SizedBox(height: 12),
      SizedBox(
          height: 280,
          child: BeeSupportDocument(
              view: const SizedBox.shrink(),
              progress: 0,
              failed: true,
              failureLabel: l.helpCenterLoadFailed,
              retryLabel: l.helpCenterRetry,
              browserLabel: l.helpCenterOpenInBrowser,
              onRetry: () => feedback(l.helpCenterRetry),
              onBrowser: () => feedback(l.helpCenterOpenInBrowser))),
    ]);
  }
}
