import 'dart:convert';

import 'package:agentcore/agentcore.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../agent/tools/local_agent_tools.dart';
import '../../../../agent/tools/ledger_query_snapshot.dart';
import '../../../../services/data/category_service.dart';
import '../../../../utils/currencies.dart';
import '../../../../utils/format_money.dart';
import '../../../shared/transactions/transaction_list_item.dart';
import '../../../transaction/transaction_detail_page.dart';
import '../../../../data/db.dart' show Category;
import '../../../../l10n/app_localizations.dart';
import '../../../../providers.dart';
import '../../../../providers/ai_chat_providers.dart';
import '../../../../utils/category_utils.dart';
import '../../../shared/transactions/bindings/transaction_list_metadata.dart';
import '../../../shared/transactions/bindings/transaction_tile.dart';
import '../../../transaction/search/bindings/transaction_search.dart';

/// Shows the values observed by the tool. Older answers can explicitly look
/// up today's bills using the saved filters.
class LedgerEvidenceSheet extends ConsumerStatefulWidget {
  const LedgerEvidenceSheet(
      {super.key, required this.ledgerId, required this.queries});
  final int ledgerId;
  final List<Map<String, Object?>> queries;

  static Future<void> show(
    BuildContext context, {
    required int ledgerId,
    required List<Map<String, Object?>> queries,
  }) async {
    if (queries.isEmpty) return;
    // The page wraps its cards in a local Theme. Present this opaque sheet
    // from the navigator so its rows keep following the live app theme.
    await showBeeSheet<void>(Navigator.of(context).context,
        title: AppLocalizations.of(context).agentEvidenceBills,
        child: LedgerEvidenceSheet(ledgerId: ledgerId, queries: queries));
  }

  static List<Map<String, Object?>> forMessage(String? metadata, int ledgerId) {
    if (metadata == null) return const [];
    try {
      final decoded = jsonDecode(metadata);
      if (decoded is! Map || decoded['contextLedgerId'] != ledgerId) {
        return const [];
      }
      final context = decoded['queryContext'];
      if (context is! Map ||
          context['displayRefs'] is! List ||
          context['queries'] is! List) {
        return const [];
      }
      return (context['queries'] as List)
          .whereType<Map>()
          .where((query) =>
              query['ledgerId'] == ledgerId &&
              query['filters'] is Map &&
              (context['displayRefs'] as List).contains(query['ref']))
          .map((query) {
        final snapshots = context['snapshots'];
        return <String, Object?>{
          ...(Map<String, Object?>.from(query)..remove('snapshot')),
          if (snapshots is Map && snapshots.containsKey(query['ref']))
            'snapshot': snapshots[query['ref']],
        };
      }).toList();
    } on FormatException {
      return const [];
    }
  }

  @override
  ConsumerState<LedgerEvidenceSheet> createState() =>
      _LedgerEvidenceSheetState();
}

typedef _EvidencePage = ({
  List<SearchTransaction> rows,
  TransactionListMetadata metadata,
  String currency,
  int count,
  String? next,
});

class _LedgerEvidenceSheetState extends ConsumerState<LedgerEvidenceSheet> {
  int _selection = 0;
  String? _cursor;
  Future<_EvidencePage>? _page;
  bool _lookupCurrent = false;
  int _frozenPage = 0;

  Map<String, Object?> get _query => widget.queries[_selection];

  Future<_EvidencePage> _load() async {
    final ledgerId = widget.ledgerId;
    final repo = ref.read(repositoryProvider);
    final database = ref.read(databaseProvider);
    final queryRef = widget.queries[_selection]['ref'];
    final cursor = _cursor;
    final tools = LocalAgentTools(
      scope: AgentScope(
          id: 'bill-evidence', ledgerId: ledgerId, allowsMutations: false),
      gateway: ref.read(localAgentToolGatewayProvider),
      previous: widget.queries,
      captureEvidence: false,
    ).build();
    // Keep the filters, total and hydrated display fields on one SQLite snapshot.
    return database.transaction(() async {
      final result = await tools['query_transactions']!.execute(
        AgentToolCall(name: 'query_transactions', arguments: {
          'baseQuery': queryRef,
          if (cursor != null) 'cursor': cursor,
        }),
      );
      if (result.containsKey('error') ||
          ['unmatched', 'ambiguous'].contains(result['matchStatus'])) {
        throw StateError('Evidence query no longer resolves');
      }
      // The query owns the order and scope. The App's joined rows also carry
      // local custom icons, full notes, tag colors and attachment counts.
      final ids = [
        for (final row in (result['items'] as List).cast<Map>())
          row['id'] as int
      ];
      final (bills, metadata) = await (
        repo.getTransactionsWithCategoryByIds(
            ledgerId: ledgerId, transactionIds: ids),
        readTransactionListMetadata(
            transactionIds: ids,
            readTags: repo.getTagsForTransactions,
            readAttachmentCounts: repo.getAttachmentCountsForTransactions),
      ).wait;
      final byId = {for (final row in bills) row.t.id: row};
      return (
        rows: [
          for (final id in ids)
            if (byId[id] case final row?) row
        ],
        metadata: metadata,
        currency: result['currency'] as String,
        count: result['totalCount'] as int,
        next: result['nextCursor'] as String?,
      );
    });
  }

