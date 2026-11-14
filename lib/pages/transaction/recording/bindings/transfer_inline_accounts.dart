import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/db.dart';
import '../../../../data/repositories/local/local_repository.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../../providers.dart';
import '../../../../providers/shared_ledger_providers.dart';
import '../../../../utils/account_type_utils.dart';
import '../../../../utils/shared_ledger_picker_filter.dart';

typedef TransferInlineAccountQuery = ({int ledgerId, int? fromPin, int? toPin});
final transferInlineAccountsProvider = FutureProvider.autoDispose
    .family<List<Account>, TransferInlineAccountQuery>((ref, query) async {
  ref.watch(sharedResourceRefreshProvider);
  ref.watch(syncGenerationProvider);
  final repo = ref.watch(repositoryProvider);
  var accounts = await repo.getAllAccounts();
  if (repo is LocalRepository) {
    final scope = await repo.db.loadLedgerPickerContext(query.ledgerId);
    accounts = await repo.db.filterAccountsForLedger(accounts, scope);
  } else {
    accounts = accounts.where((account) => !account.hidden).toList();
  }
  // Preserve the existing pinned hidden-account compatibility for editing and
  // copying; other hidden accounts never become new candidates.
  for (final id in {query.fromPin, query.toPin}) {
    if (id == null || accounts.any((account) => account.id == id)) continue;
    final account = await lookupTransferInlineAccount(repo, id);
    if (account?.hidden == true) accounts = [...accounts, account!];
  }
  return accounts;
});

Future<Account?> lookupTransferInlineAccount(
    BaseRepository repo, int id) async {
  if (id >= 0) return repo.getAccount(id);
  if (repo is! LocalRepository) return null;
  return repo.db.findAccountBySyntheticId(id);
}

bool isTransferInlineAccountEligible(Account account,
        {required Set<int> pinnedIds, required bool editing}) =>
    isTradableType(account.type) ||
    (account.hidden && pinnedIds.contains(account.id)) ||
    (editing && pinnedIds.contains(account.id));

/// Final write guard uses current production account filtering, rather than a
/// stale picker list. Only an unchanged historical pair may stay cross-currency.
Future<void> validateTransferInlineWrite(
  WidgetRef ref, {
  required int ledgerId,
  required int fromAccountId,
  required int toAccountId,
  required double amount,
  required String? currencyCode,
  required double? nativeAmount,
  required int? editingId,
  Set<int> pinnedAccountIds = const {},
}) async {
  if (fromAccountId == toAccountId) {
    throw StateError('Transfer accounts must be different');
  }
  if (!amount.isFinite ||
      amount <= 0 ||
      nativeAmount == null ||
      !nativeAmount.isFinite ||
      nativeAmount <= 0) {
    throw StateError('Invalid transfer amount or conversion');
  }
  final repo = ref.read(repositoryProvider);
  final existing =
      editingId == null ? null : await repo.getTransactionById(editingId);
  final oldFrom = existing?.accountSyncIdOverride == null
      ? existing?.accountId
      : syntheticIdForSyncId(existing!.accountSyncIdOverride!);
  final oldTo = existing?.toAccountSyncIdOverride == null
      ? existing?.toAccountId
      : syntheticIdForSyncId(existing!.toAccountSyncIdOverride!);
  final originalPair = existing?.type == 'transfer' &&
      oldFrom == fromAccountId &&
      oldTo == toAccountId;
  final pins = {
    ...pinnedAccountIds,
    if (oldFrom != null) oldFrom,
    if (oldTo != null) oldTo
  };
  var available = await repo.getAllAccounts();
  if (repo is LocalRepository) {
    available = await repo.db.filterAccountsForLedger(
        available, await repo.db.loadLedgerPickerContext(ledgerId));
  } else {
    available = available.where((account) => !account.hidden).toList();
  }
  Future<Account> resolve(int id) async {
    Account? value;
    for (final account in available) {
      if (account.id == id) {
        value = account;
        break;
      }
    }
    if (value == null && pins.contains(id)) {
      final pinned = await lookupTransferInlineAccount(repo, id);
      if (pinned?.hidden == true) value = pinned;
    }
    if (value == null ||
        !isTransferInlineAccountEligible(value,
            pinnedIds: pins, editing: existing != null)) {
      throw StateError('Transfer account is no longer available');
    }
    return value;
  }

  final from = await resolve(fromAccountId), to = await resolve(toAccountId);
  final sameCurrency = from.currency.toUpperCase() == to.currency.toUpperCase();
  if (!sameCurrency && !originalPair) {
    throw StateError('Transfer accounts must use the same currency');
  }
  final expectedCurrency =
      originalPair ? (existing!.currencyCode ?? from.currency) : from.currency;
  if (currencyCode?.toUpperCase() != expectedCurrency.toUpperCase()) {
    throw StateError('Transfer currency does not match the selected account');
  }
  final ledger = await repo.getLedgerById(ledgerId);
  if (ledger == null) throw StateError('Transfer ledger is unavailable');
  if (expectedCurrency.toUpperCase() == ledger.currency.toUpperCase() &&
      (nativeAmount - amount).abs() > 1e-9) {
    throw StateError('Invalid native-currency transfer snapshot');
  }
}
