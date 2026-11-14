import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/ai/ai_settings_page.dart';
import '../../../providers/ai_config_providers.dart';

class LiveAISettingsPreview extends ConsumerWidget {
  const LiveAISettingsPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        config = ref.watch(aiConfigProvider),
        binding = ref.watch(aiCapabilityBindingProvider),
        providers = ref.watch(aiProviderListForCapabilityProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实AI能力绑定（只读）'),
      const SizedBox(height: 8),
      BeeToggleRow(
          title: l.aiEnableTitle, value: config.enabled, onChanged: null),
      binding.when(
          data: (b) => providers.when(
              data: (ps) => Column(children: [
                    for (final item in [
                      (
                        l.aiCapabilityTextChat,
                        b.textProviderId,
                        'MessageSquare'
                      ),
                      (
                        l.aiCapabilityImageUnderstand,
                        b.visionProviderId,
                        'Images'
                      ),
                      (l.aiCapabilitySpeechToText, b.speechProviderId, 'Mic')
                    ])
                      BeeAICapabilityRow(
                          title: item.$1,
                          description: '只读',
                          providerName: ps
                                  .where((p) => p.id == item.$2)
                                  .firstOrNull
                                  ?.name ??
                              '智谱GLM',
                          icon: BeeLineIcon(item.$3),
                          onSelect: null),
                  ]),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e')),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('$e')),
      const SizedBox(height: 12),
      BeeButton(
          label: '打开真实AI设置',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const AISettingsPage()))),
    ]);
  }
}
