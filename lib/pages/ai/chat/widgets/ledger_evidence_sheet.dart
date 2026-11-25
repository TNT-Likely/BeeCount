import 'dart:convert';

import 'package:agentcore/agentcore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../agent/tools/local_agent_tools.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers.dart';
import '../../../../providers/ai_chat_providers.dart';
import '../../../transaction/transaction_detail_page.dart';

/// Replays the filters behind the answer. The user can open the actual bill
/// and use its existing edit or copy actions.
class LedgerEvidenceSheet extends ConsumerStatefulWidget {
  const LedgerEvidenceSheet(
      {super.key, required this.ledgerId, required this.queries});
  final int ledgerId;
  final List<Map<String, Object?>> queries;

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

class _LedgerEvidenceSheetState extends ConsumerState<LedgerEvidenceSheet> {
  int _selection = 0;
  late Future<Map<String, Object?>> _page;
  String? _cursor;
  @override
  void initState() {
    super.initState();
    _page = _load();
  }

  Future<Map<String, Object?>> _load() async {
    final tools = LocalAgentTools(
            scope: AgentScope(
                id: 'bill-evidence',
                ledgerId: widget.ledgerId,
                allowsMutations: false),
            gateway: ref.read(localAgentToolGatewayProvider),
            previous: widget.queries)
        .build();
    final result = await tools['query_transactions']!
        .execute(AgentToolCall(name: 'query_transactions', arguments: {
      'baseQuery': widget.queries[_selection]['ref'],
      if (_cursor != null) 'cursor': _cursor,
    }));
    if (result.containsKey('error') ||
        ['unmatched', 'ambiguous'].contains(result['matchStatus'])) {
      throw StateError('Evidence query no longer resolves');
    }
    return result;
  }

  String _label(Map<String, Object?> query) {
    final filters = query['filters'] as Map;
    final dates = MaterialLocalizations.of(context);
    final start = DateTime.tryParse(filters['start']?.toString() ?? '');
    final end = DateTime.tryParse(filters['end']?.toString() ?? '');
    final l = AppLocalizations.of(context);
    return [
      if (start != null && end != null)
        '${dates.formatCompactDate(start)} – ${dates.formatCompactDate(end.subtract(const Duration(microseconds: 1)))}',
      if (filters['flowType'] == 'income') l.homeIncome,
      if (filters['flowType'] == 'expense') l.homeExpense,
      for (final key in ['categoryNames', 'accountNames', 'tagNames'])
        if (filters[key] is List) ...(filters[key] as List),
      if (filters['minAmount'] != null) '≥ ${filters['minAmount']}',
      if (filters['maxAmount'] != null) '≤ ${filters['maxAmount']}',
      if (filters['exclude'] != null) l.agentEvidenceExcluded,
    ].join(' · ');
  }

  void _select(int index, [String? cursor]) => setState(() {
        _selection = index;
        _cursor = cursor;
        _page = _load();
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sameLedger = ref.watch(currentLedgerIdProvider) == widget.ledgerId;
    return SafeArea(
        child: FractionallySizedBox(
            heightFactor: .83,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.agentEvidenceBills,
                        style: Theme.of(context).textTheme.titleLarge),
                    if (sameLedger)
                      DropdownButton<int>(
                          isExpanded: true,
                          value: _selection,
                          items: [
                            for (final (index, query) in widget.queries.indexed)
                              DropdownMenuItem(
                                  value: index,
                                  child: Text(_label(query),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (value) {
                            if (value != null) _select(value);
                          }),
                    if (sameLedger)
                      Expanded(
                          child: FutureBuilder<Map<String, Object?>>(
                              future: _page,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState !=
                                    ConnectionState.done) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                if (snapshot.hasError || !snapshot.hasData) {
                                  return Center(
                                      child: TextButton(
                                          onPressed: () => _select(_selection),
                                          child: Text(l.helpCenterRetry)));
                                }
                                final data = snapshot.data!;
                                final rows =
                                    (data['items'] as List).cast<Map>();
                                final next = data['nextCursor'] as String?;
                                return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(l.agentEvidenceCount(
                                          data['totalCount'] as int)),
                                      Expanded(
                                          child: ListView(children: [
                                        for (final row in rows)
                                          ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text([
                                                row['note'],
                                                (row['category']
                                                    as Map?)?['name'],
                                                l.commonUncategorized
                                              ].whereType<String>().firstWhere(
                                                  (s) => s.trim().isNotEmpty)),
                                              subtitle: Text([
                                                MaterialLocalizations.of(
                                                        context)
                                                    .formatCompactDate(
                                                        DateTime.parse(
                                                            row['happenedAt']
                                                                as String)),
                                                if (row['account'] is Map)
                                                  (row['account']
                                                      as Map)['name']
                                              ].join(' · ')),
                                              trailing: Text(
                                                  '${row['currency']} ${(row['amount'] as num).abs().toStringAsFixed(2)}'),
                                              onTap: () async {
                                                await Navigator.of(context).push(
                                                    MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            TransactionDetailPage(
                                                                transactionId:
                                                                    row['id']
                                                                        as int,
                                                                ledgerId: widget
                                                                    .ledgerId)));
                                                if (mounted) {
                                                  _select(_selection);
                                                }
                                              }),
                                        if (next != null)
                                          TextButton(
                                              onPressed: () =>
                                                  _select(_selection, next),
                                              child: Text(l.commonNext)),
                                        if (_cursor != null)
                                          TextButton(
                                              onPressed: () =>
                                                  _select(_selection),
                                              child: Text(
                                                  l.agentEvidenceFirstPage))
                                      ]))
                                    ]);
                              })),
                  ]),
            )));
  }
}
