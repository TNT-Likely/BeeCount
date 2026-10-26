import 'package:beecount_business_ui/auto_billing.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../presentation/v4/bindings/ios_auto_billing_actions.dart';
import '../../widgets/ui/toast.dart';

/// iOS screenshot recognition retains its existing Shortcuts import and manual
/// fallback. This page never enables Android screenshot monitoring.
class IOSAutoBillingPage extends ConsumerStatefulWidget {
  const IOSAutoBillingPage({super.key});
  @override
  ConsumerState<IOSAutoBillingPage> createState() => _IOSAutoBillingPageState();
}

class _IOSAutoBillingPageState extends ConsumerState<IOSAutoBillingPage> {
  bool _openingShortcut = false, _openingTutorial = false;
  Future<void> _open({required bool shortcut}) async {
    if (_openingShortcut || _openingTutorial) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _openingShortcut = shortcut;
      _openingTutorial = !shortcut;
    });
    try {
      final actions = ref.read(iosAutoBillingActionsProvider);
      final ok =
          await (shortcut ? actions.openShortcut() : actions.openTutorial());
      if (!ok && shortcut && mounted) showToast(context, l.iosAutoImportFailed);
    } catch (error) {
      if (mounted) {
        showToast(context, shortcut ? l.iosAutoImportFailed : l.commonError);
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingShortcut = false;
          _openingTutorial = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final supportsAppIntents =
        ref.watch(iosAutoBillingSupportsAppIntentsProvider);
    return Scaffold(
        backgroundColor: BeeCardTheme.of(context).canvas,
        body: Column(children: [
          BeePageHeader(
              title: l.autoScreenshotBillingIosTitle,
              leading: BeeIconButton(
                  label: l.commonBack,
                  icon: const BeeLineIcon('ChevronLeft', size: 22),
                  onPressed: () => Navigator.maybePop(context))),
          Expanded(
              child: BeePageBody(children: [
            BeeAutoBillingTutorialCard(
                title: l.iosAutoTutorialTitle,
                description: l.iosAutoTutorialDesc,
                busy: _openingTutorial,
                onOpen: _openingShortcut ? null : () => _open(shortcut: false)),
            if (!supportsAppIntents)
              BeeAutoBillingVersionNotice(
                  title: l.iosVersionWarningTitle,
                  description: l.iosVersionWarningDesc),
            BeeAutoBillingActionCard(
                title: l.iosAutoImportTitle,
                description: l.iosAutoImportDesc,
                actionLabel: l.iosAutoImportButton,
                actionKey: const ValueKey('auto-billing-import-shortcut'),
                busy: _openingShortcut,
                onAction:
                    _openingTutorial ? null : () => _open(shortcut: true)),
            BeeAutoBillingInfoCard(
                title: l.featureDescription, description: l.iosAutoFeatureDesc),
            BeeAutoBillingInfoCard(
                title: l.iosAutoBackTapTitle,
                description: l.iosAutoBackTapDesc,
                icon: 'Hand'),
            BeeAutoBillingManualGuide(
                title: l.iosAutoManualConfigTitle,
                description: l.iosAutoManualConfigDesc,
                stepsTitle: l.iosAutoShortcutConfigTitle,
                steps: [
                  l.iosAutoShortcutStep1,
                  l.iosAutoShortcutStep2,
                  l.iosAutoShortcutStep3,
                  l.iosAutoShortcutStep4,
                  l.iosAutoShortcutStep5,
                  l.iosAutoShortcutStep6
                ],
                recommendation: l.iosAutoShortcutRecommendedTip),
          ])),
        ]));
  }
}
