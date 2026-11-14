import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ai/providers/ai_provider_config.dart';
import '../../l10n/app_localizations.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'providers/bindings/ai_provider_catalog.dart';
import 'providers/bindings/ai_provider_editor.dart';
export 'providers/bindings/ai_provider_catalog.dart'
    show aiProviderListRefreshProvider, aiProvidersProvider;
export 'providers/controllers/ai_provider_editor_controller.dart'
    show TestStatus;

class AIProviderManagePage extends ConsumerWidget {
  const AIProviderManagePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    Future<void> edit(AIServiceProviderConfig? provider) async {
      final saved = await showDialog<bool>(
          context: context,
          builder: (_) => AIProviderEditPage(provider: provider));
      if (saved == true && context.mounted) {
        ref.read(aiProviderListRefreshProvider.notifier).state++;
      }
    }

    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.aiProviderManageTitle,
          leading: const BackButton(),
          actions: [
            BeeIconButton(
                label: l.aiProviderAdd,
                icon: const BeeLineIcon('Plus'),
                onPressed: () => edit(null))
          ]),
      Expanded(child: AIProviderCatalog(onEdit: (p) => edit(p))),
    ]));
  }
}

/// Preserved public entry, now rendered in the approved configuration dialog.
class AIProviderEditPage extends StatelessWidget {
  const AIProviderEditPage({super.key, this.provider});
  final AIServiceProviderConfig? provider;
  @override
  Widget build(BuildContext context) => AIProviderEditor(provider: provider);
}
