import 'dart:math' as math;
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db.dart';
import '../../../providers.dart';
import '../../../l10n/app_localizations.dart';

/// Keeps the original immediate-result dialog contract for chat and recurring bills.
Future<int?> showLedgerSelector(BuildContext context, {int? currentLedgerId}) =>
    showDialog<int>(
        context: context,
        builder: (_) => LedgerSelectorDialog(currentLedgerId: currentLedgerId));

class LedgerSelectorDialog extends ConsumerStatefulWidget {
  const LedgerSelectorDialog({super.key, this.currentLedgerId});
  final int? currentLedgerId;
  @override
  ConsumerState<LedgerSelectorDialog> createState() =>
      _LedgerSelectorDialogState();
}

class _LedgerSelectorDialogState extends ConsumerState<LedgerSelectorDialog> {
  late Future<List<Ledger>> ledgers;
  @override
  void initState() {
    super.initState();
    ledgers = ref.read(repositoryProvider).getAllLedgers();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeDialog(
        title: Text(l.ledgerSelectTitle),
        content: FutureBuilder<List<Ledger>>(
            future: ledgers,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  BeeStatus(
                      label: '${l.commonError}: ${snapshot.error}',
                      tone: BeeTone.error),
                  BeeButton(
                      label: l.helpCenterRetry,
                      onPressed: () => setState(() => ledgers =
                          ref.read(repositoryProvider).getAllLedgers()))
                ]);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return SizedBox(
                  height:
                      math.min(400, MediaQuery.sizeOf(context).height * .45),
                  child: BeeLedgerPicker(
                      ledgers: [
                        for (final ledger in snapshot.data!)
                          BeeLedgerChoice(
                              id: '${ledger.id}',
                              name: ledger.name,
                              currency: ledger.currency)
                      ],
                      currentId: widget.currentLedgerId?.toString(),
                      searchLabel: l.commonSearch,
                      emptyLabel: l.ledgersEmpty,
                      currentLabel: l.aiChatEmptyCurrentLedger,
                      onSelected: (id) =>
                          Navigator.pop(context, int.parse(id))));
            }));
  }
}
