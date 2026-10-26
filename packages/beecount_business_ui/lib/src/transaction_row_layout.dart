import 'dart:math' as math;

/// Intrinsic widths measured using the row's real font and text scaler.
/// No database, preferences, currency conversion or navigation enters planning.
class TransactionRowMetrics {
  const TransactionRowMetrics({
    required this.amount,
    required this.minimumTitle,
    this.account = 0,
    this.attachment = 0,
    this.ledger = 0,
    this.converted = 0,
    this.timestamp = 0,
    this.readOnly = 0,
    this.statuses = const [],
    this.tags = const [0, 0, 0],
    required this.moreLabelWidth,
  });
  final double amount, minimumTitle;
  final double account, attachment, ledger, converted, timestamp, readOnly;
  final List<double> statuses;

  /// Width for zero, one and two visible labels, including the +N remainder.
  final List<double> tags;
  final double Function(int count) moreLabelWidth;
}

class TransactionRowPlan {
  const TransactionRowPlan({
    required this.wide,
    required this.inset,
    required this.lines,
    required this.widths,
    required this.folded,
    required this.visibleTags,
  });
  final bool wide;
  final double inset;
  final List<List<String>> lines;
  final Map<String, double> widths;
  final List<String> folded;
  final int visibleTags;
  int get lineCount => lines.where((l) => l.isNotEmpty).length;
}

