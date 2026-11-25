/// Checks whether each named category has its own ledger amount in the reply.
/// Accepts prose and table rows. Counts, dates and percentages are not amounts.
Map<String, num> expectedCategoryAmounts(List tools) {
  final amounts = <String, num>{};
  for (final tool in tools.whereType<Map>()) {
    if (tool['name'] != 'get_category_breakdown') continue;
    final items = (tool['result'] as Map?)?['items'];
    if (items is! List) continue;
    for (final row in items.whereType<Map>()) {
      final name = (row['category'] as Map?)?['name'];
      if (name is String && row['amount'] is num) {
        amounts[name] = row['amount'] as num;
      }
    }
  }
  return amounts;
}

bool matchesCategoryAmounts(String text, Map<String, num> expected) {
  if (expected.isEmpty) return true;
  final labels = expected.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final labelPattern = RegExp(labels.map(RegExp.escape).join('|'));
  final normalized =
      text.replaceAll(RegExp(r'(?<=\d)[,，](?=\d{3}(?:\D|$))'), '');
  final currency = RegExp(
      r'(?:(?:[¥￥$]|CNY|RMB|USD)\s*(-?\d+(?:\.\d+)?)|(-?\d+(?:\.\d+)?)\s*(?:元|块|圓|圆|CNY|USD))',
      caseSensitive: false);
  final number = RegExp(r'(?<![\d.])-?\d+(?:\.\d+)?(?![\d.])');
  final mentions = labelPattern.allMatches(normalized).toList();
  final matched = <String>{};
  for (final (index, label) in mentions.indexed) {
    final name = label.group(0)!;
    final after = normalized
        .substring(
            label.end,
            index + 1 < mentions.length
                ? mentions[index + 1].start
                : normalized.length)
        .split(RegExp(r'[。；;\n，,]'))
        .first;
    final before = normalized
        .substring(index > 0 ? mentions[index - 1].end : 0, label.start)
        .split(RegExp(r'[。；;\n，,]'))
        .last;
    final money = currency.firstMatch(after);
    // A bare table value is accepted in the absence of an explicit unit.
    final bare = number
        .allMatches(after)
        .where(
            (n) => !RegExp(r'^\s*[%％笔筆年月日]').hasMatch(after.substring(n.end)))
        .firstOrNull;
    final preceding = currency
        .allMatches(before)
        .where((m) => before.substring(m.end).trim().isEmpty)
        .lastOrNull;
    final value = money?.group(1) ??
        money?.group(2) ??
        bare?.group(0) ??
        preceding?.group(1) ??
        preceding?.group(2);
    if (value != null && num.tryParse(value) == expected[name]) {
      matched.add(name);
    }
  }
  return matched.length == expected.length;
}
