import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/ai_quick_command.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';

/// Four high-frequency prompts shown only while a conversation is empty.
///
/// They help a new user discover useful tasks without permanently occupying
/// vertical space once the conversation has started.
final class AIQuickCommandSuggestions extends ConsumerWidget {
  const AIQuickCommandSuggestions({
    super.key,
    required this.onCommandTap,
  });

  final ValueChanged<AIQuickCommand> onCommandTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final commands = AIQuickCommands.getAllCommands().take(4).toList();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8.0.scaled(context, ref),
      runSpacing: 8.0.scaled(context, ref),
      children: [
        for (var index = 0; index < commands.length; index++)
          ActionChip(
            key: ValueKey('ai-quick-command-suggestion-$index'),
            avatar: Icon(
              Icons.auto_awesome_outlined,
              size: 15.0.scaled(context, ref),
            ),
            label: Text(_titleFor(commands[index], l10n)),
            onPressed: () => onCommandTap(commands[index]),
          ),
      ],
    );
  }
}

/// A compact input-adjacent entry point for the full command catalog.
final class AIQuickCommandLauncher extends StatelessWidget {
  const AIQuickCommandLauncher({
    super.key,
    required this.onCommandTap,
    this.enabled = true,
  });

  final ValueChanged<AIQuickCommand> onCommandTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      key: const ValueKey('ai-quick-command-launcher'),
      tooltip: l10n.aiQuickCommandsOpen,
      onPressed: enabled
          ? () async {
              final command = await showModalBottomSheet<AIQuickCommand>(
                context: context,
                showDragHandle: true,
                builder: (_) => const _AIQuickCommandsSheet(),
              );
              if (command != null) onCommandTap(command);
            }
          : null,
      icon: const Icon(Icons.auto_awesome_outlined),
    );
  }
}

final class _AIQuickCommandsSheet extends ConsumerWidget {
  const _AIQuickCommandsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final commands = AIQuickCommands.getAllCommands();
    return SafeArea(
      top: false,
      child: SizedBox(
        key: const ValueKey('ai-quick-command-sheet'),
        height: 420.0.scaled(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                20.0.scaled(context, ref),
                4.0.scaled(context, ref),
                20.0.scaled(context, ref),
                8.0.scaled(context, ref),
              ),
              child: Text(
                l10n.aiQuickCommandsTitle,
                style: BeeTextTokens.strongTitle(context),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  12.0.scaled(context, ref),
                  0,
                  12.0.scaled(context, ref),
                  16.0.scaled(context, ref),
                ),
                itemCount: commands.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final command = commands[index];
                  final description = _descriptionFor(command, l10n);
                  return ListTile(
                    key: ValueKey('ai-quick-command-sheet-item-$index'),
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text(_titleFor(command, l10n)),
                    subtitle: description == null || description.isEmpty
                        ? null
                        : Text(description),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pop(command),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _titleFor(AIQuickCommand command, AppLocalizations l10n) {
  return switch (command.titleKey) {
    'aiQuickCommandFinancialHealthTitle' =>
      l10n.aiQuickCommandFinancialHealthTitle,
    'aiQuickCommandMonthlyExpenseTitle' =>
      l10n.aiQuickCommandMonthlyExpenseTitle,
    'aiQuickCommandCategoryAnalysisTitle' =>
      l10n.aiQuickCommandCategoryAnalysisTitle,
    'aiQuickCommandBudgetPlanningTitle' =>
      l10n.aiQuickCommandBudgetPlanningTitle,
    'aiQuickCommandAbnormalExpenseTitle' =>
      l10n.aiQuickCommandAbnormalExpenseTitle,
    'aiQuickCommandSavingTipsTitle' => l10n.aiQuickCommandSavingTipsTitle,
    _ => command.titleKey,
  };
}

String? _descriptionFor(AIQuickCommand command, AppLocalizations l10n) {
  return switch (command.descriptionKey) {
    'aiQuickCommandFinancialHealthDesc' =>
      l10n.aiQuickCommandFinancialHealthDesc,
    'aiQuickCommandMonthlyExpenseDesc' => l10n.aiQuickCommandMonthlyExpenseDesc,
    'aiQuickCommandCategoryAnalysisDesc' =>
      l10n.aiQuickCommandCategoryAnalysisDesc,
    'aiQuickCommandBudgetPlanningDesc' => l10n.aiQuickCommandBudgetPlanningDesc,
    'aiQuickCommandAbnormalExpenseDesc' =>
      l10n.aiQuickCommandAbnormalExpenseDesc,
    'aiQuickCommandSavingTipsDesc' => l10n.aiQuickCommandSavingTipsDesc,
    _ => null,
  };
}