  String _label(Map<String, Object?> query, bool hidden) {
    final filters = query['filters'] as Map;
    final dates = MaterialLocalizations.of(context);
    final start =
        DateTime.tryParse(filters['start']?.toString() ?? '')?.toLocal();
    final end = DateTime.tryParse(filters['end']?.toString() ?? '')?.toLocal();
    final l = AppLocalizations.of(context);
    final flow = query['displayFlow'] ?? filters['flowType'];
    final categoryNames = filters['categoryNames'];
    final label = [
      if (start != null && end != null)
        '${dates.formatCompactDate(start)} – ${dates.formatCompactDate(end.subtract(const Duration(microseconds: 1)))}',
      if (flow == 'income') l.homeIncome,
      if (flow == 'expense') l.homeExpense,
      if (flow == 'transfer') l.billCardTransfer,
      if (categoryNames is List)
        for (final name in categoryNames.whereType<String>())
          CategoryUtils.getDisplayName(name, context,
              kind: flow == 'income' ? 'income' : 'expense'),
      for (final key in ['accountNames', 'tagNames'])
        if (filters[key] is List) ...(filters[key] as List).whereType<String>(),
      for (final (key, title) in [
        ('category', l.exportCsvHeaderCategory),
        ('account', l.exportCsvHeaderAccount),
        ('tag', l.exportCsvHeaderTags)
      ])
        if (filters['${key}Names'] == null && filters['${key}Ids'] is List)
          for (final id in filters['${key}Ids'] as List) '$title #$id',
      if (filters['minAmount'] != null)
        '≥ ${hidden ? '••••' : filters['minAmount']}',
      if (filters['maxAmount'] != null)
        '≤ ${hidden ? '••••' : filters['maxAmount']}',
      if (filters['currency'] case final String currency) currency,
      if (filters['exclude'] != null) l.agentEvidenceExcluded,
    ].join(' · ');
    return label.isEmpty ? l.agentEvidenceScope : label;
  }

  void _select(int index, [String? cursor]) {
    if (!mounted) return;
    setState(() {
      _selection = index;
      _cursor = cursor;
      _frozenPage = 0;
      _page =
          _lookupCurrent && !_query.containsKey('snapshot') ? _load() : null;
    });
  }

