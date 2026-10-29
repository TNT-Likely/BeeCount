import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../pages/transaction/detail/bindings/transaction_detail_controls.dart';

final _recentDetailIdProvider =
    FutureProvider.autoDispose<(int, int)?>((ref) async {
  final ledger = ref.watch(currentLedgerIdProvider);
  ref.watch(statsRefreshProvider);
  ref.watch(syncGenerationProvider);
  final rows = await ref
      .watch(repositoryProvider)
      .getRecentTransactionsWithCategory(ledgerId: ledger, limit: 1);
  return rows.isEmpty ? null : (rows.first.t.id, ledger);
});

/// Real data projection; gallery actions never open a mutable editor or share.
class TransactionDetailPreview extends ConsumerWidget {
  const TransactionDetailPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        data = ref.watch(_recentDetailIdProvider);
    return data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            BeeStatus(label: '${l.commonError}: $error', tone: BeeTone.error),
        data: (ids) => ids == null
            ? BeeEmptyState(title: l.aiChatTransactionNotFound)
            : TransactionDetailControls(
                transactionId: ids.$1, ledgerId: ids.$2, previewOnly: true));
  }
}
