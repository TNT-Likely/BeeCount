import 'dart:io' show Platform;
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ai/ai_settings_page.dart';
import '../../../automation/auto_billing_settings_page.dart';
import '../../shortcuts_guide_page.dart';
import 'smart_billing_dialogs.dart';

/// Host-only distribution policy. Presentation packages never inspect Platform.
class SmartBillingAvailability {
  const SmartBillingAvailability(
      {required this.android, required this.googlePlay});
  final bool android, googlePlay;
  bool get share => android;
  bool get screenshot => !(android && googlePlay);
}

final smartBillingAvailabilityProvider = Provider((ref) =>
    SmartBillingAvailability(
        android: Platform.isAndroid,
        googlePlay:
            const bool.fromEnvironment('GOOGLE_PLAY', defaultValue: false)));

Widget smartBillingCard(BuildContext context, List<Widget> rows) => BeeSurface(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Column(children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0)
          Divider(
              height: 1,
              indent: 12,
              endIndent: 12,
              color: Theme.of(context).dividerColor),
        rows[i]
      ]
    ]));

class SmartBillingEntries extends ConsumerWidget {
  const SmartBillingEntries({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        policy = ref.watch(smartBillingAvailabilityProvider);
    Widget row(String icon, String title, String desc, VoidCallback tap) =>
        BeeMenuRow(
            title: title,
            subtitle: desc,
            leading: BeeLineIcon(icon, size: 20),
            onTap: tap);
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    Widget guide(String icon, String title, String desc, String body,
            String requirement, {String? hint}) =>
        row(
            icon,
            title,
            desc,
            () => SmartBillingDialogs.guide(context,
                title: title,
                description: body,
                requirement: requirement,
                actionHint: hint));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      smartBillingCard(context, [
        row('Sparkles', l.aiSettingsTitle, l.aiSettingsSubtitle,
            () => open(const AISettingsPage()))
      ]),
      const SizedBox(height: 12),
      smartBillingCard(context, [
        guide(
            'Images',
            l.smartBillingImageBilling,
            l.smartBillingImageBillingDesc,
            l.smartBillingImageBillingGuide,
            l.smartBillingVisionAIRequired),
        guide(
            'Camera',
            l.smartBillingCameraBilling,
            l.smartBillingCameraBillingDesc,
            l.smartBillingCameraBillingGuide,
            l.smartBillingVisionAIRequired),
        guide('Mic', l.smartBillingVoiceBilling, l.smartBillingVoiceBillingDesc,
            l.smartBillingVoiceBillingGuide, l.smartBillingAIRequired)
      ]),
      const SizedBox(height: 12),
      smartBillingCard(context, [
        if (policy.share)
          guide('Share2', l.shareBilling, l.shareBillingDesc,
              l.shareBillingGuide, l.smartBillingVisionAIRequired,
              hint: l.shareBillingActionHint),
        if (policy.screenshot)
          row(
              'ScanLine',
              policy.android
                  ? l.autoScreenshotBilling
                  : l.autoScreenshotBillingIosTitle,
              policy.android
                  ? l.autoScreenshotBillingDesc
                  : l.autoScreenshotBillingIosDesc,
              () => open(const AutoBillingSettingsPage())),
        row('Command', l.shortcutsGuide, l.shortcutsGuideDesc,
            () => open(const ShortcutsGuidePage()))
      ])
    ]);
  }
}
