import '../../agent/tools/ledger_query_snapshot.dart';
import '../../agent/tools/ledger_query_evidence.dart';

/// Facts available to a fresh interpretation of a previously saved answer.
/// Bill pages and transaction notes stay on the device.
abstract final class FrozenQueryAnswer {
  static List<Map<String, Object?>> facts(Map context, int ledgerId) {
    final refs = context['displayRefs'];
    final definitions = context['queries'];
    final snapshots = context['snapshots'];
    if (refs is! List || definitions is! List || snapshots is! Map) {
      return const [];
    }
    final remaining = refs.whereType<String>().toSet();
    if (remaining.length != refs.length) return const [];
    final facts = <Map<String, Object?>>[];
    var primaryCount = 0;
    for (final query in definitions.whereType<Map>()) {
      if (!remaining.remove(query['ref'])) continue;
      if (query['ledgerId'] != ledgerId) return const [];
      final primary = query['tool'] == 'get_period_overview' &&
          const {'expense', 'income', 'overview', 'balance'}
              .contains(query['answerMetric']);
      final filters = query['filters'];
      final snapshot = snapshots[query['ref']];
      if (filters is! Map ||
          snapshot is! Map ||
          !LedgerQuerySnapshot.valid(snapshot, ledgerId) ||
          !_sameTime(filters['start'], snapshot['start']) ||
          !_sameTime(filters['end'], snapshot['end'])) {
        if (primary) return const [];
        continue;
      }
      if (primary) primaryCount++;
      final totals = snapshot['totals'] as Map;
      facts.add({
        'tool': query['tool'],
        'answerMetric': query['answerMetric'],
        'filters': _filters(filters),
        'currency': snapshot['currency'],
        for (final flow in ['income', 'expense', 'transfer'])
          flow: {
            'amount': totals[flow]['amount'],
            'count': totals[flow]['count'],
          },
        'net': (totals['income']['amount'] as num) -
            (totals['expense']['amount'] as num),
      });
    }
    return primaryCount == 1 && remaining.isEmpty ? facts : const [];
  }

  static bool _sameTime(Object? left, Object? right) {
    final a = left is String ? DateTime.tryParse(left) : null;
    final b = right is String ? DateTime.tryParse(right) : null;
    return a != null && b != null && a.isAtSameMomentAs(b);
  }

  static Map<String, Object?> _filters(Map raw, [int depth = 0]) => {
        for (final key in LedgerQueryEvidence.filterKeys)
          if (raw.containsKey(key) && key != 'exclude') key: raw[key],
        if (raw['exclude'] case final Map excluded when depth < 4)
          'exclude': _filters(excluded, depth + 1),
      };
}
