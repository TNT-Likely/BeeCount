import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db.dart';
import '../../../data/repositories/local/local_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/category/category_edit_page.dart';
import '../../../pages/category/category_manage_page.dart';
import '../../../providers.dart';
import '../../../providers/shared_ledger_providers.dart';
import '../../../utils/category_utils.dart';
import '../../../utils/shared_ledger_picker_filter.dart';
import 'recording_category_icon.dart';

final recordingCategoriesProvider = FutureProvider.autoDispose
    .family<List<Category>, ({int ledgerId, String kind})>((ref, query) async {
  ref.watch(sharedResourceRefreshProvider);
  ref.watch(syncGenerationProvider);
  final repo = ref.watch(repositoryProvider);
  final all = (await repo.getAllCategories())
      .where((category) => category.kind == query.kind)
      .toList();
  if (repo is! LocalRepository) return all;
  final scope = await repo.db.loadLedgerPickerContext(query.ledgerId);
  return repo.db.filterCategoriesForLedger(all, scope,
      kind: query.kind, topLevelOnly: false);
});

/// App binding: shared-ledger filtering and image resolution stay outside the UI package.
class RecordingCategorySection extends ConsumerStatefulWidget {
  const RecordingCategorySection(
      {super.key,
      required this.ledgerId,
      required this.kind,
      required this.selectedId,
      required this.onSelected,
      this.showAll = false});
  final int ledgerId;
  final String kind;
  final int? selectedId;
  final ValueChanged<Category> onSelected;
  final bool showAll;

  @override
  ConsumerState<RecordingCategorySection> createState() =>
      _RecordingCategorySectionState();
}

