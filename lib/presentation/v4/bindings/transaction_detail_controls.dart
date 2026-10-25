import 'dart:io';

import 'package:beecount_business_ui/transaction_detail.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/account/account_detail_page.dart';
import '../../../pages/attachment/attachment_preview_page.dart';
import '../../../pages/tag/tag_detail_page.dart';
import '../../../pages/transaction/category_detail_page.dart';
import '../../../providers.dart';
import '../../../utils/category_utils.dart';
import '../../../utils/transaction_edit_utils.dart';
import '../../../widgets/biz/format_money.dart';
import '../../../widgets/biz/transaction_receipt_dialog.dart';
import 'page_scaffold.dart';
import 'recording_category_icon.dart';
import 'transaction_detail_data.dart';

class TransactionDetailControls extends ConsumerStatefulWidget {
  const TransactionDetailControls(
      {super.key,
      required this.transactionId,
      this.ledgerId,
      this.allLedgers = false,
      this.previewOnly = false});
  final int transactionId;
  final int? ledgerId;
  final bool allLedgers, previewOnly;
  @override
  ConsumerState<TransactionDetailControls> createState() =>
      _TransactionDetailControlsState();
}

class _TransactionDetailControlsState
    extends ConsumerState<TransactionDetailControls> {
  bool _busy = false;
  String? _actionError;
  TransactionDetailRequest get request =>
      TransactionDetailRequest(widget.transactionId, ledgerId: widget.ledgerId);
  void _refresh() => ref.invalidate(transactionDetailDataProvider(request));

  Future<void> _open(Widget page) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Navigator.push(
          context, MaterialPageRoute<void>(builder: (_) => page));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  Future<void> _action(String action) async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final data =
          await loadTransactionDetail(ref.read(repositoryProvider), request);
      if (!mounted) return;
      if (data == null) {
        _refresh();
        return;
      }
      if (action != 'receipt' && !data.canWrite) {
        throw StateError(l.commonFailed);
      }
      switch (action) {
        case 'edit':
          await TransactionEditUtils.editTransaction(
              context, ref, data.row.t, data.row.category);
        case 'copy':
          await TransactionEditUtils.copyTransaction(context, ref, data.row.t);
        case 'receipt':
          await TransactionReceiptDialog.open(context, ref, data.row.t);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = error.toString());
        showBeeToast(context, '${l.commonError}: $error', tone: BeeTone.error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        hidden = ref.watch(hideAmountsProvider);
    final data = ref.watch(transactionDetailDataProvider(request));
    if (widget.previewOnly) {
      return data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              BeeStatus(label: '${l.commonError}: $error', tone: BeeTone.error),
          data: (value) => value == null
              ? BeeEmptyState(title: l.aiChatTransactionNotFound)
              : _content(context, value, hidden));
    }
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.v4TransactionDetailTitle,
          leading: const BackButton(),
          actions: [
            BeeIconButton(
                label: hidden ? l.v4AmountsShow : l.v4AmountsHide,
                icon: BeeLineIcon(hidden ? 'EyeOff' : 'Eye'),
                onPressed: () =>
                    ref.read(hideAmountsProvider.notifier).state = !hidden),
          ]),
      Expanded(
          child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => BeeEmptyState(
                  title: '${l.commonError}: $error',
                  action: BeeButton(
                      label: l.v4RecordingRetry, onPressed: _refresh)),
              data: (value) => value == null
                  ? BeeEmptyState(title: l.aiChatTransactionNotFound)
                  : BeePageBody(eager: true, children: [
                      _content(context, value, hidden),
                      if (_actionError != null)
                        BeeStatus(
                            label: '${l.commonError}: $_actionError',
                            tone: BeeTone.error),
                    ]))),
    ]));
  }

  Widget _content(
      BuildContext context, TransactionDetailData data, bool hidden) {
    final l = AppLocalizations.of(context),
        tx = data.row.t,
        category = data.row.category;
    final accountsEnabled =
        ref.watch(accountFeatureEnabledProvider).valueOrNull ?? true;
    final isTransfer = tx.type == 'transfer';
    final kind = tx.type == 'income'
        ? BeeTransactionKind.income
        : tx.type == 'expense'
            ? BeeTransactionKind.expense
            : BeeTransactionKind.transfer;
    final kindLabel = tx.type == 'income'
        ? l.exportTypeIncome
        : tx.type == 'expense'
            ? l.exportTypeExpense
            : tx.type == 'transfer'
                ? l.exportTypeTransfer
                : tx.type;
    final categoryName = category == null
        ? l.v4DetailMissingCategory
        : CategoryUtils.getDisplayName(category.name, context, kind: tx.type);
    final parentName = data.parentCategory == null
        ? null
        : CategoryUtils.getDisplayName(data.parentCategory!.name, context,
            kind: tx.type);
    final title = tx.note?.isNotEmpty == true
        ? tx.note!
        : isTransfer
            ? l.transferTitle
            : categoryName;
    // Same sign convention as TransactionListItem, including negative refunds.
    final signedValue = tx.type == 'expense' ? -tx.amount : tx.amount;
    final sign = isTransfer || signedValue == 0
        ? ''
        : signedValue < 0
            ? '−'
            : '+';
    final amount =
        '$sign${formatMoneyCompact(signedValue.abs(), trimZeros: false)}';
    final scopeAll =
        widget.allLedgers || ref.watch(currentLedgerIdProvider) != tx.ledgerId;
    VoidCallback? categoryAction =
        widget.previewOnly || category == null || category.id <= 0 || isTransfer
            ? null
            : () => _open(CategoryDetailPage(
                categoryId: category.id,
                categoryName: categoryName,
                allLedgers: scopeAll));
    Widget value(String text) => Text(text,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 13, height: 1.5));
    BeeDetailItem accountItem(String label, Account? account) => BeeDetailItem(
        label: label,
        value: value(account?.name ?? l.accountNone),
        onTap:
            !widget.previewOnly && account != null && account.id > 0 && !_busy
                ? () => _open(AccountDetailPage(account: account))
                : null);
    final items = <BeeDetailItem>[
      if (!isTransfer)
        BeeDetailItem(
            label: l.importFieldCategory,
            value: value(
                '${parentName == null ? '' : '$parentName / '}$categoryName'),
            onTap: _busy ? null : categoryAction),
      if (accountsEnabled && !isTransfer)
        accountItem(l.importFieldAccount, data.row.account),
      if (accountsEnabled && isTransfer) ...[
        accountItem(l.transferFromAccount, data.row.account),
        accountItem(l.transferToAccount, data.row.toAccount)
      ],
      BeeDetailItem(
          label: l.transactionReceiptLedger, value: value(data.ledger.name)),
      BeeDetailItem(
          label: l.importFieldDate,
          value: value(DateFormat('yyyy.MM.dd HH:mm:ss')
              .format(tx.happenedAt.toLocal()))),
    ];
    final directory = data.attachments.isEmpty
        ? null
        : ref.watch(transactionDetailDirectoryProvider);
    final models = directory?.valueOrNull == null
        ? <BeeAttachment>[]
        : [
            for (final a in data.attachments)
              BeeAttachment(
                  id: '${a.id}',
                  image: FileImage(
                      File('${directory!.valueOrNull}/${a.fileName}')),
                  label: a.originalName ?? a.fileName,
                  info: a.fileSize == null ? '' : '${a.fileSize} B')
          ];
    final placeholder = directory?.when(
        data: (_) => null,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => BeeStatus(
            label: l.commonError,
            tone: BeeTone.error,
            action: BeeButton(
                label: l.v4RecordingRetry,
                onPressed: () =>
                    ref.invalidate(transactionDetailDirectoryProvider))));
    final tags = [
      for (final tag in data.tags)
        BeeTagData('${tag.id}', tag.name, _tagColor(tag.color, context))
    ];
    final historical = data.historicalAmount, rate = data.historicalRate;
    return BeeTransactionDetail(
      title: title,
      kindLabel: kindLabel,
      kind: kind,
      currency: data.currency,
      amount: amount,
      hidden: hidden,
      icon: isTransfer
          ? const BeeLineIcon('ArrowLeftRight', size: 26)
          : category == null
              ? const BeeLineIcon('Shapes', size: 26)
              : RecordingCategoryIcon(category: category, size: 26),
      incomeIsRed: ref.watch(incomeExpenseColorSchemeProvider),
      onCategory: categoryAction,
      items: items,
      snapshotLabel: data.foreign ? l.v4TransactionDetailSnapshot : null,
      snapshotAmount: historical == null
          ? (data.foreign ? l.unconvertedBadge : null)
          : '≈ ${data.baseCurrency} ${formatMoneyCompact(historical, trimZeros: false)}',
      snapshotRateLabel: l.v4TransactionDetailSnapshotRate,
      snapshotRate: rate == null
          ? null
          : '1 ${data.currency} ≈ ${rate.toStringAsPrecision(6)} ${data.baseCurrency}',
      note: tx.note,
      noteLabel: l.exportCsvHeaderNote,
      tags: tags,
      tagsLabel: l.transactionReceiptTags,
      readOnlyTagIds: {
        for (final tag in data.tags)
          if (tag.id < 0 || widget.previewOnly) '${tag.id}'
      },
      onTag: (tag) {
        final id = int.parse(tag.id);
        if (id > 0) {
          _open(TagDetailPage(
              tagId: id, tagName: tag.label, allLedgers: scopeAll));
        }
      },
      attachments: models,
      attachmentPlaceholder: placeholder,
      attachmentLabel: l.exportCsvHeaderAttachments,
      attachmentCountLabel: l.attachmentCount(data.attachments.length),
      onAttachment: (index) => _open(AttachmentPreviewPage.fromTransaction(
          transactionId: tx.id, initialIndex: index, allowDelete: false)),
      statusLabels: [
        if (tx.excludeFromStats) l.txFlagExcludeFromStats,
        if (tx.excludeFromBudget) l.txFlagExcludeFromBudget
      ],
      copyLabel: l.transactionCopyAction,
      editLabel: l.commonEdit,
      receiptLabel: l.transactionReceiptAction,
      busy: _busy,
      onCopy: !widget.previewOnly &&
              data.canWrite &&
              ref.watch(currentLedgerIdProvider) == tx.ledgerId
          ? () => _action('copy')
          : null,
      onEdit:
          !widget.previewOnly && data.canWrite ? () => _action('edit') : null,
      onReceipt: widget.previewOnly ? null : () => _action('receipt'),
    );
  }

  Color _tagColor(String? input, BuildContext context) {
    final raw = input?.replaceFirst('#', ''),
        parsed = raw == null
            ? null
            : int.tryParse(raw.length == 6 ? 'ff$raw' : raw, radix: 16);
    return parsed == null
        ? Theme.of(context).colorScheme.primary
        : Color(parsed);
  }
}