/// C3: ordinary rows use two baselines, complex rows at most three.
/// Priority text is never replaced with icons or silently removed. Secondary
/// fields may enter an explicit, readable disclosure; their values stay in data.
TransactionRowPlan planTransactionRow(double width, TransactionRowMetrics m) {
  const gap = 5.0;
  final sizes = <String, double>{
    'amount': m.amount,
    'account': math.min(105, m.account),
    'attachment': m.attachment,
    'ledger': math.min(105, m.ledger),
    'converted': m.converted,
    'time': m.timestamp,
    'readonly': m.readOnly,
    for (var i = 0; i < m.statuses.length; i++) 'status-$i': m.statuses[i],
  };
  double occupied(Iterable<String> tokens) {
    final t = tokens.toList();
    return t.fold(0.0, (sum, token) => sum + (sizes[token] ?? 0)) +
        math.max(0, t.length - 1) * gap;
  }

  final status = [for (var i = 0; i < m.statuses.length; i++) 'status-$i'];
  final hard = [
    if (m.ledger > 0) 'ledger',
    ...status,
    if (m.timestamp > 0) 'time'
  ];
  final standard = math.max(0.0, width - 26 - 46);
  // A long ledger can still use its useful ellipsis width. It must not move
  // the entire row into the three-line wide layout just because of its name.
  final hardMinimum = occupied(hard) -
      (m.ledger > 0 ? sizes['ledger']! - math.min(42, sizes['ledger']!) : 0);
  final wide =
      m.amount + m.minimumTitle + gap > standard || hardMinimum > standard;
  final inset = wide ? (width < 330 ? 6.0 : 9.0) : 13.0;
  final available = math.max(0.0, width - inset * 2 - (wide ? 0 : 46));
  final lines = <List<String>>[
    wide ? ['amount'] : ['title', 'amount'],
    wide
        ? ['title', if (m.converted > 0) 'converted']
        : [
            if (m.account > 0) 'account',
            if (m.attachment > 0) 'attachment',
            if (m.converted > 0) 'converted',
          ],
    [...hard, if (m.readOnly > 0) 'readonly'],
  ];
  final folded = <String>[];
  if (wide) {
    if (m.account > 0) folded.add('account');
    if (m.attachment > 0) folded.add('attachment');
    if (m.readOnly > 0) {
      folded.add('readonly');
      lines[2].remove('readonly');
    }
  }
  if (m.ledger > 0) {
    final rest = hard.where((id) => id != 'ledger').toList();
    sizes['ledger'] = math.min(sizes['ledger']!,
        math.max(42, available - occupied(rest) - (rest.isEmpty ? 0 : gap)));
  }
  // Try all ordinary metadata on the second baseline before introducing a
  // third. A ledger, text status or read-only state is not itself complex.
  final hasTags = m.tags.any((w) => w > 0);
  var visibleTags = hasTags ? 2 : 0;
  if (!wide) {
    final candidates = [
      if (m.account > 0) 'account',
      if (m.attachment > 0) 'attachment',
      if (m.ledger > 0) 'ledger',
      ...status,
      if (m.readOnly > 0) 'readonly',
      if (hasTags) 'tags',
      if (m.converted > 0) 'converted',
      if (m.timestamp > 0) 'time',
    ];
    // Keep at least one real tag in a compact row. If even one tag cannot fit,
    // use the existing third line rather than disguising every tag as +N.
    for (final count in hasTags ? [2, 1] : [0]) {
      final compact = <String, double>{
        ...sizes,
        'tags': hasTags ? m.tags[count] : 0,
      };
      double used() =>
          candidates.fold(0.0, (sum, id) => sum + compact[id]!) +
          math.max(0, candidates.length - 1) * gap;
      final needed = used() - available;
      if (needed > 0) {
        final flexible = <String, double>{
          for (final id in ['account', 'ledger'])
            if (candidates.contains(id)) id: math.max(0, compact[id]! - 60),
        };
        final capacity = flexible.values.fold(0.0, (sum, room) => sum + room);
        if (needed > capacity || capacity == 0) continue;
        // Share the reduction so neither name collapses into a tiny stub.
        // A subpixel reserve avoids a render-rounding overflow at exact fits.
        final reduction = math.min(capacity, needed + .1);
        for (final entry in flexible.entries) {
          compact[entry.key] =
              compact[entry.key]! - reduction * entry.value / capacity;
        }
      }
      if (used() <= available) {
        return TransactionRowPlan(
            wide: false,
            inset: inset,
            lines: [lines[0], candidates],
            widths: compact,
            folded: const [],
            visibleTags: count);
      }
    }
  }
  // Account name may truncate normally; below a useful name width, disclose it.
  if (!wide && m.account > 0) {
    final remaining =
        available - occupied(lines[1].where((s) => s != 'account')) - gap;
    if (remaining < 30) {
      lines[1].remove('account');
      folded.add('account');
    } else {
      sizes['account'] = math.min(sizes['account']!, remaining);
    }
  }
  if (!wide &&
      occupied(lines[1]) > available &&
      lines[1].remove('attachment')) {
    folded.add('attachment');
  }
  if (occupied(lines[2]) > available && lines[2].remove('readonly')) {
    folded.add('readonly');
  }
  if (hasTags) {
    final room = available - occupied(lines[2]) - (lines[2].isEmpty ? 0 : gap);
    visibleTags = 2;
    while (visibleTags >= 0 && m.tags[visibleTags] > room) {
      visibleTags--;
    }
    if (visibleTags < 0) {
      folded.add('tags');
      visibleTags = 0;
    } else {
      sizes['tags'] = m.tags[visibleTags];
      final beforeTime = lines[2].indexOf('time');
      lines[2].insert(beforeTime < 0 ? lines[2].length : beforeTime, 'tags');
    }
  }
  if (folded.isNotEmpty) {
    sizes['more'] = m.moreLabelWidth(folded.length);
    final beforeConversion = lines[1].indexOf('converted');
    lines[1].insert(
        beforeConversion < 0 ? lines[1].length : beforeConversion, 'more');
    if (!wide) {
      for (final optional in ['account', 'attachment']) {
        if (occupied(lines[1]) <= available) break;
        if (lines[1].remove(optional)) {
          folded.add(optional);
          sizes['more'] = m.moreLabelWidth(folded.length);
        }
      }
    }
  }
  return TransactionRowPlan(
      wide: wide,
      inset: inset,
      lines: lines,
      widths: sizes,
      folded: folded,
      visibleTags: visibleTags);
}
