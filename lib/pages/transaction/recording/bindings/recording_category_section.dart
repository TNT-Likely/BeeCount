import 'dart:async';
import 'dart:math' as math;

import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/db.dart';
import '../../../../data/repositories/local/local_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../category/category_edit_page.dart';
import '../../../category/category_manage_page.dart';
import '../../../../providers.dart';
import '../../../../providers/shared_ledger_providers.dart';
import '../../../../utils/category_utils.dart';
import '../../../../utils/shared_ledger_picker_filter.dart';
import '../../../shared/resources/bindings/recording_category_icon.dart';

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

/// Compact presentation when the viewport cannot accommodate a full grid tile.
class RecordingMoreCategoriesButton extends StatelessWidget {
  const RecordingMoreCategoriesButton({super.key, required this.onPressed});

  final VoidCallback onPressed;
  static const height = 44.0;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).v4RecordingMoreCategories;
    return SizedBox(
      width: 80,
      height: height,
      child: Tooltip(
        message: label,
        child: InkWell(
          key: const ValueKey('recording-more-categories'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: BeeCardTheme.of(context).soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: BeeLineIcon('Grid2x2', size: 16)),
              ),
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      ),
    );
  }
}

/// App binding: shared-ledger filtering and image resolution stay outside the UI package.
class RecordingCategorySection extends ConsumerStatefulWidget {
  const RecordingCategorySection(
      {super.key,
      required this.ledgerId,
      required this.kind,
      required this.selectedId,
      required this.onSelected,
      this.moreInDetails,
      this.showAll = false});
  final int ledgerId;
  final String kind;
  final int? selectedId;
  final ValueChanged<Category> onSelected;
  final ValueNotifier<VoidCallback?>? moreInDetails;
  final bool showAll;

  @override
  ConsumerState<RecordingCategorySection> createState() =>
      _RecordingCategorySectionState();
}

