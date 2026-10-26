import 'package:beecount_business_ui/transaction_detail.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../utils/app_localizations_resolver.dart';

/// All callbacks are local example feedback, without file or repository writes.
class TransactionDetailSample extends StatefulWidget {
  const TransactionDetailSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<TransactionDetailSample> createState() =>
      _TransactionDetailSampleState();
}

class _TransactionDetailSampleState extends State<TransactionDetailSample> {
  bool hidden = false, transfer = false;
  String event = 'QA local detail sample';
  void action(String value) => setState(() => event = 'QA · $value');
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSurface(child: Text(event)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        BeeButton(
            label: hidden ? l.v4AmountsShow : l.v4AmountsHide,
            kind: BeeButtonKind.secondary,
            onPressed: () => setState(() => hidden = !hidden)),
        BeeButton(
            label: l.transferTitle,
            kind: BeeButtonKind.secondary,
            onPressed: () => setState(() => transfer = !transfer)),
      ]),
      const SizedBox(height: 12),
      BeeTransactionDetail(
          title: 'QA 午餐与咖啡',
          kindLabel: transfer ? l.transferTitle : l.exportTypeExpense,
          kind: transfer
              ? BeeTransactionKind.transfer
              : BeeTransactionKind.expense,
          amount: transfer ? '12.00' : '−12.00',
          currency: 'USD',
          hidden: hidden,
          icon: const BeeLineIcon('Coffee', size: 26),
          onCategory: () => action(l.categoryTitle),
          items: [
            BeeDetailItem(
                label: l.transactionReceiptLedger,
                value: const Text('QA CNY账本')),
            BeeDetailItem(
                label: l.importFieldDate,
                value: const Text('2026.10.25 12:30:00')),
            BeeDetailItem(
                label: transfer ? l.transferFromAccount : l.importFieldAccount,
                value: const Text('QA USD现金')),
            if (transfer)
              BeeDetailItem(
                  label: l.transferToAccount, value: const Text('QA USD银行')),
          ],
          snapshotLabel: l.v4TransactionDetailSnapshot,
          snapshotAmount: '≈ CNY 85.80',
          snapshotRateLabel: l.v4TransactionDetailSnapshotRate,
          snapshotRate: '1 USD ≈ 7.15000 CNY',
          tags: const [BeeTagData('qa', 'QA 午餐', Color(0xffbd5d50))],
          tagsLabel: l.transactionReceiptTags,
          onTag: (_) => action(l.tagDetailTitle),
          note: 'QA 完整备注与多张附件。所有操作只更新此局部样例。',
          noteLabel: l.exportCsvHeaderNote,
          attachments: [
            for (final name in ['payment', 'receipt', 'order'])
              BeeAttachment(
                  id: name,
                  image: AssetImage('assets/v4_gallery/attachment-$name.png'),
                  label: 'QA $name',
                  info: 'QA synthetic')
          ],
          attachmentLabel: l.exportCsvHeaderAttachments,
          attachmentCountLabel: l.attachmentCount(3),
          onAttachment: (index) => action('attachment ${index + 1}'),
          statusLabels: [l.txFlagExcludeFromStats, l.txFlagExcludeFromBudget],
          copyLabel: l.transactionCopyAction,
          editLabel: l.commonEdit,
          receiptLabel: l.transactionReceiptAction,
          onCopy: () => action(l.transactionCopyAction),
          onEdit: () => action(l.commonEdit),
          onReceipt: () => action(l.transactionReceiptAction)),
      if (widget.liveData != null) ...[
        const SizedBox(height: 16),
        widget.liveData!
      ],
    ]);
  }
}
