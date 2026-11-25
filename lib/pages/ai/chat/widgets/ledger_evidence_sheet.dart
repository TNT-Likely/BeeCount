import 'dart:convert';

import 'package:agentcore/agentcore.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../agent/tools/local_agent_tools.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers.dart';
import '../../../../providers/ai_chat_providers.dart';
import '../../../../utils/category_utils.dart';
import '../../../shared/transactions/bindings/transaction_list_metadata.dart';
import '../../../shared/transactions/bindings/transaction_tile.dart';
import '../../../transaction/search/bindings/transaction_search.dart';

/// Replays the filters behind the answer. The user can open the actual bill
/// and use its existing edit or copy actions.
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
    await showBeeSheet<void>(context,
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
          .map(Map<String, Object?>.from)
          .toList();
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
  late Future<_EvidencePage> _page;

  @override
  void initState() {
    super.initState();
    _page = _load();
  }

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
    final flow = filters['flowType'];
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
      _page = _load();
    });
  }

  void _refresh() => _select(_selection, _cursor);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (ref.watch(currentLedgerIdProvider) != widget.ledgerId) {
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
            if (data == null &&
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
}
