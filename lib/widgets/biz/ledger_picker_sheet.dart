import 'dart:math' as math;
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../pages/main/ledgers_page_new.dart';

/// App adapter: observes the same local ledger list and current selection as the
/// original dialog. Search and rendering are controlled business components.
class LedgerPickerDialog extends ConsumerWidget {
  const LedgerPickerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ledgers = ref.watch(localLedgersProvider);
    final id = ref.watch(currentLedgerIdProvider);
    return BeeDialog(
        title: Text(l.homeSwitchLedger),
        content: SizedBox(
            height: math.min(350, MediaQuery.sizeOf(context).height * .45),
            child: ledgers.when(
                data: (items) => BeeLedgerPicker(
                    ledgers: items
                        .map((ledger) => BeeLedgerChoice(
                            id: '${ledger.id}',
                            name: ledger.name,
                            currency: ledger.currency,
                            detail:
                                l.tagTransactionCount(ledger.transactionCount)))
                        .toList(),
                    currentId: '$id',
                    searchLabel: l.commonSearch,
                    emptyLabel: l.ledgersEmpty,
                    currentLabel: l.commonCurrent,
                    onSelected: (value) {
                      final selected = int.parse(value);
                      if (selected != id) {
                        ref.read(currentLedgerIdProvider.notifier).state =
                            selected;
                      }
                      Navigator.pop(context);
                    }),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => BeeEmptyState(
                    title: l.commonError,
                    action: BeeButton(
                        label: l.v4RecordingRetry,
                        onPressed: () =>
                            ref.invalidate(localLedgersProvider))))),
        actions: [
          BeeButton(
              label: l.homeManageLedgers,
              kind: BeeButtonKind.secondary,
              icon: const BeeLineIcon('Settings2', size: 18),
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                    MaterialPageRoute(builder: (_) => const LedgersPageNew()));
              })
        ]);
  }
}

void showLedgerPicker(BuildContext context) {
  showDialog<void>(
      context: context, builder: (_) => const LedgerPickerDialog());
}
