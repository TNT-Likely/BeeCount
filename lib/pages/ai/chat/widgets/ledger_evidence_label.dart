import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../utils/category_utils.dart';

String ledgerEvidenceDateRange(
    BuildContext context, DateTime start, DateTime end) {
  final l = AppLocalizations.of(context);
  final locale = l.localeName;
  if (start != DateTime(start.year, start.month, start.day) ||
      end != DateTime(end.year, end.month, end.day)) {
    final time = DateFormat.yMMMd(locale).add_Hm();
    return l.agentFollowUpRange(time.format(start), time.format(end));
  }
  final last = DateTime(end.year, end.month, end.day - 1);
  final currentYear = DateTime.now().year;
  final date = start.year == currentYear && last.year == currentYear
      ? DateFormat.MMMd(locale)
      : DateFormat.yMMMd(locale);
  if (last == start) return date.format(start);
  return '${date.format(start)} – ${date.format(last)}';
}

/// The same named filters accompany the metric and its bill list.
List<String> ledgerEvidenceFilterLabels(BuildContext context, Map filters,
    {required bool accountsEnabled, bool hideAmounts = false, String? flow}) {
  final l = AppLocalizations.of(context);
  final kind = (flow ?? filters['flowType']) == 'income' ? 'income' : 'expense';
  final categories = filters['categoryNames'];
  return [
    if (categories is List)
      for (final name in categories.whereType<String>())
        CategoryUtils.getDisplayName(name, context, kind: kind),
    for (final key in [if (accountsEnabled) 'accountNames', 'tagNames'])
      if (filters[key] case final List names) ...names.whereType<String>(),
    for (final (key, label) in [
      ('category', l.exportCsvHeaderCategory),
      if (accountsEnabled) ('account', l.exportCsvHeaderAccount),
      ('tag', l.exportCsvHeaderTags)
    ])
      if (filters['${key}Names'] == null && filters['${key}Ids'] is List)
        for (final id in filters['${key}Ids'] as List) '$label #$id',
    if (filters['minAmount'] != null)
      '≥ ${hideAmounts ? '••••' : filters['minAmount']}',
    if (filters['maxAmount'] != null)
      '≤ ${hideAmounts ? '••••' : filters['maxAmount']}',
    if (filters['currency'] case final String currency) currency,
    if (filters['exclude'] != null) l.agentEvidenceExcluded,
  ];
}
