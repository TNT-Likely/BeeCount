import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/settings/smart_billing_page.dart';
import '../../../providers/attachment_settings_providers.dart';
import '../../../providers/smart_billing_providers.dart';
import '../../../providers/voice_billing_providers.dart';

class LiveSmartBillingPreview extends ConsumerWidget {
  const LiveSmartBillingPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        voice = ref.watch(voiceBillingSettingsProvider),
        original = ref.watch(attachmentKeepOriginalProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实识别偏好（只读）'),
      const SizedBox(height: 8),
      BeeSurface(
          padding: EdgeInsets.zero,
          child: Column(children: [
            BeeToggleRow(
                title: l.smartBillingAutoTags,
                value: ref.watch(smartBillingAutoTagsProvider),
                onChanged: null),
            BeeToggleRow(
                title: l.smartBillingAutoAttachment,
                value: ref.watch(smartBillingAutoAttachmentProvider),
                onChanged: null),
            BeeToggleRow(
                title: l.attachmentKeepOriginal,
                value: original.valueOrNull ?? false,
                onChanged: null),
            BeeMenuRow(
                title: l.smartBillingVoiceTrigger,
                subtitle:
                    '${voice.triggerMode == VoiceTriggerMode.auto ? l.voiceTriggerModeAuto : l.voiceTriggerModeHold} · ${voice.silenceTimeoutMs} ms')
          ])),
      const SizedBox(height: 12),
      BeeButton(
          label: '打开真实智能记账',
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const SmartBillingPage())))
    ]);
  }
}
