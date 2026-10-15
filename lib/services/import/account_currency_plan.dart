import '../data_import_service.dart';

/// Only external tables lack account definitions. Backups keep their own protocol.
class AccountCurrencyPlan {
  final ImportData data;
  final List<String> mappings;
  const AccountCurrencyPlan(this.data, this.mappings);
}

AccountCurrencyPlan planExternalAccountCurrencies(
  ImportData source, {
  required String ledgerCurrency,
  required Map<String, String> existingCurrencies,
}) {
  final explicit = <String, Set<String>>{};
  Iterable<String> names(ImportTransaction tx) => [
        tx.accountName,
        tx.fromAccountName,
        tx.toAccountName
      ].whereType<String>();
  for (final tx in source.transactions) {
    if (tx.currencyCode == null) continue;
    for (final name in names(tx)) {
      explicit.putIfAbsent(name, () => {}).add(tx.currencyCode!.toUpperCase());
    }
  }
  String currency(ImportTransaction tx) {
    if (tx.currencyCode != null) return tx.currencyCode!.toUpperCase();
    final account = names(tx).firstOrNull;
    if (account != null) {
      final existing = existingCurrencies[account];
      if (existing != null) return existing.toUpperCase();
      final codes = explicit[account];
      if (codes != null && codes.length == 1) return codes.single;
    }
    return ledgerCurrency.toUpperCase();
  }

  final allCurrencies = <String, Set<String>>{};
  for (final tx in source.transactions) {
    for (final name in names(tx)) {
      allCurrencies.putIfAbsent(name, () => {}).add(currency(tx));
    }
  }
  final occupied = {...existingCurrencies};
  final resolved = <(String, String), String>{};
  final accounts = <String, ImportAccount>{};
  final mappings = <String>[];
  String? resolve(String? name, String code) {
    if (name == null) return null;
    final key = (name, code);
    return resolved.putIfAbsent(key, () {
      final existing = existingCurrencies[name]?.toUpperCase();
      final split = (existing != null && existing != code) ||
          (existing == null && allCurrencies[name]!.length > 1);
      var target = split ? '$name $code' : name;
      var suffix = 2;
      while (occupied.containsKey(target) &&
          occupied[target]!.toUpperCase() != code) {
        target = '$name $code ${suffix++}';
      }
      occupied[target] = code;
      accounts[target] =
          ImportAccount(name: target, type: 'cash', currency: code);
      if (target != name) mappings.add('$name ($code) → $target');
      return target;
    });
  }

  final transactions = source.transactions.map((tx) {
    final code = currency(tx);
    return ImportTransaction(
      type: tx.type,
      amount: tx.amount,
      currencyCode: code,
      happenedAt: tx.happenedAt,
      categoryName: tx.categoryName,
      categoryKind: tx.categoryKind,
      categoryId: tx.categoryId,
      note: tx.note,
      accountName: resolve(tx.accountName, code),
      fromAccountName: resolve(tx.fromAccountName, code),
      toAccountName: resolve(tx.toAccountName, code),
      tagNames: tx.tagNames,
      attachments: tx.attachments,
      syncId: tx.syncId,
    );
  }).toList();
  return AccountCurrencyPlan(
      ImportData(
        accounts: accounts.values.toList(),
        transactions: transactions,
        categories: source.categories,
        tags: source.tags,
      ),
      mappings);
}
