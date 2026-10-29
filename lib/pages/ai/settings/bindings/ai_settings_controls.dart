import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/ai_config_providers.dart';
import '../../ai_provider_manage_page.dart';
import '../../ai_prompt_edit_page.dart';
import '../../bindings/ai_privacy_consent_dialog.dart';

class AISettingsEnableCard extends ConsumerWidget {
  const AISettingsEnableCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        config = ref.watch(aiConfigProvider);
    return BeeSurface(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: BeeToggleRow(
          title: l.aiEnableTitle,
          subtitle: l.aiEnableSubtitle,
          leading: const BeeLineIcon('Sparkles'),
          value: config.enabled,
          onChanged: (value) async {
            if (value && !await ensureAiPrivacyConsent(context, ref)) return;
            await ref.read(aiConfigProvider.notifier).setEnabled(value);
            if (context.mounted) {
              showBeeToast(
                  context, value ? l.aiEnableToastOn : l.aiEnableToastOff);
            }
          },
        ));
  }
}

class AISettingsProviderCard extends ConsumerWidget {
  const AISettingsProviderCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return BeeSurface(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: BeeMenuRow(
          title: l.aiProviderManageTitle,
          subtitle: l.aiProviderManageSubtitle,
          leading: const BeeLineIcon('Cloud'),
          onTap: () async {
            await Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const AIProviderManagePage()));
            ref.read(aiCapabilityBindingRefreshProvider.notifier).state++;
            ref
                .read(aiProviderListForCapabilityRefreshProvider.notifier)
                .state++;
          },
        ));
  }
}

class AISettingsAdvancedCard extends ConsumerWidget {
  const AISettingsAdvancedCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        config = ref.watch(aiConfigProvider);
    return BeeSurface(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: BeeAccordion(
          title: l.aiPromptAdvancedSettings,
          subtitle: l.aiAdvancedSettingsDesc,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(l.aiStrategyTitle, style: const TextStyle(fontSize: 13)),
            for (final item in [
              (
                AIStrategy.cloudFirst,
                l.aiStrategyCloudFirst,
                l.aiStrategyCloudFirstDesc,
                true
              ),
              (
                AIStrategy.cloudOnly,
                l.aiStrategyCloudOnly,
                l.aiStrategyCloudOnlyDesc,
                true
              ),
              (
                AIStrategy.localFirst,
                l.aiStrategyLocalFirst,
                l.aiStrategyUnavailable,
                false
              ),
              (
                AIStrategy.localOnly,
                l.aiStrategyLocalOnly,
                l.aiStrategyUnavailable,
                false
              ),
            ])
              BeeRadioTile<AIStrategy>(
                  label: item.$2,
                  subtitle: item.$3,
                  value: item.$1,
                  groupValue: config.strategy,
                  onChanged: !item.$4
                      ? null
                      : (value) async {
                          await ref
                              .read(aiConfigProvider.notifier)
                              .setStrategy(value);
                          if (context.mounted) {
                            showBeeToast(context, l.aiStrategySwitched(item.$2));
                          }
                        }),
            const Divider(height: 1),
            BeeMenuRow(
                title: l.aiPromptEditEntry,
                subtitle: l.aiPromptEditEntryDesc,
                leading: const BeeLineIcon('Pencil'),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const AIPromptEditPage()))),
          ]),
        ));
  }
}
