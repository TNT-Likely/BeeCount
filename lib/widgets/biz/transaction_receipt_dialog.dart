import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/database_providers.dart';
import '../../services/export/share_poster_service.dart';
import '../../services/system/logger_service.dart';
import '../../styles/tokens.dart';
import '../../widgets/posters/transaction_receipt.dart';
import '../../widgets/ui/ui.dart';

class TransactionReceiptDialog extends StatefulWidget {
  final TransactionReceiptData data;
  const TransactionReceiptDialog({super.key, required this.data});

  static Future<void> open(
      BuildContext context, WidgetRef ref, Transaction transaction) async {
    try {
      final repo = ref.read(repositoryProvider);
      final tx = await repo.getTransactionById(transaction.id);
      if (tx == null) throw StateError('Transaction no longer exists');
      final ledger = await repo.getLedgerById(tx.ledgerId);
      if (ledger == null) throw StateError('Ledger no longer exists');
      final day =
          DateTime(tx.happenedAt.year, tx.happenedAt.month, tx.happenedAt.day);
      // Reuse the production hydration of shared category/account references.
      final rows = await repo
          .watchTransactionsForCategoryInRange(
            ledgerId: tx.ledgerId,
            start: day,
            end: day.add(const Duration(days: 1)),
            categoryId: tx.categoryId,
            type: tx.type,
          )
          .first;
      final row = rows.where((r) => r.t.id == tx.id).firstOrNull;
      if (row == null) throw StateError('Transaction no longer exists');
      final tags = await repo.getTagsForTransaction(tx.id);
      if (!context.mounted) return;
      await showDialog<void>(
          context: context,
          builder: (_) => Dialog(
                backgroundColor: BeeTokens.surfaceElevated(context),
                surfaceTintColor: Colors.transparent,
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                    width: 420,
                    height: MediaQuery.sizeOf(context).height * .88,
                    child: TransactionReceiptDialog(
                      data: TransactionReceiptData(
                          transaction: row.t,
                          ledger: ledger,
                          category: row.category,
                          account: row.account,
                          toAccount: row.toAccount,
                          tags: tags),
                    )),
              ));
    } catch (error, stack) {
      logger.error('TransactionReceipt', '加载小票失败', error, stack);
      if (context.mounted) {
        showToast(context,
            AppLocalizations.of(context).transactionReceiptUnavailable);
      }
    }
  }

  @override
  State<TransactionReceiptDialog> createState() =>
      _TransactionReceiptDialogState();
}

class _TransactionReceiptDialogState extends State<TransactionReceiptDialog> {
  final _receiptKey = GlobalKey();
  bool _showNote = true;
  bool _showTags = true;
  bool _showAccount = false;
  bool _showLedger = false;
  bool _busy = false;
  bool _sharing = false;

