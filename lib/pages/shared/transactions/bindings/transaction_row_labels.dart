import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/widgets.dart';
import '../../../../l10n/app_localizations.dart';

/// All transaction disclosure copy comes from the application localization.
/// Component-only hosts without AppLocalizations use the package fallback.
BeeTransactionRowLabels transactionRowLabels(BuildContext context) {
  final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
  if (l == null) return const BeeTransactionRowLabels();
  return BeeTransactionRowLabels(
    fieldsTitle: l.v4TransactionRowFieldsTitle,
    moreFields: l.v4TransactionRowMoreFields,
    category: l.exportCsvHeaderCategory,
    account: l.exportCsvHeaderAccount,
    ledger: l.transactionReceiptLedger,
    note: l.exportCsvHeaderNote,
    amount: l.v4SearchOriginalAmount,
    converted: l.v4TransactionDetailSnapshot,
    time: l.exportCsvHeaderTime,
    tags: l.exportCsvHeaderTags,
    attachments: l.exportCsvHeaderAttachments,
    rules: l.txFlagMoreOptions,
    readOnly: l.v4TransactionRowReadOnly,
    access: l.v4TransactionRowAccess,
  );
}
