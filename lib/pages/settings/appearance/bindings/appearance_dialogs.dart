import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/note_history.dart';
import '../../../../providers/theme_providers.dart';

/// Same immediate choice + dismiss contract as the original appearance dialogs.
Future<T?> showAppearanceChoice<T>(BuildContext context,
    {required String title,
    required T selected,
    required List<({T value, String title, String? subtitle, String icon})>
        options}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .26),
      builder: (dialog) => BeeDialog(
          title: Text(title),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final option in options)
              BeeMenuRow(
                  title: option.title,
                  subtitle: option.subtitle,
                  leading: BeeLineIcon(option.icon),
                  selected: option.value == selected,
                  trailing: option.value == selected
                      ? null
                      : const SizedBox(width: 18),
                  onTap: () => Navigator.pop(dialog, option.value)),
          ])));
}

String noteHistorySummary(WidgetRef ref, AppLocalizations l) {
  final scope = ref.watch(noteHistoryScopeProvider),
      sort = ref.watch(noteHistorySortProvider),
      limit = ref.watch(noteHistoryLimitProvider);
  return '${scope == NoteHistoryScope.currentCategory ? l.appearanceNoteHistoryScopeCurrentCategory : l.appearanceNoteHistoryScopeAllCategories} · ${sort == NoteHistorySort.recent ? l.appearanceNoteHistorySortRecent : l.appearanceNoteHistorySortFrequency} · ${l.appearanceNoteHistoryLimit} $limit';
}

Future<void> showNoteHistoryPreferences(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .26),
      builder: (_) => const _NoteHistoryDialog());
}

class _NoteHistoryDialog extends ConsumerStatefulWidget {
  const _NoteHistoryDialog();
  @override
  ConsumerState<_NoteHistoryDialog> createState() => _NoteHistoryDialogState();
}

class _NoteHistoryDialogState extends ConsumerState<_NoteHistoryDialog> {
  bool invalid = false;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeDialog(
        title: Text(l.appearanceNoteHistory),
        content: NoteHistoryPreferencesView(
            limitError: invalid ? l.appearanceNoteHistoryLimitInvalid : null,
            onLimit: (text) {
              final value = int.tryParse(text);
              final valid = value != null &&
                  value >= noteHistoryMinLimit &&
                  value <= noteHistoryMaxLimit;
              setState(() => invalid = !valid);
              if (valid) {
                ref.read(noteHistoryLimitProvider.notifier).state = value;
              }
            }),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.commonClose))
        ]);
  }
}

/// Original preferences, shared by the production dialog and live gallery.
/// All radio changes and valid limits persist immediately, including on Close.
class NoteHistoryPreferencesView extends ConsumerWidget {
  const NoteHistoryPreferencesView(
      {super.key, this.readOnly = false, this.limitError, this.onLimit});
  final bool readOnly;
  final String? limitError;
  final ValueChanged<String>? onLimit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return BeeNoteHistoryPreferences(
        scopeLabel: l.appearanceNoteHistoryScope,
        scopeOptions: [
          l.appearanceNoteHistoryScopeAllCategories,
          l.appearanceNoteHistoryScopeCurrentCategory
        ],
        selectedScope: ref.watch(noteHistoryScopeProvider).index,
        onScope: readOnly
            ? null
            : (i) => ref.read(noteHistoryScopeProvider.notifier).state =
                NoteHistoryScope.values[i],
        sortLabel: l.appearanceNoteHistorySort,
        sortOptions: [
          l.appearanceNoteHistorySortFrequency,
          l.appearanceNoteHistorySortRecent
        ],
        selectedSort: ref.watch(noteHistorySortProvider).index,
        onSort: readOnly
            ? null
            : (i) => ref.read(noteHistorySortProvider.notifier).state =
                NoteHistorySort.values[i],
        limitLabel: l.appearanceNoteHistoryLimit,
        limitHint: l.appearanceNoteHistoryLimitHint,
        limit: ref.watch(noteHistoryLimitProvider).toString(),
        limitError: limitError,
        onLimit: readOnly ? null : onLimit);
  }
}