  Future<Uint8List> _capture() async {
    logger.debug('TransactionReceipt', '开始渲染小票');
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _receiptKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    // Keep very long notes within a bounded raster size.
    final ratio = math.min(
        3.0,
        math.min(
            8192 / boundary.size.height,
            math.sqrt(
                20000000 / (boundary.size.width * boundary.size.height))));
    final image = await boundary.toImage(pixelRatio: ratio);
    logger.debug(
        'TransactionReceipt', '小票渲染完成: ${image.width}×${image.height}');
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('PNG encoding failed');
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _export({required bool share, Rect? anchor}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _sharing = share;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = await _capture();
      if (!mounted) return;
      if (share) {
        await SharePlus.instance.share(ShareParams(files: [
          XFile.fromData(bytes,
              mimeType: 'image/png', name: 'beecount-receipt.png'),
        ], fileNameOverrides: [
          'beecount-receipt.png'
        ], sharePositionOrigin: anchor));
      } else {
        logger.debug('TransactionReceipt', '开始保存小票');
        final result = await SharePosterService.savePosterToGallery(bytes);
        logger.debug('TransactionReceipt', '保存小票结果: ${result.name}');
        if (!mounted) return;
        showToast(
            context,
            switch (result) {
              SavePosterResult.success => l10n.sharePosterSaveSuccess,
              SavePosterResult.accessDenied => l10n.sharePosterPermissionDenied,
              SavePosterResult.failed => l10n.sharePosterSaveFailed,
            });
      }
    } catch (error, stack) {
      logger.error('TransactionReceipt', '导出小票失败', error, stack);
      if (mounted) {
        showToast(
            context,
            share
                ? l10n.transactionReceiptShareFailed
                : l10n.sharePosterSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = widget.data;
    return Material(
      color: BeeTokens.surfaceElevated(context),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 10, 6),
          child: Row(children: [
            Icon(Icons.receipt_long_outlined,
                size: 20, color: BeeTokens.iconPrimary(context)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(l10n.transactionReceiptTitle,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: BeeTokens.textPrimary(context)))),
            IconButton(
                key: const ValueKey('receipt-close'),
                tooltip: l10n.commonClose,
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded,
                    size: 21, color: BeeTokens.iconSecondary(context))),
          ]),
        ),
        Expanded(
            child: ColoredBox(
          color: BeeTokens.surfaceSecondary(context),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ClipRect(
                child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                  child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 320,
                  child: DecoratedBox(
                    decoration: BoxDecoration(boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: .10),
                          blurRadius: 18,
                          offset: const Offset(0, 6))
                    ]),
                    child: RepaintBoundary(
                        key: _receiptKey,
                        child: TransactionReceipt(
                          data: data,
                          showNote: _showNote,
                          showTags: _showTags,
                          showAccount: _showAccount,
                          showLedger: _showLedger,
                        )),
                  ),
                ),
              )),
            )),
          ),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l10n.transactionReceiptFields,
                style: TextStyle(
                    color: BeeTokens.textSecondary(context), fontSize: 12)),
            const SizedBox(height: 10),
            BeeMultiSelect<String>(
              selectedValues: {
                if (_showNote) 'note',
                if (_showTags) 'tags',
                if (_showAccount) 'account',
                if (_showLedger) 'ledger'
              },
              options: [
                if (data.transaction.note?.trim().isNotEmpty ?? false)
                  BeeMultiSelectOption(
                      value: 'note',
                      label: l10n.importFieldNote,
                      key: const ValueKey('receipt-option-note')),
                if (data.tags.isNotEmpty)
                  BeeMultiSelectOption(
                      value: 'tags',
                      label: l10n.transactionReceiptTags,
                      key: const ValueKey('receipt-option-tags')),
                if (data.account != null || data.toAccount != null)
                  BeeMultiSelectOption(
                      value: 'account',
                      label: l10n.importFieldAccount,
                      key: const ValueKey('receipt-option-account')),
                BeeMultiSelectOption(
                    value: 'ledger',
                    label: l10n.transactionReceiptLedger,
                    key: const ValueKey('receipt-option-ledger')),
              ],
              onChanged: _busy
                  ? null
                  : (values) => setState(() {
                        _showNote = values.contains('note');
                        _showTags = values.contains('tags');
                        _showAccount = values.contains('account');
                        _showLedger = values.contains('ledger');
                      }),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Row(children: [
            Expanded(
                child: OutlinedButton.icon(
              key: const ValueKey('receipt-save'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BeeTokens.textPrimary(context),
                iconColor: BeeTokens.textPrimary(context),
                side: BorderSide(color: BeeTokens.borderStrong(context)),
              ),
              onPressed: _busy ? null : () => _export(share: false),
              icon: _busy && !_sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_alt_rounded, size: 18),
              label: Text(l10n.sharePosterSave),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: Builder(
                    builder: (buttonContext) => FilledButton.icon(
                          key: const ValueKey('receipt-share'),
                          style: FilledButton.styleFrom(
                            backgroundColor: BeeTokens.primary(context),
                            foregroundColor: BeeTokens.textOnColor(
                                BeeTokens.primary(context)),
                            iconColor: BeeTokens.textOnColor(
                                BeeTokens.primary(context)),
                          ),
                          onPressed: _busy
                              ? null
                              : () {
                                  final box = buttonContext.findRenderObject()
                                      as RenderBox;
                                  _export(
                                      share: true,
                                      anchor: box.localToGlobal(Offset.zero) &
                                          box.size);
                                },
                          icon: _busy && _sharing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.ios_share_rounded, size: 18),
                          label: Text(l10n.sharePosterShare),
                        ))),
          ]),
        ),
      ]),
    );
  }
}
