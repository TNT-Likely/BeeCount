import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/ai/ai_provider_manage_page.dart';

class LiveAIProviderPreview extends ConsumerWidget {
  const LiveAIProviderPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实服务商（只读，无密钥）'),
      const SizedBox(height: 8),
      ref.watch(aiProvidersProvider).when(
          data: (ps) => Column(children: [
                for (final p in ps)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BeeAIProviderCard(
                          name: p.name,
                          builtInLabel:
                              p.isBuiltIn ? l.aiProviderBuiltIn : null,
                          warning: p.isValid ? null : l.aiProviderNoApiKey,
                          editHint: l.aiProviderTapToEdit,
                          onEdit: null,
                          capabilities: [
                            BeeAIProviderCapability(l.aiCapabilityText,
                                const BeeLineIcon('MessageSquare', size: 14),
                                enabled: p.supportsText),
                            BeeAIProviderCapability(l.aiCapabilityVision,
                                const BeeLineIcon('Images', size: 14),
                                enabled: p.supportsVision),
                            BeeAIProviderCapability(l.aiCapabilitySpeech,
                                const BeeLineIcon('Mic', size: 14),
                                enabled: p.supportsSpeech),
                          ]))
              ]),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('$e')),
      BeeButton(
          label: '打开真实服务商管理',
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const AIProviderManagePage()))),
    ]);
  }
}
