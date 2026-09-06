import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/ai_quick_command.dart';
import '../../providers/theme_providers.dart';
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
    final primary = ref.watch(primaryColorProvider);
    final commands = AIQuickCommands.getAllCommands().take(4).toList();
    final gap = 8.0.scaled(context, ref);
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - gap) / 2;
        return SizedBox(
          width: constraints.maxWidth,
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var index = 0; index < commands.length; index++)
                SizedBox(
                  width: itemWidth,
                  height: 38.0.scaled(context, ref),
                  child: _AIQuickCommandSuggestionCard(
                    key: ValueKey('ai-quick-command-suggestion-$index'),
                    iconKey: ValueKey(
                      'ai-quick-command-suggestion-icon-$index',
                    ),
                    command: commands[index],
                    title: _titleFor(commands[index], l10n),
                    primary: primary,
                    onTap: () => onCommandTap(commands[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

final class _AIQuickCommandSuggestionCard extends StatelessWidget {
  const _AIQuickCommandSuggestionCard({
    super.key,
    required this.iconKey,
    required this.command,
    required this.title,
    required this.primary,
    required this.onTap,
  });

  final Key iconKey;
  final AIQuickCommand command;
  final String title;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = BeeTokens.isDark(context);
    final radius = BorderRadius.circular(12);
    final iconBackground = primary.withValues(alpha: isDark ? 0.22 : 0.14);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: BeeTokens.surface(context),
          borderRadius: radius,
          border: Border.all(
            color: primary.withValues(alpha: isDark ? 0.32 : 0.14),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Row(
              children: [
                Container(
                  key: iconKey,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    _iconFor(command),
                    color: primary,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: BeeTextTokens.strongTitle(context).copyWith(
                      color: BeeTokens.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact input-adjacent entry point for the full command catalog.
final class AIQuickCommandLauncher extends ConsumerWidget {
  const AIQuickCommandLauncher({
    super.key,
    required this.onCommandTap,
    this.enabled = true,
  });

  final ValueChanged<AIQuickCommand> onCommandTap;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    return IconButton(
      key: const ValueKey('ai-quick-command-launcher'),
      tooltip: l10n.aiQuickCommandsOpen,
      onPressed: enabled
          ? () async {
              final command = await showModalBottomSheet<AIQuickCommand>(
                context: context,
                backgroundColor: BeeTokens.surfaceSheet(context),
                barrierColor: BeeTokens.overlay(context),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => const _AIQuickCommandsSheet(),
              );
              if (command != null) onCommandTap(command);
            }
          : null,
      style: IconButton.styleFrom(foregroundColor: primary),
      icon: const Icon(Icons.auto_awesome_outlined),
    );
  }
}

final class _AIQuickCommandsSheet extends ConsumerWidget {
  const _AIQuickCommandsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    final commands = AIQuickCommands.getAllCommands();
    return SafeArea(
      top: false,
      child: SizedBox(
        key: const ValueKey('ai-quick-command-sheet'),
        height: 404.0.scaled(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 12.0.scaled(context, ref)),
                width: 34.0.scaled(context, ref),
                height: 4.0.scaled(context, ref),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20.0.scaled(context, ref),
                18.0.scaled(context, ref),
                20.0.scaled(context, ref),
                12.0.scaled(context, ref),
              ),
              child: Row(
                children: [
                  Container(
                    key: const ValueKey('ai-quick-command-sheet-header-icon'),
                    width: 38.0.scaled(context, ref),
                    height: 38.0.scaled(context, ref),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.14),
                      borderRadius:
                          BorderRadius.circular(13.0.scaled(context, ref)),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: primary,
                      size: 20.0.scaled(context, ref),
                    ),
                  ),
                  SizedBox(width: 12.0.scaled(context, ref)),
                  Text(
                    l10n.aiQuickCommandsTitle,
                    style: BeeTextTokens.boldTitle(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                key: const ValueKey('ai-quick-command-sheet-grid'),
                padding: EdgeInsets.fromLTRB(
                  16.0.scaled(context, ref),
                  0,
                  16.0.scaled(context, ref),
                  16.0.scaled(context, ref),
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10.0.scaled(context, ref),
                  crossAxisSpacing: 10.0.scaled(context, ref),
                  mainAxisExtent: 82.0.scaled(context, ref),
                ),
                itemCount: commands.length,
                itemBuilder: (context, index) {
                  final command = commands[index];
                  return Material(
                    key: ValueKey('ai-quick-command-sheet-item-$index'),
                    color: primary.withValues(
                      alpha: BeeTokens.isDark(context) ? 0.18 : 0.08,
                    ),
                    borderRadius:
                        BorderRadius.circular(16.0.scaled(context, ref)),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(command),
                      borderRadius:
                          BorderRadius.circular(16.0.scaled(context, ref)),
                      child: Padding(
                        padding: EdgeInsets.all(12.0.scaled(context, ref)),
                        child: Row(
                          children: [
                            Container(
                              width: 30.0.scaled(context, ref),
                              height: 30.0.scaled(context, ref),
                              decoration: BoxDecoration(
                                color: BeeTokens.surface(context),
                                borderRadius: BorderRadius.circular(
                                  10.0.scaled(context, ref),
                                ),
                              ),
                              child: Icon(
                                Icons.auto_awesome_outlined,
                                color: primary,
                                size: 16.0.scaled(context, ref),
                              ),
                            ),
                            SizedBox(width: 9.0.scaled(context, ref)),
                            Expanded(
                              child: Text(
                                _titleFor(command, l10n),
                                style: BeeTextTokens.strongTitle(context),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

IconData _iconFor(AIQuickCommand command) {
  return switch (command.titleKey) {
    'aiQuickCommandFinancialHealthTitle' => Icons.monitor_heart_outlined,
    'aiQuickCommandMonthlyExpenseTitle' => Icons.calendar_month_outlined,
    'aiQuickCommandCategoryAnalysisTitle' => Icons.pie_chart_outline_rounded,
    'aiQuickCommandBudgetPlanningTitle' => Icons.savings_outlined,
    'aiQuickCommandAbnormalExpenseTitle' => Icons.trending_up_rounded,
    'aiQuickCommandSavingTipsTitle' => Icons.lightbulb_outline_rounded,
    _ => Icons.auto_awesome_outlined,
  };
}
