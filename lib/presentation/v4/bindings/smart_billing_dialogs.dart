import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/voice_billing_providers.dart';

abstract final class SmartBillingDialogs {
  static void guide(BuildContext context,
      {required String title,
      required String description,
      required String requirement,
      String? actionHint,
      bool requiresAI = true}) {
    final l = AppLocalizations.of(context);
    showDialog<void>(
        context: context,
        builder: (ctx) => BeeDialog(
                title: Text(title),
                content: BeeBillingGuide(
                    description: description,
                    requirement: requirement,
                    actionHint: actionHint ?? l.smartBillingGuideHint,
                    requiresAI: requiresAI),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l.commonKnow))
                ]));
  }

  static void voice(
      BuildContext context, WidgetRef ref, VoiceTriggerMode current) {
    final l = AppLocalizations.of(context);
    showDialog<void>(
        context: context,
        builder: (ctx) => BeeDialog(
                title: Text(l.smartBillingVoiceTrigger),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final mode in VoiceTriggerMode.values)
                    RadioListTile<VoiceTriggerMode>(
                        value: mode,
                        groupValue: current,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            mode == VoiceTriggerMode.auto
                                ? l.voiceTriggerModeAuto
                                : l.voiceTriggerModeHold,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            mode == VoiceTriggerMode.auto
                                ? l.voiceTriggerModeAutoDesc
                                : l.voiceTriggerModeHoldDesc,
                            style: const TextStyle(fontSize: 11)),
                        onChanged: (value) async {
                          if (value == null) return;
                          Navigator.pop(ctx);
                          await ref
                              .read(voiceBillingSettingsProvider.notifier)
                              .setTriggerMode(value);
                        })
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l.commonCancel))
                ]));
  }
}
