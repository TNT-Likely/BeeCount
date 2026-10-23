import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';

class HomeJournalFrame extends ConsumerWidget {
  const HomeJournalFrame(
      {super.key,
      required this.child,
      required this.onCalendar,
      required this.onFilter,
      required this.onBatch});
  final Widget child;
  final VoidCallback onCalendar, onFilter, onBatch;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = ref.watch(currentLedgerIdProvider);
    final count =
        ref.watch(countsForLedgerProvider(id)).valueOrNull?.txCount ?? 0;
    return Padding(
        padding: const EdgeInsets.fromLTRB(17, 5, 17, 0),
        child: BeeSurface(
            padding: const EdgeInsets.fromLTRB(15, 4, 15, 9),
            child: Column(children: [
              BeeTransactionStreamHeader(
                  title: l10n.v4HomeAllTransactions,
                  count: l10n.tagTransactionCount(count),
                  actions: [
                    BeeIconButton(
                        label: l10n.calendarTitle,
                        icon: const BeeLineIcon('CalendarDays', size: 17),
                        onPressed: onCalendar),
                    BeeIconButton(
                        label: l10n.searchFilterTitle,
                        icon: const BeeLineIcon('SlidersHorizontal', size: 17),
                        onPressed: onFilter),
                    TextButton(
                        onPressed: onBatch,
                        style: TextButton.styleFrom(
                            minimumSize: const Size(36, 44),
                            padding: EdgeInsets.zero),
                        child: Text(l10n.v4HomeBatch,
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).hintColor))),
                  ]),
              Expanded(child: child),
            ])));
  }
}