class _RecordingCategorySectionState
    extends ConsumerState<RecordingCategorySection> {
  int? _expandedId;
  final _childScroll = ScrollController();
  int? _revealedParent, _revealedChild;

  @override
  void dispose() {
    _childScroll.dispose();
    super.dispose();
  }

  void _revealChild(int parentId, List<Category> items, int columns) {
    if (_revealedParent == parentId && _revealedChild == widget.selectedId) {
      return;
    }
    _revealedParent = parentId;
    _revealedChild = widget.selectedId;
    final index = items.indexWhere((c) => c.id == widget.selectedId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_childScroll.hasClients) return;
      final offset = ((index < 0 ? 0 : index ~/ columns) - 1) * 48.0;
      _childScroll
          .jumpTo(offset.clamp(0, _childScroll.position.maxScrollExtent));
    });
  }

  @override
  void didUpdateWidget(covariant RecordingCategorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.ledgerId != widget.ledgerId) {
      _expandedId = null;
    }
  }

  Future<void> _manage({bool create = false}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => create
            ? CategoryEditPage(kind: widget.kind)
            : CategoryManagePage(
                initialTabIndex: widget.kind == 'expense' ? 0 : 1)));
    if (mounted) {
      ref.invalidate(recordingCategoriesProvider(
          (ledgerId: widget.ledgerId, kind: widget.kind)));
    }
  }

  Future<void> _more() async {
    final result = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BeeCardTheme.of(context).canvas,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          AppLocalizations.of(context)
                              .v4RecordingMoreCategories,
                          style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                      tooltip: AppLocalizations.of(context).commonClose,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ])),
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: RecordingCategorySection(
                        ledgerId: widget.ledgerId,
                        kind: widget.kind,
                        selectedId: widget.selectedId,
                        showAll: true,
                        onSelected: (category) =>
                            Navigator.pop(context, category)))),
          ])),
    );
    if (result != null && mounted) {
      setState(() => _expandedId = result.parentId ?? result.id);
      widget.onSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = (ledgerId: widget.ledgerId, kind: widget.kind);
    return ref.watch(recordingCategoriesProvider(query)).when(
          loading: () => const BeeSurface(
              child: Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator()))),
          error: (error, stack) => BeeSurface(
              child: Column(children: [
            Text(l10n.v4RecordingCategoriesFailed),
            TextButton(
                onPressed: () =>
                    ref.invalidate(recordingCategoriesProvider(query)),
                child: Text(l10n.v4RecordingRetry)),
          ])),
          data: (all) {
            final parents =
                all.where((category) => category.level == 1).toList();
            if (parents.isEmpty) {
              return BeeSurface(
                  child: Column(children: [
                Text(l10n.categoryEmpty),
                TextButton.icon(
                    onPressed: () => _manage(create: true),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.categoryNew)),
              ]));
            }
            final selected = all
                .where((category) => category.id == widget.selectedId)
                .firstOrNull;
            final activeParent = selected?.parentId ?? selected?.id;
            final expanded = _expandedId ??
                (selected?.level == 2 ? selected?.parentId : null);
            var visible = widget.showAll ? parents : parents.take(7).toList();
            if (!widget.showAll &&
                activeParent != null &&
                !visible.any((c) => c.id == activeParent)) {
              final parent =
                  parents.where((c) => c.id == activeParent).firstOrNull;
              if (parent != null) visible = [...visible.take(6), parent];
            }

            Widget tile(Category category, {bool child = false}) {
              final hasChildren = all.any((c) => c.parentId == category.id);
              final selected = widget.selectedId == category.id ||
                  (!child && activeParent == category.id);
              return RecordingCategoryTile(
                  key: ValueKey('recording-category-${category.id}'),
                  label: CategoryUtils.getDisplayName(category.name, context),
                  selected: selected,
                  hasChildren: hasChildren,
                  expanded: expanded == category.id,
                  icon: RecordingCategoryIcon(
                      category: category,
                      size: 18,
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface),
                  onTap: () {
                    if (hasChildren && widget.showAll) {
                      setState(() => _expandedId =
                          expanded == category.id ? null : category.id);
                    } else {
                      if (hasChildren) {
                        setState(() => _expandedId =
                            expanded == category.id ? null : category.id);
                      }
                      widget.onSelected(category);
                    }
                  });
            }

            final entries = <Widget>[...visible.map(tile)];
            if (!widget.showAll) {
              entries.add(RecordingCategoryTile(
                  key: const ValueKey('recording-more-categories'),
                  label: l10n.v4RecordingMoreCategories,
                  icon: const BeeLineIcon('Grid2x2', size: 18),
                  onTap: _more));
            }
            final rows = <Widget>[];
            for (var i = 0; i < entries.length; i += 4) {
              rows.add(Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                      4,
                      (offset) => Expanded(
                          child: i + offset < entries.length
                              ? entries[i + offset]
                              : const SizedBox.shrink()))));
              final rowParents = visible.skip(i).take(4);
              if (expanded != null &&
                  rowParents.any((category) => category.id == expanded)) {
                final parent = parents
                    .where((category) => category.id == expanded)
                    .firstOrNull;
                final children = all
                    .where((category) => category.parentId == expanded)
                    .toList();
                if (parent != null && children.isNotEmpty) {
                  rows.add(Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: BeeCardTheme.of(context).soft,
                        borderRadius: BorderRadius.circular(16)),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final items = [parent, ...children];
                      final columns = constraints.maxWidth < 270 ? 2 : 4;
                      final content = Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: items
                              .map((category) => SizedBox(
                                    width: (constraints.maxWidth -
                                            (columns - 1) * 4) /
                                        columns,
                                    height: 44,
                                    child: Tooltip(
                                      message: CategoryUtils.getDisplayName(
                                          category.name, context),
                                      child: RecordingSubcategoryChip(
                                        key: ValueKey(
                                            'recording-category-${category.id}'),
                                        label: CategoryUtils.getDisplayName(
                                            category.name, context),
                                        icon: RecordingCategoryIcon(
                                            category: category,
                                            size: 18,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface),
                                        selected:
                                            widget.selectedId == category.id,
                                        onTap: () =>
                                            widget.onSelected(category),
                                      ),
                                    ),
                                  ))
                              .toList());
                      if (widget.showAll) return content;
                      _revealChild(parent.id, items, columns);
                      // Two touch-sized rows; large taxonomies do not grow the
                      // main editor. The full picker stays freely expandable.
                      return ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 92),
                          child: Scrollbar(
                              controller: _childScroll,
                              thumbVisibility: items.length > columns * 2,
                              child: SingleChildScrollView(
                                  key: const ValueKey(
                                      'recording-subcategories-scroll'),
                                  controller: _childScroll,
                                  child: content)));
                    }),
                  ));
                }
              }
            }
            if (widget.showAll) {
              rows.add(TextButton.icon(
                  onPressed: _manage,
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(l10n.mineCategoryManagement)));
            }
            return BeeSurface(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: rows));
          },
        );
  }
}
