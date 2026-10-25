import 'package:beecount_business_ui/transaction_export.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../widgets/ui/ui.dart';
import 'export_csv.dart';
import 'export_platform.dart';
import 'page_scaffold.dart';

/// Binds the fixed CSV presentation to the same repository and platform I/O.
class ExportControls extends ConsumerStatefulWidget {
  const ExportControls({super.key});
  @override
  ConsumerState<ExportControls> createState() => _ExportControlsState();
}

class _ExportControlsState extends ConsumerState<ExportControls> {
  bool exporting = false;
  double progress = 0;
  String? savedPath, errorMessage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final platform = ref.watch(transactionExportPlatformProvider);
    final ledger = ref.watch(currentLedgerProvider).valueOrNull;
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.exportTitle, leading: const BackButton()),
      Expanded(
          child: BeePageBody(eager: true, children: [
        BeeTransactionExport(
            description: l.exportDescription,
            ledgerLabel: l.configIncludeLedgers,
            ledgerName: ledger?.name,
            fieldLabels: exportCsvHeaders(l),
            actionLabel: platform.shareAfterSave
                ? l.exportButtonIOS
                : l.exportButtonAndroid,
            exporting: exporting,
            progress: progress,
            savedMessage:
                savedPath == null ? null : l.exportSavedTo(savedPath!),
            errorTitle: l.exportFailedTitle,
            errorMessage: errorMessage,
            onExport: exporting ? null : _export),
      ]))
    ]));
  }

  Future<void> _export() async {
    if (exporting) return;
    // Capture the same current ledger at the moment the export is requested.
    final repo = ref.read(repositoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);
    final platform = ref.read(transactionExportPlatformProvider);
    final l = AppLocalizations.of(context);
    setState(() {
      exporting = true;
      progress = 0;
      savedPath = null;
      errorMessage = null;
    });
    try {
      final directory = await platform.exportDirectory();
      final csv = await buildTransactionExportCsv(
          repo: repo,
          ledgerId: ledgerId,
          l10n: l,
          onProgress: (value) {
            if (mounted) setState(() => progress = value);
          });
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = p.join(directory, 'beecount_$ts.csv');
      await platform.writeCsv(path, csv);
      if (!mounted) return;
      setState(() {
        savedPath = path;
        progress = 1;
      });
      if (platform.shareAfterSave) {
        // Preserve iOS system sharing, including its original dismiss behavior.
        await platform.shareCsv(path, l.exportShareText);
        if (!mounted) return;
        await AppDialog.info(context,
            title: l.exportSuccessTitle,
            message: l.exportSuccessMessageIOS(path));
      } else {
        await AppDialog.info(context,
            title: l.exportSuccessTitle,
            message: l.exportSuccessMessageAndroid(path));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = error.toString());
      await AppDialog.error(context,
          title: l.exportFailedTitle, message: error.toString());
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }
}
