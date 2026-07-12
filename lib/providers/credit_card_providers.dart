import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../providers.dart';

/// 所有信用卡账户
final creditCardAccountsProvider = FutureProvider<List<Account>>((ref) async {
  // 监听账户变化
  ref.watch(allAccountsStreamProvider);
  final repo = ref.watch(repositoryProvider);
  return repo.getCreditCardAccounts();
});

/// 信用卡已用额度（per account）
final creditCardUsedAmountProvider =
    FutureProvider.family<double, int>((ref, accountId) async {
  // 监听交易变化
  ref.watch(statsRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  return repo.getCreditCardUsedAmount(accountId);
});

/// 信用卡可用额度（per account）= creditLimit - usedAmount
final creditCardAvailableAmountProvider =
    FutureProvider.family<double?, int>((ref, accountId) async {
  final repo = ref.watch(repositoryProvider);
  final account = await repo.getAccount(accountId);
  if (account == null || account.creditLimit == null) return null;

  final usedAmount =
      await ref.watch(creditCardUsedAmountProvider(accountId).future);
  return account.creditLimit! - usedAmount;
});
