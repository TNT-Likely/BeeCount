import '../../presentation/v4/bindings/page_scaffold.dart';
import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/v4/bindings/search_results.dart';
import '../../presentation/v4/bindings/transaction_batch.dart';
import '../../presentation/v4/bindings/transaction_search.dart';
import '../../presentation/v4/bindings/transaction_search_filter.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/category_utils.dart';
import '../../widgets/biz/category_selector_dialog.dart';
import '../tag/widgets/tag_selector.dart';

export '../../presentation/v4/bindings/transaction_search.dart'
    show SearchTransaction;

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage(
      {super.key,
      this.initialBatchMode = false,
      this.initialFilter = const TransactionSearchFilter(),
      this.initialOpenFilter = false});
  final bool initialBatchMode, initialOpenFilter;
  final TransactionSearchFilter initialFilter;
  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _text = TextEditingController();
  TransactionSearchController? _data;
  bool _writing = false, _openedFilter = false;
  @override
  void dispose() {
    _text.dispose();
    _data?.dispose();
    super.dispose();
  }

  void _ensureData(int ledgerId, AppLocalizations l) {
    if (_data?.ledgerId == ledgerId) return;
    _data?.dispose();
    _text.clear();
    _data = TransactionSearchController(
        repository: ref.read(repositoryProvider),
        ledgerId: ledgerId,
        initialBatch: widget.initialBatchMode,
        categoryLabel: (c) =>
            CategoryUtils.displayName(c?.name, l, kind: c?.kind ?? 'expense'));
    _data!.filter = widget.initialFilter;
    unawaited(_data!.start());
    if (widget.initialOpenFilter && !_openedFilter) {
      _openedFilter = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _filters();
      });
    }
  }

  Future<void> _filters() async {
    if (_writing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final c = _data!;
    final filter = await showDialog<TransactionSearchFilter>(
        context: context,
        builder: (_) => TransactionSearchFilterDialog(
            initial: c.filter,
            accounts: c.accounts,
            tags: c.availableTags,
            currency: ref.read(currentLedgerProvider).valueOrNull?.currency ??
                'CNY'));
    if (mounted && identical(_data, c) && filter != null) c.applyFilter(filter);
  }

  Future<void> _write(Future<int> Function() action,
      String Function(int) success, String Function(String) failure) async {
    final c = _data!;
    if (_writing ||
        c.selected.isEmpty ||
        ref.read(currentLedgerIdProvider) != c.ledgerId) {
      return;
    }
    setState(() => _writing = true);
    try {
      final count = await action();
      if (!mounted) return;
      ref.invalidate(countsForLedgerProvider(c.ledgerId));
      ref.read(statsRefreshProvider.notifier).state++;
      ref.read(budgetRefreshProvider.notifier).state++;
      ref.read(tagListRefreshProvider.notifier).state++;
      PostProcessor.sync(ref, ledgerId: c.ledgerId);
      if (mounted && identical(_data, c)) {
        c.afterWrite();
        await c.refresh();
        if (mounted) {
          showBeeToast(context, success(count), tone: BeeTone.success);
        }
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(context, failure(e.toString()), tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _note() async {
    final c = _data!,
        ids = _data!.selected.toList(),
        l = AppLocalizations.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    final note = await showDialog<String>(
        context: context, builder: (_) => _BatchNoteDialog(count: ids.length));
    if (!mounted || !identical(c, _data) || note == null) return;
    await _write(
        () => TransactionBatchBinding(ref.read(repositoryProvider))
            .replaceNotes(
                ledgerId: c.ledgerId, transactionIds: ids, note: note),
        l.searchBatchSetNoteSuccess,
        l.searchBatchSetNoteFailed);
  }

  Future<void> _category() async {
    final c = _data!,
        ids = _data!.selected.toList(),
        l = AppLocalizations.of(context);
    final kinds = c.results
        .where((r) => ids.contains(r.t.id))
        .map((r) => r.t.type)
        .toSet();
    if (kinds.contains('transfer') || kinds.length != 1) {
      showBeeToast(
          context,
          kinds.contains('transfer')
              ? l.searchBatchCategoryTransferError
              : l.searchBatchCategoryTypeError);
      return;
    }
    final category = await showCategorySelector(context,
        type: kinds.single,
        includeParentCategories: false,
        showTransactionCount: true,
        ledgerId: c.ledgerId);
    if (!mounted || !identical(c, _data) || category == null) return;
    await _write(
        () => TransactionBatchBinding(ref.read(repositoryProvider))
            .changeCategory(
                ledgerId: c.ledgerId, transactionIds: ids, category: category),
        l.searchBatchChangeCategorySuccess,
        l.searchBatchChangeCategoryFailed);
  }

  Future<void> _tags() async {
    final c = _data!,
        ids = _data!.selected.toList(),
        l = AppLocalizations.of(context);
    final initial = ids.isEmpty
        ? <int>{}
        : (c.tags[ids.first] ?? []).map((t) => t.id).toSet();
    for (final id in ids.skip(1)) {
      initial.retainAll((c.tags[id] ?? []).map((t) => t.id));
    }
    final tags =
        await TagSelector.show(context, selectedTagIds: initial.toList());
    if (!mounted || !identical(c, _data) || tags == null) return;
    await _write(
        () => TransactionBatchBinding(ref.read(repositoryProvider)).replaceTags(
            ledgerId: c.ledgerId, transactionIds: ids, tagIds: tags),
        (_) => l.v4SearchTagsSaved,
        (error) => '${l.commonError}: $error');
  }

  Future<void> _delete() async {
    final c = _data!,
        ids = _data!.selected.toList(),
        l = AppLocalizations.of(context);
    final confirmed = await showBeeConfirm(context,
        title: l.searchBatchDeleteConfirmTitle,
        message: l.searchBatchDeleteConfirmMessage(ids.length),
        confirmLabel: l.commonDelete,
        cancelLabel: l.commonCancel,
        danger: true);
    if (!mounted || !identical(c, _data) || !confirmed) return;
    await _write(() async {
      final repo = ref.read(repositoryProvider);
      // Check every identity before deleting the first selected row.
      for (final id in ids) {
        if ((await repo.getTransactionById(id))?.ledgerId != c.ledgerId) {
          throw StateError('Batch scope changed');
        }
      }
      for (final id in ids) {
        await repo.deleteTransaction(id);
      }
      return ids.length;
    }, l.searchBatchDeleteSuccess, l.searchBatchDeleteFailed);
  }

  List<Widget> _filterChips(TransactionSearchController c, AppLocalizations l) {
    final f = c.filter;
    final labels = <String, String>{
      if (f.category != null)
        'category': CategoryUtils.displayName(f.category!.name, l,
            kind: f.category!.kind),
      if (f.accountId != null)
        'account':
            c.accounts.where((a) => a.id == f.accountId).firstOrNull?.name ??
                l.exportCsvHeaderAccount,
      if (f.tagId != null)
        'tag':
            c.availableTags.where((t) => t.id == f.tagId).firstOrNull?.name ??
                l.exportCsvHeaderTags,
      if (f.kind != null)
        'kind': f.kind == 'income'
            ? l.exportTypeIncome
            : f.kind == 'expense'
                ? l.exportTypeExpense
                : l.transferTitle,
      if (f.minimum != null || f.maximum != null)
        'amount':
            '${f.basis == SearchAmountBasis.original ? l.v4SearchOriginalAmount : l.v4SearchLedgerAmount}: ${f.minimum ?? 0} — ${f.maximum ?? '∞'}',
      if (f.start != null || f.end != null) 'date': l.searchDateFilter,
    };
    return labels.entries
        .map((e) => BeeChoiceChip(
            compact: true,
            label: e.value,
            selected: false,
            trailing: const BeeLineIcon('X', size: 12),
            onSelected: _writing
                ? null
                : (_) => c.applyFilter(TransactionSearchFilter(
                    category: e.key == 'category' ? null : f.category,
                    accountId: e.key == 'account' ? null : f.accountId,
                    tagId: e.key == 'tag' ? null : f.tagId,
                    kind: e.key == 'kind' ? null : f.kind,
                    basis: f.basis,
                    minimum: e.key == 'amount' ? null : f.minimum,
                    maximum: e.key == 'amount' ? null : f.maximum,
                    start: e.key == 'date' ? null : f.start,
                    end: e.key == 'date' ? null : f.end))))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        ledgerId = ref.watch(currentLedgerIdProvider);
    ref.watch(hideAmountsProvider);
    _ensureData(ledgerId, l);
    final c = _data!;
    return AnimatedBuilder(
        animation: c,
        builder: (context, _) => PopScope(
            canPop: !_writing,
            child: V4PageScaffold(
                backgroundColor: BeeCardTheme.of(context).canvas,
                bottomNavigationBar: !c.batch
                    ? null
                    : BeeBatchActionBar(busy: _writing, actions: [
                        for (final action in [
                          (l.searchBatchSetNote, 'PencilLine', _note),
                          (l.searchBatchChangeCategory, 'Shapes', _category),
                          (l.v4SearchSetTags, 'Tag', _tags),
                          (l.commonDelete, 'Trash2', _delete)
                        ])
                          BeeBatchAction(
                              label: action.$1,
                              icon: BeeLineIcon(action.$2, size: 19),
                              danger: action.$2 == 'Trash2',
                              onPressed: c.selected.isEmpty ? null : action.$3),
                      ]),
                body: Column(children: [
                  BeePageHeader(
                      title: c.batch ? l.searchBatchMode : l.v4SearchTitle,
                      leading: BackButton(
                          onPressed: _writing
                              ? null
                              : () {
                                  if (c.batch && !widget.initialBatchMode) {
                                    c.toggleBatch();
                                  } else {
                                    Navigator.pop(context);
                                  }
                                }),
                      actions: [
                        BeeIconButton(
                            label: c.batch
                                ? l.searchExitBatchMode
                                : l.searchFilterTitle,
                            icon: BeeLineIcon(
                                c.batch ? 'X' : 'SlidersHorizontal',
                                size: 20),
                            onPressed: _writing
                                ? null
                                : c.batch
                                    ? () {
                                        if (widget.initialBatchMode) {
                                          Navigator.pop(context);
                                        } else {
                                          c.toggleBatch();
                                        }
                                      }
                                    : _filters)
                      ]),
                  if (!c.batch)
                    Padding(
                        padding: const EdgeInsets.fromLTRB(17, 0, 17, 8),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              BeeSearchField(
                                  controller: _text,
                                  hint: l.v4SearchHint,
                                  clearLabel: l.commonRemove,
                                  enabled: !_writing,
                                  onChanged: c.search,
                                  onSubmitted: (_) => c.remember()),
                              const SizedBox(height: 8),
                              Wrap(spacing: 6, runSpacing: 6, children: [
                                BeeChoiceChip(
                                    compact: true,
                                    label: l.searchFilterTitle,
                                    selected: false,
                                    leading: const BeeLineIcon(
                                        'SlidersHorizontal',
                                        size: 12),
                                    onSelected:
                                        _writing ? null : (_) => _filters()),
                                ..._filterChips(c, l)
                              ]),
                            ])),
                  Expanded(
                      child: SearchResults(
                          data: c,
                          writing: _writing,
                          onScope: _filters,
                          onQuery: (query) {
                            _text.text = query;
                            c.search(query);
                          },
                          onRetry: () => setState(() {
                                c.dispose();
                                _data = null;
                              }))),
                ]))));
  }
}

class _BatchNoteDialog extends StatefulWidget {
  const _BatchNoteDialog({required this.count});
  final int count;
  @override
  State<_BatchNoteDialog> createState() => _BatchNoteState();
}

class _BatchNoteState extends State<_BatchNoteDialog> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeDialog(
        title: Text(l.searchBatchSetNoteTitle),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.searchBatchSetNoteMessage(widget.count)),
          const SizedBox(height: 16),
          TextField(
              controller: text,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(hintText: l.searchBatchSetNoteHint)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, text.text),
              child: Text(l.commonConfirm))
        ]);
  }
}
