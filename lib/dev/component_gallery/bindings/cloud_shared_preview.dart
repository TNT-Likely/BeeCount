import 'package:beecount_business_ui/cloud_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Variable;
import '../../../l10n/app_localizations.dart';
import '../../../providers/database_providers.dart';

/// Local mirror only. Gallery inspection never fetches invites or members.
final cloudSharedMirrorCountsProvider = StreamProvider.autoDispose
    .family<({int categories, int accounts, int tags}), String>((ref, ledger) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect('''
    SELECT (SELECT COUNT(*) FROM shared_ledger_categories WHERE ledger_sync_id = ?) AS categories,
           (SELECT COUNT(*) FROM shared_ledger_accounts WHERE ledger_sync_id = ?) AS accounts,
           (SELECT COUNT(*) FROM shared_ledger_tags WHERE ledger_sync_id = ?) AS tags
  ''', variables: [
        Variable(ledger),
        Variable(ledger),
        Variable(ledger)
      ], readsFrom: {
        db.sharedLedgerCategories,
        db.sharedLedgerAccounts,
        db.sharedLedgerTags,
      })
      .watchSingle()
      .map((row) => (
            categories: row.read<int>('categories'),
            accounts: row.read<int>('accounts'),
            tags: row.read<int>('tags'),
          ));
});

class CloudSharedPreview extends ConsumerWidget {
  const CloudSharedPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ref.watch(currentLedgerProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('${l.commonError}: $error'),
          data: (ledger) {
            if (ledger == null) return Text(l.aiOcrNoLedger);
            return ref
                .watch(cloudSharedMirrorCountsProvider(ledger.syncId ?? ''))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('${l.commonError}: $error'),
                  data: (counts) => BeeCloudSharedCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Text(ledger.name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        BeeCloudSharedHealthRow(
                            label: l.syncHealthRowCategory,
                            value: l.syncHealthValueRemoteMissing(
                                counts.categories)),
                        BeeCloudSharedHealthRow(
                            label: l.syncHealthRowAccount,
                            value: l
                                .syncHealthValueRemoteMissing(counts.accounts)),
                        BeeCloudSharedHealthRow(
                            label: l.syncHealthRowTag,
                            value: l.syncHealthValueRemoteMissing(counts.tags)),
                      ])),
                );
          },
        );
  }
}
