import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../models/home_transaction_preview.dart';

class HomeJournalFrame extends ConsumerStatefulWidget {
  const HomeJournalFrame(
      {super.key,
      this.child,
      this.childBuilder,
      this.initialPreview,
      required this.onCalendar,
      required this.onFilter,
      required this.onBatch})
      : assert(child != null || childBuilder != null);
  final Widget? child;
  final HomeTransactionPreview? initialPreview;
  final Widget Function(ValueChanged<HomeTransactionPreview> onPreviewReady)?
      childBuilder;
  final VoidCallback onCalendar, onFilter, onBatch;
  @override
  ConsumerState<HomeJournalFrame> createState() => _HomeJournalFrameState();
}

class _HomeJournalFrameState extends ConsumerState<HomeJournalFrame> {
  int? _countLedger, _displayCount;
  AsyncValue<({int dayCount, int txCount})>? _observedCounts;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPreview;
    if (initial != null &&
        initial.ledgerId == ref.read(currentLedgerIdProvider)) {
      _countLedger = initial.ledgerId;
      _displayCount = initial.totalCount;
      // A cached/in-flight count must not replace the transactional startup
      // total before onPreviewReady invalidates that older generation.
      _observedCounts = ref.read(countsForLedgerProvider(initial.ledgerId));
    }
  }

  void _onPreviewReady(HomeTransactionPreview preview) {
    if (!mounted || preview.ledgerId != ref.read(currentLedgerIdProvider)) {
      return;
    }
    setState(() {
      _countLedger = preview.ledgerId;
      _displayCount = preview.totalCount;
    });
    // A count query started before the preview may complete afterwards with
    // an older snapshot. Replace that pending generation with a fresh COUNT;
    // the preview count covers the header while it runs.
    ref.invalidate(countsForLedgerProvider(preview.ledgerId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = ref.watch(currentLedgerIdProvider);
    if (_countLedger != id) {
      _countLedger = id;
      _displayCount = null;
      _observedCounts = null;
    }
    final counts = ref.watch(countsForLedgerProvider(id));
    if (!identical(counts, _observedCounts)) {
      _observedCounts = counts;
      if (!counts.isLoading &&
          counts is AsyncData<({int dayCount, int txCount})>) {
        _displayCount = counts.value.txCount;
      }
    }
    final count = _displayCount ?? 0;
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
                        onPressed: widget.onCalendar),
                    BeeIconButton(
                        label: l10n.searchFilterTitle,
                        icon: const BeeLineIcon('SlidersHorizontal', size: 17),
                        onPressed: widget.onFilter),
                    TextButton(
                        onPressed: widget.onBatch,
                        style: TextButton.styleFrom(
                            minimumSize: const Size(36, 44),
                            padding: EdgeInsets.zero),
                        child: Text(l10n.v4HomeBatch,
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).hintColor))),
                  ]),
              Expanded(
                  child: widget.childBuilder?.call(_onPreviewReady) ??
                      widget.child!),
            ])));
  }
}
