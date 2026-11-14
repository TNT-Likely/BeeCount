import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

List<BeeSegment<String>> detailPeriodItems(BuildContext context) {
  final l = AppLocalizations.of(context);
  return [
    BeeSegment('month', l.v4DetailMonth),
    BeeSegment('year', l.v4DetailYear),
    BeeSegment('all', l.analyticsAll),
  ];
}

String detailRangeLabel(BuildContext context, String period, DateTime anchor) =>
    switch (period) {
      'all' => AppLocalizations.of(context).v4DetailAllTime,
      'year' => '${anchor.year}',
      _ => MaterialLocalizations.of(context).formatMonthYear(anchor),
    };

Future<({String period, DateTime anchor})?> showResourcePeriodPicker(
    BuildContext context,
    {required String period,
    required DateTime anchor}) async {
  var draft = ['month', 'year', 'all'].contains(period) ? period : 'month';
  var date = anchor;
  return showBeeSheet<({String period, DateTime anchor})>(context,
      title: AppLocalizations.of(context).homeSelectDate,
      child: StatefulBuilder(builder: (context, update) {
    final l = AppLocalizations.of(context);
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BeeCompactTabs<String>(
              items: detailPeriodItems(context),
              value: draft,
              trackHeight: 32,
              tapHeight: 44,
              onChanged: (value) => update(() => draft = value)),
          const SizedBox(height: 10),
          if (draft != 'all')
            BeeYearMonthWheel(
                key: ValueKey(draft),
                value: date,
                showMonth: draft == 'month',
                onChanged: (value) => date = value)
          else
            SizedBox(
                height: 150,
                child: Center(
                    child: Text(l.v4DetailAllTime,
                        style: const TextStyle(fontSize: 18)))),
          const SizedBox(height: 12),
          BeeButton(
              label: l.commonConfirm,
              onPressed: () =>
                  Navigator.pop(context, (period: draft, anchor: date))),
        ]);
  }));
}
