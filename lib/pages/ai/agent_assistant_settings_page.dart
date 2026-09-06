import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/runtime/agent_execution_settings.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/ai_chat_providers.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/primary_header.dart';
import 'agent_activity_page.dart';
import 'agent_memory_page.dart';
import 'agent_permissions_page.dart';

/// One entry point for the local controls of the AI assistant.
final class AgentAssistantSettingsPage extends ConsumerStatefulWidget {
  const AgentAssistantSettingsPage({super.key, required this.ledgerId});

  final int ledgerId;

  @override
  ConsumerState<AgentAssistantSettingsPage> createState() =>
      _AgentAssistantSettingsPageState();
}

final class _AgentAssistantSettingsPageState
    extends ConsumerState<AgentAssistantSettingsPage> {
  AgentExecutionSettings? _executionSettings;

  @override
  void initState() {
    super.initState();
    _loadExecutionSettings();
  }

  Future<void> _loadExecutionSettings() async {
    final settings = await ref.read(agentExecutionSettingsStoreProvider).read();
    if (mounted) setState(() => _executionSettings = settings);
  }

  Future<void> _chooseExecutionDepth() async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: BeeTokens.surfaceSheet(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              l10n.agentExecutionDepthChooseTitle,
              style: BeeTextTokens.boldTitle(sheetContext),
            ),
            const SizedBox(height: 12),
            for (final option in _depthOptions(l10n))
              RadioListTile<int>(
                value: option.turns,
                groupValue: _executionSettings?.maximumModelTurns,
                contentPadding: EdgeInsets.zero,
                title: Text(option.label),
                subtitle: Text(
                  l10n.agentExecutionDepthSelected(option.turns),
                ),
                onChanged: (value) => Navigator.of(sheetContext).pop(value),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await ref
        .read(agentExecutionSettingsStoreProvider)
        .setMaximumModelTurns(selected);
    await _loadExecutionSettings();
  }

  List<({int turns, String label})> _depthOptions(AppLocalizations l10n) => [
        (turns: 2, label: l10n.agentExecutionDepthQuick),
        (
          turns: AgentExecutionSettings.standardTurns,
          label: l10n.agentExecutionDepthStandard
        ),
        (turns: 6, label: l10n.agentExecutionDepthDeep),
        (
          turns: AgentExecutionSettings.maximumTurns,
          label: l10n.agentExecutionDepthCustom
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final executionSettings = _executionSettings;
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.agentAssistantSettingsTitle,
            subtitle: l10n.agentAssistantSettingsSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                _SettingsCard(
                  icon: Icons.verified_user_outlined,
                  title: l10n.agentAssistantPermissionsEntry,
                  description: l10n.agentAssistantPermissionsEntryDescription,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AgentPermissionsPage()),
                  ),
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  icon: Icons.memory_outlined,
                  title: l10n.agentAssistantMemoryEntry,
                  description: l10n.agentAssistantMemoryEntryDescription,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AgentMemoryPage(ledgerId: widget.ledgerId),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  icon: Icons.history_outlined,
                  title: l10n.agentAssistantActivityEntry,
                  description: l10n.agentAssistantActivityEntryDescription,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AgentActivityPage(ledgerId: widget.ledgerId),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _SettingsCard(
                  icon: Icons.tune_outlined,
                  title: l10n.agentExecutionDepthEntry,
                  description: executionSettings == null
                      ? l10n.agentExecutionDepthEntryDescription
                      : l10n.agentExecutionDepthSelected(
                          executionSettings.maximumModelTurns,
                        ),
                  trailing: executionSettings == null
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap:
                      executionSettings == null ? null : _chooseExecutionDepth,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Material(
        color: BeeTokens.surface(context),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: BeeTokens.primary(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: BeeTokens.primary(context)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: BeeTextTokens.strongTitle(context)),
                      const SizedBox(height: 3),
                      Text(description, style: BeeTextTokens.label(context)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailing ??
                    Icon(Icons.chevron_right,
                        color: BeeTokens.iconSecondary(context)),
              ],
            ),
          ),
        ),
      );
}
