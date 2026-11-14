import '../shared/scaffold/widgets/page_scaffold.dart';
import 'dart:async';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart' show Category;
import '../../l10n/app_localizations.dart';
import 'category_detail/bindings/category_detail.dart';
import 'category_detail/widgets/category_detail_sections.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/category_utils.dart';
import '../shared/resources/widgets/detail_period_controls.dart';
import '../category/category_edit_page.dart';
import '../category/category_manage_page.dart';
import 'search_page.dart';
import 'search/bindings/transaction_search.dart';
import '../category/category_migration_page.dart';
import 'transaction_editor_page.dart';

typedef SortType = CategoryDetailSort;
final categoryDetailSortProvider =
    StateProvider.family<CategoryDetailSort, int>(
        (ref, id) => CategoryDetailSort.timeDesc);

class CategoryDetailPage extends ConsumerStatefulWidget {
  const CategoryDetailPage(
      {super.key,
      required this.categoryId,
      required this.categoryName,
      this.startDate,
      this.endDate,
      this.periodLabel,
      this.allLedgers = false});
  final int categoryId;
  final String categoryName;
  final DateTime? startDate, endDate;
  final String? periodLabel;
  final bool allLedgers;
  @override
  ConsumerState<CategoryDetailPage> createState() => _CategoryDetailState();
}

class _CategoryDetailState extends ConsumerState<CategoryDetailPage> {
  CategoryDetailController? _data;
  bool _showAll = false;
  @override
  void dispose() {
    _data?.dispose();
    super.dispose();
  }

  void _ensure(int? ledgerId, int summaryLedgerId) {
    if (_data != null &&
        _data!.ledgerId == ledgerId &&
        _data!.categoryId == widget.categoryId &&
        _data!.initialStart == widget.startDate &&
        _data!.initialEnd == widget.endDate) {
      unawaited(_data!.setSummaryLedger(summaryLedgerId));
      return;
    }
    _data?.dispose();
    _data = CategoryDetailController(
        repository: ref.read(repositoryProvider),
        categoryId: widget.categoryId,
        ledgerId: ledgerId,
        summaryLedgerId: summaryLedgerId,
        initialStart: widget.startDate,
        initialEnd: widget.endDate)
      ..sort = ref.read(categoryDetailSortProvider(widget.categoryId));
    unawaited(_data!.start());
  }

