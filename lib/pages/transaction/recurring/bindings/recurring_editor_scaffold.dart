import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';

/// The original App editor frame, shared by local and Cloud rules.
class RecurringEditorScaffold extends StatelessWidget {
  const RecurringEditorScaffold({
    super.key,
    required this.editing,
    required this.saving,
    required this.editor,
    this.onSave,
    this.onDelete,
    this.saveLabel,
  });

  final bool editing, saving;
  final Widget editor;
  final VoidCallback? onSave, onDelete;
  final String? saveLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeePageHeader(
          title:
              editing ? l.recurringTransactionEdit : l.recurringTransactionAdd,
          leading: const BackButton(),
          actions: [
            if (editing)
              BeeIconButton(
                  label: l.commonDelete,
                  icon: const BeeLineIcon('Trash2'),
                  onPressed: saving ? null : onDelete),
          ]),
      Expanded(child: editor),
      SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 8, 17, 12),
              child: BeeButton(
                  key: const ValueKey('recurring-editor-save'),
                  label: saveLabel ?? l.commonSave,
                  icon: const BeeLineIcon('Check', size: 18),
                  loading: saving,
                  onPressed: saving ? null : onSave))),
    ]));
  }
}
