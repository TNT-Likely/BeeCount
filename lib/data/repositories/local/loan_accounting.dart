import '../../db.dart';
import '../../../utils/app_localizations_resolver.dart';
import '../../../utils/account_type_utils.dart';
import 'local_account_repository.dart';

class LoanAccountingException implements Exception {
  final String code;
  const LoanAccountingException(this.code);
  @override
  String toString() {
    final l10n = resolveAppLocalizations(null);
    return switch (code) {
      'loanNeedsReview' => l10n.loanNeedsReview,
      'loanTransferOnly' => l10n.loanTransferOnly,
      'loanPersonalLedgerOnly' => l10n.loanPersonalLedgerOnly,
      'loanSameCurrencyOnly' => l10n.loanSameCurrencyOnly,
      'loanBeforeBaseline' => l10n.loanBeforeBaseline,
      'loanRepaymentExceedsDebt' => l10n.loanRepaymentExceedsDebt,
      _ => code,
    };
  }
}

/// 校验一次完整资金变动，调用者须与写入放在同一个数据库事务中。
class LoanAccountingGuard {
  final BeeDatabase db;
  LoanAccountingGuard(this.db);

  Future<void> validate({
    Transaction? before,
    String? type,
    double? amount,
    int? accountId,
    int? toAccountId,
    DateTime? happenedAt,
    int? ledgerId,
  }) async {
    final ids = {before?.accountId, before?.toAccountId, accountId, toAccountId}
      ..remove(null);
    if (ids.isEmpty) return;
    final accounts = await (db.select(db.accounts)
          ..where((a) => a.id.isIn(ids.cast<int>().toList())))
        .get();
    for (final loan in accounts.where((a) => a.type == 'loan')) {
      final touchedAfter =
          type != null && (loan.id == accountId || loan.id == toAccountId);
      final financialChange = before == null ||
          type == null ||
          before.type != type ||
          before.amount != amount ||
          before.accountId != accountId ||
          before.toAccountId != toAccountId ||
          happenedAt == null ||
          !before.happenedAt.isAtSameMomentAs(happenedAt);
      if (!financialChange) continue;
      if (loan.loanBalanceVersion != 1) {
        throw const LoanAccountingException('loanNeedsReview');
      }
      if (touchedAfter) {
        if (type != 'transfer' ||
            amount == null ||
            !amount.isFinite ||
            amount <= 0 ||
            accountId == toAccountId ||
            accountId == null ||
            toAccountId == null) {
          throw const LoanAccountingException('loanTransferOnly');
        }
        final ledger = await (db.select(db.ledgers)
              ..where((l) => l.id.equals(ledgerId ?? before?.ledgerId ?? -1)))
            .getSingleOrNull();
        if (ledger?.isShared == true)
          throw const LoanAccountingException('loanPersonalLedgerOnly');
        final pair = accounts
            .where((a) => a.id == accountId || a.id == toAccountId)
            .toList();
        if (pair.any((account) => isValuationOnlyType(account.type))) {
          throw const LoanAccountingException('loanTransferOnly');
        }
        if (pair.length != 2 || pair[0].currency != pair[1].currency) {
          throw const LoanAccountingException('loanSameCurrencyOnly');
        }
      }
      if (financialChange && loan.loanBalanceSince != null) {
        if ((touchedAfter &&
                happenedAt != null &&
                happenedAt.isBefore(loan.loanBalanceSince!)) ||
            (before != null &&
                before.happenedAt.isBefore(loan.loanBalanceSince!))) {
          throw const LoanAccountingException('loanBeforeBaseline');
        }
      }
      double movement(String? kind, double? value, int? from, int? to) {
        if (kind == null || value == null) return 0;
        if (from == loan.id) return kind == 'income' ? value : -value;
        return kind == 'transfer' && to == loan.id ? value : 0;
      }

      final balance =
          await LocalAccountRepository(db).getAccountBalance(loan.id);
      final next = balance -
          movement(before?.type, before?.amount, before?.accountId,
              before?.toAccountId) +
          movement(type, amount, accountId, toAccountId);
      if (next > 0.0000001)
        throw const LoanAccountingException('loanRepaymentExceedsDebt');
    }
  }
}
