import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/attachment_settings_providers.dart';
import '../../../providers/smart_billing_providers.dart';
import '../../../providers/voice_billing_providers.dart';
import '../../../widgets/ui/toast.dart';
import 'smart_billing_dialogs.dart';
import 'smart_billing_entries.dart';

class SmartBillingPreferences extends ConsumerWidget {
  const SmartBillingPreferences({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        original = ref.watch(attachmentKeepOriginalProvider);
    return smartBillingCard(context, [
      BeeToggleRow(
          title: l.smartBillingAutoTags,
          subtitle: l.smartBillingAutoTagsDesc,
          leading: const BeeLineIcon('Tags', size: 20),
          value: ref.watch(smartBillingAutoTagsProvider),
          onChanged: (v) =>
              ref.read(smartBillingAutoTagsProvider.notifier).state = v),
      BeeToggleRow(
          title: l.smartBillingAutoAttachment,
          subtitle: l.smartBillingAutoAttachmentDesc,
          leading: const BeeLineIcon('Paperclip', size: 20),
          value: ref.watch(smartBillingAutoAttachmentProvider),
          onChanged: (v) =>
              ref.read(smartBillingAutoAttachmentProvider.notifier).state = v),
      BeeToggleRow(
          title: l.attachmentKeepOriginal,
          subtitle: l.attachmentKeepOriginalDesc,
          leading: const BeeLineIcon('Image', size: 20),
          value: original.valueOrNull ?? false,
          onChanged: !original.hasValue
              ? null
              : (v) async {
                  try {
                    await ref
                        .read(attachmentKeepOriginalProvider.notifier)
                        .setEnabled(v);
                  } catch (_) {
                    if (context.mounted) showToast(context, l.commonError);
                  }
                })
    ]);
  }
}

class SmartBillingVoicePreferences extends ConsumerStatefulWidget {
  const SmartBillingVoicePreferences({super.key});
  @override
  ConsumerState<SmartBillingVoicePreferences> createState() =>
      _SmartBillingVoicePreferencesState();
}

class _SmartBillingVoicePreferencesState
    extends ConsumerState<SmartBillingVoicePreferences> {
  int? dragValue;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        settings = ref.watch(voiceBillingSettingsProvider),
        auto = settings.triggerMode == VoiceTriggerMode.auto,
        ms = dragValue ?? settings.silenceTimeoutMs;
    return smartBillingCard(context, [
      BeeMenuRow(
          title: l.smartBillingVoiceTrigger,
          subtitle: auto ? l.voiceTriggerModeAuto : l.voiceTriggerModeHold,
          leading: const BeeLineIcon('Mic', size: 20),
          onTap: () =>
              SmartBillingDialogs.voice(context, ref, settings.triggerMode)),
      if (auto)
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: BeeSliderField(
                label: l.smartBillingVoiceSilenceTimeout,
                valueLabel: l.smartBillingVoiceSilenceTimeoutValue(
                    (ms / 1000).toStringAsFixed(1)),
                value: ms.toDouble(),
                min: VoiceBillingSettings.minSilenceTimeoutMs.toDouble(),
                max: VoiceBillingSettings.maxSilenceTimeoutMs.toDouble(),
                divisions: (VoiceBillingSettings.maxSilenceTimeoutMs -
                        VoiceBillingSettings.minSilenceTimeoutMs) ~/
                    100,
                onChanged: (value) => setState(() => dragValue = value.round()),
                onChangeEnd: (value) async {
                  setState(() => dragValue = null);
                  await ref
                      .read(voiceBillingSettingsProvider.notifier)
                      .setSilenceTimeoutMs(value.round());
                }))
    ]);
  }
}
