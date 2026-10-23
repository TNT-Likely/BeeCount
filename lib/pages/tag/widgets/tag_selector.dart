import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/tag_providers.dart';
import '../tag_edit_page.dart';

/// Real ledger resources, LRU ordering, creation permissions and draft binding.
class TagSelector extends ConsumerStatefulWidget {
  const TagSelector(
      {super.key, this.selectedTagIds = const [], this.onConfirm});
  final List<int> selectedTagIds;
  final ValueChanged<List<int>>? onConfirm;
  static Future<List<int>?> show(BuildContext context,
          {List<int> selectedTagIds = const []}) =>
      showModalBottomSheet<List<int>>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: BeeCardTheme.of(context).surface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          builder: (_) => TagSelector(selectedTagIds: selectedTagIds));
  @override
  ConsumerState<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends ConsumerState<TagSelector> {
  late Set<int> _selectedIds = {...widget.selectedTagIds};
  Color _color(Tag tag) {
    final hex = tag.color?.replaceFirst('#', '');
    final parsed = hex == null
        ? null
        : int.tryParse(hex.length == 6 ? 'ff$hex' : hex, radix: 16);
    return parsed == null
        ? Theme.of(context).colorScheme.primary
        : Color(parsed);
  }

  BeeTagData _model(Tag tag) => BeeTagData('${tag.id}', tag.name, _color(tag));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(tagsForCurrentLedgerProvider).unwrapPrevious();
    final recent =
        ref.watch(recentTagsForCurrentLedgerProvider).unwrapPrevious();
    final canCreate = ref.watch(canCreateTagForCurrentLedgerProvider);
    final visible = all.valueOrNull?.map((tag) => tag.id).toSet();
    Widget? placeholder;
    if (all.isLoading) {
      placeholder = const Center(
          child: Padding(
              padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    } else if (all.hasError) {
      placeholder = BeeStatus(
          label: l10n.commonError,
          tone: BeeTone.error,
          action: BeeButton(
              label: l10n.v4RecordingRetry,
              onPressed: () => ref.invalidate(tagsForCurrentLedgerProvider)));
    }
    return ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height *
                (MediaQuery.viewInsetsOf(context).bottom > 0 ? .9 : .75)),
        child: BeeSheet(
            title: l10n.tagSelectTitle,
            child: BeeTagPicker(
              compact: MediaQuery.sizeOf(context).height -
                      MediaQuery.viewInsetsOf(context).bottom <
                  500,
              tags: (all.valueOrNull ?? <Tag>[]).map(_model).toList(),
              recent: (recent.valueOrNull ?? <Tag>[])
                  .where((tag) => visible?.contains(tag.id) == true)
                  .map(_model)
                  .toList(),
              recentLabel: l10n.tagSelectRecentlyUsed,
              allLabel: l10n.tagSelectAllTags,
              initial: widget.selectedTagIds.map((id) => '$id').toSet(),
              selection: _selectedIds.map((id) => '$id').toSet(),
              onSelectionChanged: (ids) =>
                  setState(() => _selectedIds = ids.map(int.parse).toSet()),
              searchLabel: l10n.commonSearch,
              selectionLabel: l10n.tagSelectHint,
              clearLabel: l10n.v4ClearSelection,
              confirmLabel: l10n.commonConfirm,
              countLabel: l10n.searchSelectedCount,
              emptyLabel: l10n.tagManageEmpty,
              placeholder: placeholder,
              confirmEnabled: canCreate || visible != null,
              onConfirm: (ids) {
                // Preserve unresolved Owner synthetic IDs; remove old personal IDs
                // that the shared Editor cannot see. The same rule applies after clear.
                final selected = ids
                    .map(int.parse)
                    .where((id) => canCreate || id < 0 || visible!.contains(id))
                    .toList();
                widget.onConfirm?.call(selected);
                Navigator.of(context).pop(selected);
              },
              onCreate: canCreate ? _createNewTag : null,
              createLabel: l10n.tagSelectCreateNew,
              footer: canCreate
                  ? null
                  : Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(l10n.tagSelectOwnerManaged,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).hintColor))),
            )));
  }

  Future<void> _createNewTag() async {
    final tag = await Navigator.push<Tag>(
        context, MaterialPageRoute(builder: (_) => const TagEditPage()));
    if (!mounted) return;
    if (tag != null) setState(() => _selectedIds.add(tag.id));
    ref.read(tagListRefreshProvider.notifier).state++;
  }
}
