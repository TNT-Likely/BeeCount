import 'package:beecount_business_ui/transaction_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import 'export_csv.dart';

/// Read-only production data preview; the gallery never starts file I/O.
class ExportPreview extends ConsumerWidget {
  const ExportPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ledger = ref.watch(currentLedgerProvider);
    return BeeTransactionExport(
        description: l.exportDescription,
        ledgerLabel: l.configIncludeLedgers,
        ledgerName: ledger.valueOrNull?.name,
        fieldLabels: exportCsvHeaders(l),
        actionLabel: l.exportButtonAndroid,
        onExport: null);
  }
}
