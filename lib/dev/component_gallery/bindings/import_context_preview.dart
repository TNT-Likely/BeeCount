import 'package:beecount_business_ui/transaction_import.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/data/import_page.dart';
import '../../../providers.dart';

final importContextPreviewProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(repositoryProvider);
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final ledger = await repo.getLedgerById(ledgerId);
  final accounts = await repo.getAllAccounts();
  return (ledger: ledger, accounts: accounts);
});

/// Reads the actual target book and existing accounts without starting an import.
class LiveImportContextPreview extends ConsumerWidget {
  const LiveImportContextPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实导入目标（只读）'),
      const SizedBox(height: 8),
      ref.watch(importContextPreviewProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => BeeStatus(
              label: '$error',
              tone: BeeTone.error,
              action: TextButton(
                  onPressed: () => ref.invalidate(importContextPreviewProvider),
                  child: Text(l.v4RecordingRetry))),
          data: (value) => BeeImportSection(
              title: value.ledger?.name ?? l.importTitle,
              description:
                  '${value.ledger?.currency ?? 'CNY'} · ${value.accounts.length} 个现有账户',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final account in value.accounts.take(3))
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('${account.name} · ${account.currency}',
                              style: const TextStyle(fontSize: 12))),
                    Text(l.importAccountCurrencyPreviewHint,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.55,
                            color: Theme.of(context).hintColor)),
                  ]))),
      const SizedBox(height: 12),
      BeeButton(
          label: l.importTitle,
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ImportPage()))),
    ]);
  }
}