  Future<void> _menu() async {
    final c = _data!, l = AppLocalizations.of(context);
    final category = c.category;
    if (category == null || category.id < 0) return;
    final action = await showBeeSheet<String>(context,
        title: l.categoryDetailTooltip,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!widget.allLedgers)
            BeeMenuRow(
                title: l.searchTitle,
                leading: const BeeLineIcon('Search'),
                onTap: () => Navigator.pop(context, 'search')),
          BeeMenuRow(
              title: l.commonEdit,
              leading: const BeeLineIcon('PencilLine'),
              onTap: () => Navigator.pop(context, 'edit')),
          BeeMenuRow(
              title: l.categoryMigrationTooltip,
              leading: const BeeLineIcon('ArrowLeftRight'),
              onTap: () => Navigator.pop(context, 'move')),
          BeeMenuRow(
              title: l.mineCategoryManagement,
              leading: const BeeLineIcon('Shapes'),
              onTap: () => Navigator.pop(context, 'manage')),
        ]));
    if (!mounted || action == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => switch (action) {
                  'edit' =>
                    CategoryEditPage(category: category, kind: category.kind),
                  'search' => SearchPage(
                      initialFilter: TransactionSearchFilter(
                          category: category,
                          start: c.range.start,
                          end: c.range.end == null
                              ? null
                              : DateTime(c.range.end!.year, c.range.end!.month,
                                  c.range.end!.day - 1))),
                  'manage' => const CategoryManagePage(),
                  _ => CategoryMigrationPage(preselectedFromCategory: category),
                }));
    if (mounted) await c.refreshResources();
  }

  Future<void> _record() async {
    final c = _data!, category = _data!.category;
    if (category == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => TransactionEditorPage(
                initialKind: category.kind, initialCategoryId: category.id)));
    if (mounted) await c.refreshResources();
  }

  Future<void> _child(Category child) async {
    final c = _data!, range = _data!.range;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => CategoryDetailPage(
                categoryId: child.id,
                categoryName: CategoryUtils.getDisplayName(child.name, context,
                    kind: child.kind),
                allLedgers: widget.allLedgers,
                startDate: range.start,
                endDate: range.end,
                periodLabel: widget.periodLabel)));
    if (mounted) await c.refreshResources();
  }

  Future<void> _date() async {
    final c = _data!;
    final chosen = await showResourcePeriodPicker(context,
        period: c.period.name, anchor: c.anchor);
    if (chosen != null && mounted) {
      c.choosePeriod(CategoryDetailPeriod.values.byName(chosen.period),
          anchor: chosen.anchor);
    }
  }

  Future<void> _delete(int id, int ledgerId) async {
    final l = AppLocalizations.of(context);
    try {
      final repo = ref.read(repositoryProvider);
      final row = await repo.getTransactionById(id);
      if (row == null || row.ledgerId != ledgerId) {
        throw StateError('Transaction scope changed');
      }
      await repo.deleteTransaction(id);
      ref.invalidate(countsForLedgerProvider(ledgerId));
      ref.read(statsRefreshProvider.notifier).state++;
      ref.read(budgetRefreshProvider.notifier).state++;
      PostProcessor.sync(ref, ledgerId: ledgerId);
    } catch (e) {
      if (mounted) {
        showBeeToast(context, '${l.categoryDetailDeleteFailed}: $e',
            tone: BeeTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        ledgerId = ref.watch(currentLedgerIdProvider);
    _ensure(widget.allLedgers ? null : ledgerId, ledgerId);
    ref.listen(rateRefreshTickProvider,
        (_, __) => unawaited(_data?.refreshResources()));
    ref.listen(
        statsRefreshProvider, (_, __) => unawaited(_data?.refreshResources()));
    ref.listen(syncGenerationProvider,
        (_, __) => unawaited(_data?.refreshResources()));
    ref.listen(currentLedgerProvider, (previous, next) {
      if (previous?.valueOrNull?.currency != next.valueOrNull?.currency) {
        unawaited(_data?.refreshResources());
      }
    });
    final c = _data!;
    return AnimatedBuilder(
        animation: c,
        builder: (context, _) => V4PageScaffold(
            backgroundColor: BeeCardTheme.of(context).canvas,
            body: Column(children: [
              BeePageHeader(
                  title: l.categoryDetailTooltip,
                  leading: const BackButton(),
                  actions: [
                    BeeIconButton(
                        label: l.commonMore,
                        icon: const BeeLineIcon('Ellipsis'),
                        onPressed: c.category == null || c.category!.id < 0
                            ? null
                            : _menu)
                  ]),
              if (c.category != null)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    child: Column(children: [
                      BeeCompactTabs<CategoryDetailPeriod>(
                          value: c.period,
                          trackHeight: 32,
                          tapHeight: 44,
                          items: [
                            BeeSegment(
                                CategoryDetailPeriod.month, l.v4DetailMonth),
                            BeeSegment(
                                CategoryDetailPeriod.year, l.v4DetailYear),
                            BeeSegment(
                                CategoryDetailPeriod.all, l.analyticsAll),
                            if (c.period == CategoryDetailPeriod.custom)
                              BeeSegment(CategoryDetailPeriod.custom,
                                  l.v4DetailCustom),
                          ],
                          onChanged: (value) {
                            setState(() => _showAll = false);
                            c.choosePeriod(value);
                          }),
                      if (c.period != CategoryDetailPeriod.all)
                        BeeDateRangeBar(
                            label: c.period == CategoryDetailPeriod.custom
                                ? widget.periodLabel ?? l.v4DetailCustom
                                : detailRangeLabel(
                                    context, c.period.name, c.anchor),
                            onChoose: _date,
                            previousLabel: c.period == CategoryDetailPeriod.month ||
                                    c.period == CategoryDetailPeriod.year
                                ? MaterialLocalizations.of(context)
                                    .previousMonthTooltip
                                : null,
                            nextLabel: c.period == CategoryDetailPeriod.month ||
                                    c.period == CategoryDetailPeriod.year
                                ? MaterialLocalizations.of(context)
                                    .nextMonthTooltip
                                : null,
                            onPrevious: () => c.chooseAnchor(c.period == CategoryDetailPeriod.year
                                ? DateTime(c.anchor.year - 1, c.anchor.month)
                                : DateTime(c.anchor.year, c.anchor.month - 1)),
                            onNext: () => c.chooseAnchor(
                                c.period == CategoryDetailPeriod.year
                                    ? DateTime(c.anchor.year + 1, c.anchor.month)
                                    : DateTime(c.anchor.year, c.anchor.month + 1))),
                    ])),
              const SizedBox(height: 8),
              Expanded(
                  child: c.loading
                      ? const Center(child: CircularProgressIndicator())
                      : c.error != null
                          ? Center(
                              child: BeeStatus(
                                  label: l.commonError,
                                  tone: BeeTone.error,
                                  action: BeeButton(
                                      label: l.v4RecordingRetry,
                                      onPressed: () => setState(() {
                                            c.dispose();
                                            _data = null;
                                          }))))
                          : c.category == null
                              ? Center(
                                  child: BeeEmptyState(
                                      title: l.v4DetailMissingCategory))
                              : CategoryDetailSections(
                                  data: c,
                                  allLedgers: widget.allLedgers,
                                  periodLabel: widget.periodLabel,
                                  showAll: _showAll,
                                  onShowAll: () =>
                                      setState(() => _showAll = !_showAll),
                                  onChild: _child,
                                  onRecord: _record,
                                  onSort: (value) {
                                    ref
                                        .read(categoryDetailSortProvider(
                                                widget.categoryId)
                                            .notifier)
                                        .state = value;
                                    c.chooseSort(value);
                                  },
                                  onDelete: _delete)),
            ])));
  }
}
