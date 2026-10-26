import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../ai/providers/ai_provider_config.dart';
import '../../../ai/providers/ai_provider_manager.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/ui/toast.dart';

final aiProviderListRefreshProvider = StateProvider<int>((ref) => 0);
final aiProvidersProvider =
    FutureProvider<List<AIServiceProviderConfig>>((ref) async {
  ref.watch(aiProviderListRefreshProvider);
  return AIProviderManager.getProviders();
});

class AIProviderCatalog extends ConsumerWidget {
  const AIProviderCatalog({super.key, required this.onEdit});
  final ValueChanged<AIServiceProviderConfig> onEdit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ref.watch(aiProvidersProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => BeeEmptyState(title: l.commonError, message: '$e'),
        data: (providers) => providers.isEmpty
            ? BeeEmptyState(
                title: l.aiProviderEmpty,
                icon: const BeeLineIcon('Cloud', size: 36))
            : BeePageBody(children: [
                Text(l.aiProviderManageSubtitle,
                    style: TextStyle(
                        fontSize: 11, color: Theme.of(context).hintColor)),
                for (final p in providers)
                  BeeAIProviderCard(
                      name: p.name,
                      builtInLabel: p.isBuiltIn ? l.aiProviderBuiltIn : null,
                      warning: p.isValid ? null : l.aiProviderNoApiKey,
                      editHint: l.aiProviderTapToEdit,
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
                      ],
                      onEdit: () => onEdit(p),
                      deleteLabel: l.commonDelete,
                      onDelete:
                          p.isBuiltIn ? null : () => _delete(context, ref, p)),
              ]));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref,
      AIServiceProviderConfig provider) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => BeeDialog(
                title: Text(l.aiProviderDeleteTitle),
                content: Text(l.aiProviderDeleteConfirm(provider.name)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l.commonCancel)),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(ctx).colorScheme.error,
                          foregroundColor: Theme.of(ctx).colorScheme.onError),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.commonDelete)),
                ]));
    if (confirmed != true || !context.mounted) return;
    final success = await AIProviderManager.deleteProvider(provider.id);
    if (!context.mounted) return;
    if (success) {
      ref.read(aiProviderListRefreshProvider.notifier).state++;
      showToast(context, l.aiProviderDeleted);
    }
  }
}