class _RecordingCategorySectionState
    extends ConsumerState<RecordingCategorySection> {
  int? _expandedId;
  bool _hasExpansionOverride = false;
  final _childScroll = ScrollController();
  final _selectedChildAnchor = GlobalKey();
  int? _revealedParent, _revealedChild;
  bool _fallbackPending = false;
  VoidCallback? _detailsAction;

  void _placeMoreInDetails(bool show) {
    final target = widget.moreInDetails;
    if (target == null) return;
    _detailsAction = show ? _more : null;
    if (_fallbackPending || target.value == _detailsAction) return;
    // LayoutBuilder runs during layout. Update the sibling after this frame.
    _fallbackPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fallbackPending = false;
      if (mounted && widget.moreInDetails == target) {
        target.value = _detailsAction;
      }
    });
  }

  @override
  void dispose() {
    _childScroll.dispose();
    super.dispose();
  }

  void _revealChild(int parentId) {
    if (_revealedParent == parentId && _revealedChild == widget.selectedId) {
      return;
    }
    _revealedParent = parentId;
    _revealedChild = widget.selectedId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _selectedChildAnchor.currentContext;
      if (target == null) return;
      unawaited(Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 180),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd));
    });
  }

  @override
  void didUpdateWidget(covariant RecordingCategorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.ledgerId != widget.ledgerId) {
      _expandedId = null;
      _hasExpansionOverride = false;
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

  Future<void> _more({int? initialParent}) async {
    final l10n = AppLocalizations.of(context);
    final query = (ledgerId: widget.ledgerId, kind: widget.kind);
    final result = await showBeeSheet<Category>(
      context,
      title: l10n.v4RecordingMoreCategories,
      child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Consumer(
              builder: (sheetContext, ref, _) => ref
                  .watch(recordingCategoriesProvider(query))
                  .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => BeeStatus(
                          label: l10n.v4RecordingCategoriesFailed,
                          tone: BeeTone.error,
                          action: BeeButton(
                              label: l10n.v4RecordingRetry,
                              onPressed: () => ref.invalidate(
                                  recordingCategoriesProvider(query)))),
                      data: (all) {
                        BeeCategoryChoice choice(Category category,
                                {bool withChildren = false}) =>
                            BeeCategoryChoice(
                                id: '${category.id}',
                                label: CategoryUtils.getDisplayName(
                                    category.name, context),
                                icon: RecordingCategoryIcon(
                                    category: category, size: 18),
                                enabled:
                                    !all.any((c) => c.parentId == category.id),
                                children: withChildren
                                    ? all
                                        .where((c) => c.parentId == category.id)
                                        .map((c) => choice(c))
                                        .toList()
                                    : const []);
                        return Column(children: [
                          Expanded(
                              child: BeeCategoryPicker(
                                  items: all
                                      .where((c) => c.level == 1)
                                      .map((c) => choice(c, withChildren: true))
                                      .toList(),
                                  selected: widget.selectedId?.toString(),
                                  initialParent: initialParent?.toString(),
                                  searchLabel: l10n.searchCategoryHint,
                                  emptyLabel: l10n.categoryEmpty,
                                  confirmLabel: l10n.commonConfirm,
                                  cancelLabel: l10n.commonCancel,
                                  onConfirm: (id) => Navigator.pop(sheetContext,
                                      all.firstWhere((c) => '${c.id}' == id)),
                                  onCancel: () => Navigator.pop(sheetContext))),
                          TextButton.icon(
                              onPressed: _manage,
                              icon: const BeeLineIcon('SlidersHorizontal',
                                  size: 18),
                              label: Text(l10n.mineCategoryManagement)),
                        ]);
                      }))),
    );
    if (result != null && mounted) {
      setState(() {
        _expandedId = result.parentId;
        _hasExpansionOverride = true;
      });
      widget.onSelected(result);
    }
  }

  Widget _categoryGrid(
    BuildContext context,
    BoxConstraints box,
    List<Category> all,
    List<Category> parents,
    bool narrow,
  ) {
    const horizontalPadding = 13.0;
    const childPadding = 8.0;
    const childGap = 6.0;
    const childChrome = 2 * (childGap + childPadding);
    final l10n = AppLocalizations.of(context);
    final selected = all.where((c) => c.id == widget.selectedId).firstOrNull;
    final activeParent = selected?.parentId ?? selected?.id;
    final expandedId = _hasExpansionOverride ? _expandedId : selected?.parentId;
    final expandedParent = parents.where((c) => c.id == expandedId).firstOrNull;
    final childrenByParent = <int, List<Category>>{};
    for (final category in all) {
      final parentId = category.parentId;
      if (parentId != null) {
        childrenByParent.putIfAbsent(parentId, () => []).add(category);
      }
    }
    String label(Category category) =>
        CategoryUtils.getDisplayName(category.name, context);
    final children = childrenByParent[expandedParent?.id] ?? const [];
    final childChoices = children
        .map((category) => BeeCategoryChoice(
              id: category.id.toString(),
              label: label(category),
              enabled: !childrenByParent.containsKey(category.id),
              icon: RecordingCategoryIcon(
                category: category,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ))
        .toList();
    final verticalPadding = narrow ? 2.0 : 10.0;
    final width = math.max(0.0, box.maxWidth - 2 * horizontalPadding);
    final bound = !widget.showAll && box.hasBoundedHeight;
    final height = box.maxHeight - 2 * verticalPadding;
    var rowHeight = RecordingCategoryTile.heightFor(
        context, l10n.v4RecordingMoreCategories,
        width: width / 4, compact: narrow);
    for (final parent in parents) {
      rowHeight = math.max(
        rowHeight,
        RecordingCategoryTile.heightFor(context, label(parent),
            width: width / 4,
            compact: narrow,
            selected: parent.id == activeParent),
      );
    }
    rowHeight = rowHeight.ceilToDouble();

    if (bound && height < rowHeight) {
      final inDetails = box.maxHeight < RecordingMoreCategoriesButton.height;
      _placeMoreInDetails(inDetails);
      return inDetails
          ? const SizedBox.shrink()
          : Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Align(
                alignment: Alignment.bottomRight,
                child: RecordingMoreCategoriesButton(onPressed: _more),
              ),
            );
    }
    _placeMoreInDetails(false);

    final childRoom = height - rowHeight - childChrome;
    final canExpand =
        !bound || childRoom >= RecordingSubcategoryGrid.minimumItemHeight;
    final showChildren = canExpand && childChoices.isNotEmpty;
    final childHeight = !showChildren || !bound
        ? 0.0
        : math.min(
            math.min(154.0, childRoom),
            RecordingSubcategoryGrid.recordingHeightFor(
                    context,
                    childChoices,
                    math.max(0.0, width - 2 * childPadding),
                    widget.selectedId?.toString())
                .ceilToDouble(),
          );
    final capacity = bound
        ? 4 *
                math
                    .max(
                        1,
                        ((height -
                                    (showChildren
                                        ? childChrome + childHeight
                                        : 0)) /
                                rowHeight)
                            .floor())
                    .toInt() -
            1
        : parents.length;
    final visible = parents.take(capacity).toList();
    final keep = {activeParent, if (showChildren) expandedParent?.id};
    for (final parent in parents.where((c) => keep.contains(c.id))) {
      if (visible.contains(parent)) continue;
      final index = visible.lastIndexWhere((c) => !keep.contains(c.id));
      if (index >= 0) visible[index] = parent;
    }

    Widget tile(Category category) {
      final selected = activeParent == category.id;
      final hasChildren = childrenByParent.containsKey(category.id);
      return RecordingCategoryTile(
        compact: narrow,
        key: ValueKey('recording-category-${category.id}'),
        label: label(category),
        selected: selected,
        hasChildren: hasChildren,
        expanded: showChildren && expandedParent?.id == category.id,
        icon: RecordingCategoryIcon(
          category: category,
          size: 18,
          color: selected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
        ),
        onTap: () {
          if (!hasChildren) {
            widget.onSelected(category);
          } else if (!canExpand) {
            unawaited(_more(initialParent: category.id));
          } else {
            setState(() {
              _expandedId = expandedId == category.id ? null : category.id;
              _hasExpansionOverride = true;
            });
          }
        },
      );
    }

    Widget childGroup() {
      final content = RecordingSubcategoryGrid(
        items: childChoices,
        selected: widget.selectedId?.toString(),
        selectedAnchorKey: _selectedChildAnchor,
        onSelected: (id) => widget
            .onSelected(children.firstWhere((c) => c.id.toString() == id)),
      );
      if (!widget.showAll) _revealChild(expandedParent!.id);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: childGap),
        padding: const EdgeInsets.all(childPadding),
        decoration: BoxDecoration(
          color: BeeCardTheme.of(context).soft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: widget.showAll
            ? content
            : ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: bound ? childHeight : 154),
                child: Scrollbar(
                  controller: _childScroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    key: const ValueKey('recording-subcategories-scroll'),
                    controller: _childScroll,
                    child: content,
                  ),
                ),
              ),
      );
    }

    final entries = [
      ...visible.map(tile),
      if (!widget.showAll)
        RecordingCategoryTile(
          compact: narrow,
          key: const ValueKey('recording-more-categories'),
          label: l10n.v4RecordingMoreCategories,
          icon: const BeeLineIcon('Grid2x2', size: 18),
          onTap: _more,
        ),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += 4) {
      final row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          4,
          (offset) => Expanded(
              child: i + offset < entries.length
                  ? entries[i + offset]
                  : const SizedBox.shrink()),
        ),
      );
      rows.add(bound ? SizedBox(height: rowHeight, child: row) : row);
      if (showChildren &&
          visible.skip(i).take(4).any((c) => c.id == expandedParent?.id)) {
        rows.add(childGroup());
      }
    }
    return BeeSurface(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...rows,
          if (widget.showAll)
            TextButton.icon(
              onPressed: _manage,
              icon: const Icon(Icons.tune, size: 18),
              label: Text(l10n.mineCategoryManagement),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final narrow = MediaQuery.sizeOf(context).width <= 340 &&
        MediaQuery.sizeOf(context).height -
                MediaQuery.viewPaddingOf(context).vertical <
            720;
    final query = (ledgerId: widget.ledgerId, kind: widget.kind);
    return ref.watch(recordingCategoriesProvider(query)).when(
      loading: () {
        _placeMoreInDetails(false);
        return const BeeSurface(
            child: Center(child: CircularProgressIndicator()));
      },
      error: (_, __) {
        _placeMoreInDetails(false);
        return BeeSurface(
          child: SingleChildScrollView(
            child: Column(children: [
              Text(l10n.v4RecordingCategoriesFailed),
              TextButton(
                onPressed: () =>
                    ref.invalidate(recordingCategoriesProvider(query)),
                child: Text(l10n.v4RecordingRetry),
              ),
            ]),
          ),
        );
      },
      data: (all) {
        final parents = all.where((category) => category.level == 1).toList();
        if (parents.isEmpty) {
          _placeMoreInDetails(false);
          return BeeSurface(
            child: SingleChildScrollView(
              child: Column(children: [
                Text(l10n.categoryEmpty),
                TextButton.icon(
                  onPressed: () => _manage(create: true),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.categoryNew),
                ),
              ]),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, box) =>
              _categoryGrid(context, box, all, parents, narrow),
        );
      },
    );
  }
}