  void _refresh() => _select(_selection, _cursor);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (widget.queries.isEmpty ||
        ref.watch(currentLedgerIdProvider) != widget.ledgerId ||
        _query['ledgerId'] != widget.ledgerId) {
      return SingleChildScrollView(
          child: BeeEmptyState(
              title: l.agentEvidenceLedgerChanged,
              icon: const BeeLineIcon('BookOpen', size: 32)));
    }
    final hidden = ref.watch(hideAmountsProvider);
    final accounts =
        ref.watch(accountFeatureEnabledProvider).valueOrNull ?? true;
    final theme = Theme.of(context);
    return FutureBuilder<_EvidencePage>(
      key: ValueKey((_selection, _cursor)),
      future: _page,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return ListView(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          children: [
            if (widget.queries.length == 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  BeeLineIcon('CalendarDays', size: 15, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_label(widget.queries.single, hidden),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor))),
                ]),
              )
            else
              BeeSelectField<int>(
                label: l.agentEvidenceScope,
                items: [
                  for (final (index, query) in widget.queries.indexed)
                    BeeSegment(index, _label(query, hidden))
                ],
                value: _selection,
                onChanged: (index) {
                  if (index != null && index != _selection) _select(index);
                },
              ),
            if (_query.containsKey('snapshot'))
              ..._frozenRows(context, accounts)
            else if (!_lookupCurrent) ...[
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l.agentAnswerLegacyEvidence)),
              BeeButton(
                  label: l.agentAnswerLookupCurrent,
                  kind: BeeButtonKind.secondary,
                  onPressed: () => setState(() {
                        _lookupCurrent = true;
                        _page = _load();
                      })),
            ] else if (data == null &&
                snapshot.connectionState != ConnectionState.done)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator.adaptive()))
            else if (snapshot.hasError || data == null)
              BeeEmptyState(
                  title: l.categoryDetailLoadFailed,
                  icon: const BeeLineIcon('CircleAlert', size: 32),
                  action: BeeButton(
                      label: l.helpCenterRetry,
                      kind: BeeButtonKind.secondary,
                      onPressed: _refresh))
            else ...[
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l.agentAnswerCurrentResults,
                      style: theme.textTheme.bodySmall)),
              Padding(
                  padding: const EdgeInsets.only(top: 5, bottom: 3),
                  child: BeeSectionLabel(l.agentEvidenceCount(data.count))),
              if (data.rows.isEmpty)
                BeeEmptyState(title: l.categoryDetailNoTransactions)
              else
                for (final (index, row) in data.rows.indexed) ...[
                  if (index > 0)
                    const Divider(height: 1, thickness: .6, indent: 46),
                  TransactionTileBinding(
                    key: ValueKey(row.t.id),
                    row: row,
                    tags: data.metadata.tags[row.t.id] ?? const [],
                    attachmentCount: data.metadata.attachments[row.t.id] ?? 0,
                    baseCurrency: data.currency,
                    fullDate: true,
                    openDetailsOnTap: true,
                    allowCategoryNavigation: false,
                    accountsEnabled: accounts,
                    onReturned: _refresh,
                  ),
                ],
              if (_cursor != null || data.next != null)
                OverflowBar(
                    spacing: 8,
                    alignment: MainAxisAlignment.end,
                    children: [
                      if (_cursor != null)
                        BeeButton(
                            label: l.agentEvidenceFirstPage,
                            kind: BeeButtonKind.quiet,
                            onPressed: () => _select(_selection)),
                      if (data.next != null)
                        BeeButton(
                            label: l.agentEvidenceNextPage,
                            kind: BeeButtonKind.secondary,
                            onPressed: () => _select(_selection, data.next)),
                    ]),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _frozenRows(BuildContext context, bool accounts) {
    final l = AppLocalizations.of(context);
    final snapshot = _query['snapshot'];
    if (!LedgerQuerySnapshot.valid(snapshot, widget.ledgerId)) {
      return [BeeEmptyState(title: l.agentAnswerSnapshotUnavailable)];
    }
    final saved = snapshot as Map;
    final flow = _query['displayFlow'] as String?;
    final count = flow == null
        ? saved['count'] as int
        : ((saved['totals'] as Map)[flow] as Map)['count'] as int;
    final captured = flow == null
        ? saved['capturedCount'] as int
        : (((saved['flowCounts'] as Map)[flow] as List)
            .cast<int>()
            .fold<int>(0, (a, b) => a + b));
    final numberOfPages = (captured / LedgerQuerySnapshot.pageSize).ceil();
    final currency = saved['currency'] as String;
    late final List<Map<String, Object?>> bills;
    try {
      bills = LedgerQuerySnapshot.page(saved, _frozenPage, flow: flow);
    } catch (_) {
      return [BeeEmptyState(title: l.agentAnswerSnapshotUnavailable)];
    }
    return [
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: BeeSectionLabel(l.agentEvidenceCount(count))),
      if (captured < count)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(l.agentAnswerSnapshotLimit(captured, count))),
      if (count == 0) BeeEmptyState(title: l.categoryDetailNoTransactions),
      for (final (index, bill) in bills.indexed) ...[
        if (index > 0) const Divider(height: 1, thickness: .6, indent: 46),
        _FrozenRow(
            key: ValueKey(bill['id'] as int),
            bill: bill,
            currency: currency,
            accounts: accounts,
            onTap: () => showBeeSheet<void>(Navigator.of(context).context,
                title: l.agentAnswerFrozenBill,
                child: _FrozenBillDetail(
                    ledgerId: widget.ledgerId,
                    bill: bill,
                    currency: currency))),
      ],
      if (_frozenPage > 0 || _frozenPage + 1 < numberOfPages)
        OverflowBar(spacing: 8, alignment: MainAxisAlignment.end, children: [
          if (_frozenPage > 0)
            BeeButton(
                label: l.agentEvidenceFirstPage,
                kind: BeeButtonKind.quiet,
                onPressed: () => setState(() => _frozenPage = 0)),
          if (_frozenPage + 1 < numberOfPages)
            BeeButton(
                label: l.agentEvidenceNextPage,
                kind: BeeButtonKind.secondary,
                onPressed: () => setState(() => _frozenPage++)),
        ]),
    ];
  }
}

