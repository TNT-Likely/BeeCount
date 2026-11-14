part of '../../config_import_export_page.dart';

List<BeeConfigurationChoice> _configChoices(AppLocalizations l) => [
      BeeConfigurationChoice(id: 'ledgers', label: l.configIncludeLedgers),
      BeeConfigurationChoice(
          id: 'categories', label: l.configIncludeCategories),
      BeeConfigurationChoice(id: 'accounts', label: l.configIncludeAccounts),
      BeeConfigurationChoice(id: 'tags', label: l.configIncludeTags),
      BeeConfigurationChoice(id: 'budgets', label: l.configIncludeBudgets),
      BeeConfigurationChoice(
          id: 'recurring', label: l.configIncludeRecurringTransactions),
      BeeConfigurationChoice(
          id: 'ai',
          label: l.configIncludeAI,
          detail: l.configIncludeAISubtitle),
      BeeConfigurationChoice(id: 'settings', label: l.configIncludeAppSettings),
    ];
ExportOptions _configOptions(Set<String> value) => ExportOptions(
    ledgers: value.contains('ledgers'),
    categories: value.contains('categories'),
    accounts: value.contains('accounts'),
    tags: value.contains('tags'),
    budgets: value.contains('budgets'),
    recurringTransactions: value.contains('recurring'),
    ai: value.contains('ai'),
    appSettings: value.contains('settings'));
Set<String> _availableConfig(ConfigContentInfo info) => {
      if (info.hasLedgers) 'ledgers',
      if (info.hasCategories) 'categories',
      if (info.hasAccounts) 'accounts',
      if (info.hasTags) 'tags',
      if (info.hasBudgets) 'budgets',
      if (info.hasRecurringTransactions) 'recurring',
      if (info.hasAi) 'ai',
      if (info.hasAppSettings) 'settings'
    };

class _ConfigContentDialog extends StatelessWidget {
  const _ConfigContentDialog({required this.content, required this.onCopy});
  final String content;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeDialog(
        title: Text(l.configExportViewContent),
        content: BeeConfigurationPreview(content: content, label: 'YAML'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.commonClose)),
          BeeButton(label: l.configExportCopyContent, onPressed: onCopy)
        ]);
  }
}

class _ExportOptionsDialog extends StatefulWidget {
  const _ExportOptionsDialog({required this.ref});
  final WidgetRef ref;
  @override
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  Set<String> selected = {
    'ledgers',
    'categories',
    'accounts',
    'tags',
    'budgets',
    'recurring',
    'ai',
    'settings'
  };
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeDialog(
        title: Text(l.configExportSelectTitle),
        content: BeeConfigurationOptions(
            items: _configChoices(l),
            selected: selected,
            onChanged: (v) => setState(() => selected = v)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.commonCancel)),
          BeeButton(
              label: l.commonNext,
              onPressed: () => Navigator.pop(context, _configOptions(selected)))
        ]);
  }
}

class _ExportPreviewDialog extends StatelessWidget {
  const _ExportPreviewDialog({required this.yamlContent});
  final String yamlContent;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeDialog(
        title: Text(l.configExportPreviewTitle),
        content: BeeConfigurationPreview(content: yamlContent, label: 'YAML'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.commonCancel)),
          BeeButton(
              label: l.configExportConfirmTitle,
              onPressed: () => Navigator.pop(context, true))
        ]);
  }
}

class _ImportPreviewDialog extends StatefulWidget {
  const _ImportPreviewDialog(
      {required this.ref,
      required this.yamlContent,
      required this.contentInfo});
  final WidgetRef ref;
  final String yamlContent;
  final ConfigContentInfo contentInfo;
  @override
  State<_ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<_ImportPreviewDialog> {
  late final available = _availableConfig(widget.contentInfo);
  late Set<String> selected = {...available};
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeDialog(
        title: Text(l.configImportPreviewTitle),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BeeStatus(label: l.v4ConfigImportWarning, tone: BeeTone.warning),
              const SizedBox(height: 12),
              BeeConfigurationPreview(
                  content: widget.yamlContent, label: 'YAML', maxHeight: 180),
              const SizedBox(height: 12),
              Text(l.configImportSelectTitle,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              BeeConfigurationOptions(
                  items: _configChoices(l)
                      .where((x) => available.contains(x.id))
                      .toList(),
                  selected: selected,
                  onChanged: (v) => setState(() => selected = v))
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.commonCancel)),
          BeeButton(
              label: l.configImportConfirmTitle,
              onPressed: () => Navigator.pop(context, _configOptions(selected)))
        ]);
  }
}
