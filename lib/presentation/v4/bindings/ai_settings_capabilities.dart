import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/ai_config_providers.dart';
import '../../../ai/providers/ai_provider_config.dart';
import '../../../ai/providers/ai_provider_manager.dart';
import '../../../widgets/ui/toast.dart';

class AISettingsCapabilityCard extends ConsumerWidget {
  const AISettingsCapabilityCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        binding = ref.watch(aiCapabilityBindingProvider),
        providers = ref.watch(aiProviderListForCapabilityProvider);
    Widget content(AICapabilityBinding selected,
            List<AIServiceProviderConfig> options) =>
        Column(children: [
          for (final item in [
            (
              AICapabilityType.text,
              l.aiCapabilityTextChat,
              l.aiCapabilityTextChatDesc,
              'MessageSquare',
              selected.textProviderId
            ),
            (
              AICapabilityType.vision,
              l.aiCapabilityImageUnderstand,
              l.aiCapabilityImageUnderstandDesc,
              'Images',
              selected.visionProviderId
            ),
            (
              AICapabilityType.speech,
              l.aiCapabilitySpeechToText,
              l.aiCapabilitySpeechToTextDesc,
              'Mic',
              selected.speechProviderId
            ),
          ]) ...[
            const Divider(height: 1, indent: 12, endIndent: 12),
            BeeAICapabilityRow(
                title: item.$2,
                description: item.$3,
                icon: BeeLineIcon(item.$4),
                providerName: options
                    .firstWhere((p) => p.id == item.$5,
                        orElse: () => AIServiceProviderConfig.zhipuDefault)
                    .name,
                onSelect: () => _choose(context, ref,
                    title: item.$2,
                    current: item.$5,
                    type: item.$1,
                    providers: options
                        .where((p) => switch (item.$1) {
                              AICapabilityType.text => p.supportsText,
                              AICapabilityType.vision => p.supportsVision,
                              AICapabilityType.speech => p.supportsSpeech,
                            })
                        .toList())),
          ],
        ]);
    Widget error(Object e) =>
        Padding(padding: const EdgeInsets.all(12), child: Text('$e'));
    const loading = Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()));
    return BeeSurface(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.aiCapabilitySelectTitle,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(l.aiCapabilitySelectSubtitle,
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).hintColor)),
                  ])),
          binding.when(
              data: (b) => providers.when(
                  data: (p) => content(b, p),
                  loading: () => loading,
                  error: (e, _) => error(e)),
              loading: () => loading,
              error: (e, _) => error(e)),
        ]));
  }

  void _choose(BuildContext context, WidgetRef ref,
      {required String title,
      required String? current,
      required AICapabilityType type,
      required List<AIServiceProviderConfig> providers}) {
    final l = AppLocalizations.of(context);
    showDialog<void>(
        context: context,
        builder: (ctx) => BeeDialog(
                title: Text(title),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: providers
                        .map((p) => BeeMenuRow(
                              title: p.name,
                              selected: p.id == current,
                              subtitle: p.isValid ? null : l.aiProviderNoApiKey,
                              leading: BeeLineIcon(
                                  p.id == current ? 'CircleCheck' : 'Circle',
                                  size: 20),
                              onTap: () async {
                                Navigator.pop(ctx);
                                await AIProviderManager.setCapabilityProvider(
                                    type, p.id);
                                ref
                                    .read(aiCapabilityBindingRefreshProvider
                                        .notifier)
                                    .state++;
                                if (context.mounted) {
                                  showToast(
                                      context, '${l.commonSaved}: ${p.name}');
                                }
                              },
                            ))
                        .toList()),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l.commonCancel))
                ]));
  }
}
