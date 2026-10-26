import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/ai_config_providers.dart';
import '../../ai/privacy/ai_privacy_consent.dart';
import '../../widgets/ai/ai_privacy_consent_dialog.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
import '../../presentation/v4/bindings/ai_settings_controls.dart';
import '../../presentation/v4/bindings/ai_settings_capabilities.dart';

class AISettingsPage extends ConsumerStatefulWidget {
  const AISettingsPage({super.key});
  @override
  ConsumerState<AISettingsPage> createState() => _AISettingsPageState();
}

class _AISettingsPageState extends ConsumerState<AISettingsPage> {
  @override
  void initState() {
    super.initState();
    // Preserve the upgrade consent gate; refusing disables recognition.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!ref.read(aiConfigProvider).enabled) return;
      if (await AiPrivacyConsentStore.isConsented()) return;
      if (!mounted) return;
      final agreed = await ensureAiPrivacyConsent(context, ref);
      if (!agreed && mounted) {
        await ref.read(aiConfigProvider.notifier).setEnabled(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.aiSettingsTitle, leading: const BackButton()),
      Expanded(
          child: BeePageBody(eager: true, children: [
        Text(l.aiSettingsSubtitle,
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
        const AISettingsEnableCard(),
        const AISettingsProviderCard(),
        const AISettingsCapabilityCard(),
        const AISettingsAdvancedCard(),
      ])),
    ]));
  }
}
