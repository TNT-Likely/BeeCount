import 'package:beecount_business_ui/auto_billing.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../l10n/app_localizations.dart';
import 'auto_billing_actions.dart';
import 'ios_auto_billing_actions.dart';

/// Read the same existing persisted flag as ScreenshotMonitorService.isEnabled.
/// Do not construct that singleton: its constructor installs a screenshot
/// callback. The catalog must not initialize monitoring or AutoBillingService.
final autoBillingReadOnlyEnabledProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  if (const bool.fromEnvironment('GOOGLE_PLAY', defaultValue: false)) {
    return false;
  }
  return (await SharedPreferences.getInstance())
          .getBool('screenshot_monitor_enabled') ??
      false;
});

/// Current platform configuration only. No permissions, battery method calls,
/// external launches, shortcut execution or monitoring lifecycle changes.
class LiveAutoBillingPreview extends ConsumerWidget {
  const LiveAutoBillingPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ios =
        ref.watch(autoBillingPlatformProvider) == AutoBillingPlatform.ios;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实自动记账配置（只读）'),
      const SizedBox(height: 8),
      if (ios) ...[
        BeeAutoBillingInfoCard(
            title: l.featureDescription, description: l.iosAutoFeatureDesc),
        if (!ref.watch(iosAutoBillingSupportsAppIntentsProvider)) ...[
          const SizedBox(height: 12),
          BeeAutoBillingVersionNotice(
              title: l.iosVersionWarningTitle,
              description: l.iosVersionWarningDesc),
        ],
      ] else
        ref.watch(autoBillingReadOnlyEnabledProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                BeeStatus(label: l.commonError, tone: BeeTone.error),
            data: (enabled) => BeeAutoBillingMonitorCard(
                title: l.autoBilling,
                status: enabled ? l.enabled : l.disabled,
                enabled: enabled,
                onChanged: null)),
    ]);
  }
}
