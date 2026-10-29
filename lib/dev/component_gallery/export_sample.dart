import 'package:beecount_business_ui/transaction_export.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

import '../../utils/app_localizations_resolver.dart';
import '../../pages/data/export/bindings/export_csv.dart';

class ExportSample extends StatefulWidget {
  const ExportSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<ExportSample> createState() => _ExportSampleState();
}

class _ExportSampleState extends State<ExportSample> {
  int mode = 0;
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeTransactionExport(
          description: l.exportDescription,
          ledgerLabel: l.configIncludeLedgers,
          ledgerName: 'QA current ledger · USD',
          fieldLabels: exportCsvHeaders(l),
          actionLabel: l.exportButtonAndroid,
          exporting: mode == 1,
          progress: .6,
          savedMessage: mode == 2
              ? l.exportSavedTo('/QA/Download/BeeCount/beecount_sample.csv')
              : null,
          errorTitle: l.exportFailedTitle,
          errorMessage: mode == 3 ? 'QA synthetic file write failure' : null,
          onExport: () => setState(() => mode = 2)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final option in [0, 1, 2, 3])
          BeeButton(
              label: [
                'QA ready',
                'QA progress',
                'QA saved',
                'QA error'
              ][option],
              kind: BeeButtonKind.secondary,
              onPressed: () => setState(() => mode = option)),
      ]),
      if (widget.liveData != null) ...[
        const SizedBox(height: 16),
        widget.liveData!,
      ],
    ]);
  }
}