class _FrozenRow extends StatelessWidget {
  const _FrozenRow(
      {super.key,
      required this.bill,
      required this.currency,
      required this.accounts,
      this.onTap});
  final Map<String, Object?> bill;
  final String currency;
  final bool accounts;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final transfer = bill['type'] == 'transfer';
    final category = transfer
        ? null
        : CategoryUtils.getDisplayName(bill['category'] as String?, context,
            kind: bill['type'] as String);
    final note = bill['note'] as String? ?? '';
    final name = bill['category'] as String?;
    final icon = bill['icon'] as String?;
    final capturedCategory = name == null
        ? null
        : Category(
            id: bill['category_id'] as int? ?? -1,
            name: name,
            kind: bill['type'] as String,
            sortOrder: 0,
            level: 1,
            icon: icon,
            iconType: bill['icon_type'] as String? ?? 'material',
            customIconPath: bill['icon_path'] as String?);
    return TransactionListItem(
      horizontalInset: 0,
      icon: CategoryService.getCategoryIcon(icon),
      category: capturedCategory,
      title: transfer && note.isEmpty ? l.transferTitle : note,
      amount: (bill['amount'] as num).toDouble(),
      nativeAmount: (bill['native_amount'] as num?)?.toDouble(),
      currencyCode: bill['currency_code'] as String?,
      baseCurrencyCode: currency,
      isExpense: bill['type'] == 'expense',
      isTransfer: transfer,
      happenedAt: DateTime.fromMillisecondsSinceEpoch(
          (bill['happened_at'] as int) * 1000),
      showFullDate: true,
      categoryName: category,
      accountName: accounts
          ? [bill['account'], if (transfer) bill['destination']]
              .whereType<String>()
              .join(' → ')
          : null,
      excludeFromStats: bill['exclude_from_stats'] == 1,
      excludeFromBudget: bill['exclude_from_budget'] == 1,
      tags: [
        for (final tag in (bill['tags'] as List? ?? const []).whereType<Map>())
          (
            id: tag['id'] as int,
            name: tag['name'] as String,
            color: tag['color'] as String?
          ),
      ],
      attachmentCount: bill['attachments'] as int? ?? 0,
      onTap: onTap,
    );
  }
}

class _FrozenBillDetail extends ConsumerStatefulWidget {
  const _FrozenBillDetail(
      {required this.ledgerId, required this.bill, required this.currency});
  final int ledgerId;
  final Map<String, Object?> bill;
  final String currency;
  @override
  ConsumerState<_FrozenBillDetail> createState() => _FrozenBillDetailState();
}

class _FrozenBillDetailState extends ConsumerState<_FrozenBillDetail> {
  late Future<Map<String, Object?>?> _current;
  @override
  void initState() {
    super.initState();
    _current = _read();
  }

  Future<Map<String, Object?>?> _read() => LedgerQuerySnapshot.current(
      ref.read(databaseProvider), widget.ledgerId, widget.bill);

  Future<void> _openCurrent() async {
    final bill = await _read();
    if (!mounted || ref.read(currentLedgerIdProvider) != widget.ledgerId) {
      return;
    }
    if (bill != null) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TransactionDetailPage(
              transactionId: bill['id'] as int, ledgerId: widget.ledgerId)));
    }
    if (mounted) {
      final next = _read();
      setState(() {
        _current = next;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (ref.watch(currentLedgerIdProvider) != widget.ledgerId) {
      return BeeEmptyState(title: l.agentEvidenceLedgerChanged);
    }
    final accounts =
        ref.watch(accountFeatureEnabledProvider).valueOrNull ?? true;
    final hidden = ref.watch(hideAmountsProvider);
    return SingleChildScrollView(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _FrozenRow(
          bill: widget.bill, currency: widget.currency, accounts: accounts),
      FutureBuilder<Map<String, Object?>?>(
          future: _current,
          builder: (context, state) {
            if (state.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            if (state.hasError) return Text(l.categoryDetailLoadFailed);
            final current = state.data;
            if (current == null) {
              return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(l.agentAnswerBillGone));
            }
            final changed =
                !const DeepCollectionEquality().equals(current, widget.bill);
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (changed) ...[
                    const Divider(),
                    Text(l.agentAnswerBillChanged),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.agentAnswerCurrentAmount),
                        trailing: Text(hidden
                            ? '••••'
                            : '${getDistinctCurrencySymbol(current['currency_code'] as String? ?? widget.currency)}${formatMoneyCompact((current['amount'] as num).toDouble(), trimZeros: false)}')),
                    if (accounts && current['account'] != null)
                      Text(
                          '${l.agentAnswerCurrentAccount} · ${current['account']}'),
                  ],
                  const SizedBox(height: 12),
                  BeeButton(
                      label: l.agentAnswerCurrentBill,
                      kind: BeeButtonKind.secondary,
                      onPressed: _openCurrent),
                ]);
          }),
    ]));
  }
}
