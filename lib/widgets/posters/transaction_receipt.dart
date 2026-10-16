import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/category_utils.dart';

/// A read-only snapshot. Receipt options never write back to the transaction.
class TransactionReceiptData {
  final Transaction transaction;
  final Ledger ledger;
  final Category? category;
  final Account? account;
  final Account? toAccount;
  final List<Tag> tags;

  const TransactionReceiptData({
    required this.transaction,
    required this.ledger,
    this.category,
    this.account,
    this.toAccount,
    this.tags = const [],
  });
}

class TransactionReceipt extends StatelessWidget {
  final TransactionReceiptData data;
  final bool showNote;
  final bool showTags;
  final bool showAccount;
  final bool showLedger;

  const TransactionReceipt({
    super.key,
    required this.data,
    this.showNote = true,
    this.showTags = true,
    this.showAccount = false,
    this.showLedger = false,
  });

  static const ink = Color(0xFF302D27);
  static const muted = Color(0xFF898275);
  static const paper = Color(0xFFFFFDF7);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tx = data.transaction;
    final locale = Localizations.localeOf(context).toString();
    final currency =
        tx.currencyCode ?? data.account?.currency ?? data.ledger.currency;
    final amount =
        NumberFormat.currency(locale: locale, name: currency, symbol: '')
            .format(tx.amount.abs())
            .trim();
    final kind = switch (tx.type) {
      'income' => l10n.homeIncome,
      'transfer' => l10n.transferTitle,
      _ => l10n.homeExpense,
    };

    return MediaQuery.withNoTextScaling(
      child: ClipPath(
        clipper: const _ReceiptEdge(),
        child: DecoratedBox(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFEFA), Color(0xFFF9F3E6)],
          )),
          child: DefaultTextStyle(
            style: const TextStyle(fontSize: 12, height: 1.5, color: ink),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 25, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Image.asset('assets/logo2.png', width: 28, height: 28),
                    const SizedBox(width: 9),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.sharePosterAppName,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2)),
                          Text('BEECOUNT',
                              style: TextStyle(
                                  fontSize: 8,
                                  color: muted.withValues(alpha: .8),
                                  letterSpacing: 2.5)),
                        ]),
                  ]),
                  const SizedBox(height: 18),
                  const _Perforation(),
                  const SizedBox(height: 18),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(
                        width: 12,
                        height: 2,
                        child: ColoredBox(color: Color(0xFFD6B86A))),
                    const SizedBox(width: 8),
                    Text(kind,
                        style: const TextStyle(
                            color: muted, fontSize: 11, letterSpacing: 2)),
                    const SizedBox(width: 8),
                    const SizedBox(
                        width: 12,
                        height: 2,
                        child: ColoredBox(color: Color(0xFFD6B86A))),
                  ]),
                  const SizedBox(height: 8),
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${tx.type == 'expense' ? '−' : tx.type == 'income' ? '+' : ''}$amount',
                        key: const ValueKey('receipt-amount'),
                        style: const TextStyle(
                            fontSize: 42,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.5,
                            fontFeatures: [FontFeature.tabularFigures()]),
                      )),
                  const SizedBox(height: 5),
                  Text(currency,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: muted, fontSize: 10, letterSpacing: 2.5)),
                  const SizedBox(height: 18),
                  const _Perforation(),
                  const SizedBox(height: 16),
                  if (tx.type != 'transfer')
                    _line(
                        l10n.importFieldCategory,
                        CategoryUtils.getDisplayName(
                            data.category?.name, context,
                            kind: tx.type)),
                  _line(
                      l10n.importFieldDate,
                      DateFormat('yyyy.MM.dd  HH:mm', locale)
                          .format(tx.happenedAt)),
                  if (showAccount && tx.type == 'transfer') ...[
                    if (data.account != null)
                      _line(l10n.transferFromAccount, data.account!.name),
                    if (data.toAccount != null)
                      _line(l10n.transferToAccount, data.toAccount!.name),
                  ] else if (showAccount && data.account != null)
                    _line(l10n.importFieldAccount, data.account!.name),
                  if (showLedger)
                    _line(l10n.transactionReceiptLedger, data.ledger.name),
                  if (showTags && data.tags.isNotEmpty)
                    _line(l10n.transactionReceiptTags,
                        data.tags.map((t) => '#${t.name}').join('  ')),
                  if (showNote && (tx.note?.trim().isNotEmpty ?? false)) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEBDDB8).withValues(alpha: .22),
                          borderRadius: BorderRadius.circular(6)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.importFieldNote,
                                style:
                                    const TextStyle(color: muted, fontSize: 9)),
                            const SizedBox(height: 3),
                            Text(tx.note!,
                                key: const ValueKey('receipt-note'),
                                style:
                                    const TextStyle(fontSize: 12, height: 1.6)),
                          ]),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const _Perforation(),
                  const SizedBox(height: 15),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _dot(3),
                    const SizedBox(width: 5),
                    _dot(4),
                    const SizedBox(width: 5),
                    _dot(3),
                  ]),
                  const SizedBox(height: 8),
                  Text(l10n.transactionReceiptFooter,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: muted, fontSize: 10, letterSpacing: .5)),
                  const SizedBox(height: 4),
                  Text(l10n.transactionReceiptTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: muted.withValues(alpha: .65),
                          fontSize: 8,
                          letterSpacing: 2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(double size) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
          color: Color(0xFFD6B86A), shape: BoxShape.circle));

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Flexible(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(color: muted, fontSize: 11))),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: Text(value, textAlign: TextAlign.right)),
        ]),
      );
}

class _Perforation extends StatelessWidget {
  const _Perforation();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (_, constraints) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
                (constraints.maxWidth / 8).floor(),
                (_) => const SizedBox(
                    width: 4,
                    height: 1,
                    child: ColoredBox(color: Color(0xFFD8D1C3)))),
          ));
}

class _ReceiptEdge extends CustomClipper<Path> {
  const _ReceiptEdge();
  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(0, 6);
    final count = (size.width / 12).round();
    final step = size.width / count;
    for (var i = 0; i < count; i++) {
      path
        ..lineTo((i + .5) * step, 0)
        ..lineTo((i + 1) * step, 6);
    }
    path.lineTo(size.width, size.height - 6);
    for (var i = count - 1; i >= 0; i--) {
      path
        ..lineTo((i + .5) * step, size.height)
        ..lineTo(i * step, size.height - 6);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_ReceiptEdge oldClipper) => false;
}
