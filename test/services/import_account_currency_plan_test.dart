import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/services/data_import_service.dart';
import 'package:beecount/services/import/account_currency_plan.dart';

void main() {
  ImportTransaction tx(String name, String? currency) => ImportTransaction(
      type: 'expense',
      amount: 2000,
      happenedAt: DateTime(2026, 10, 1),
      accountName: name,
      currencyCode: currency);
  test('CNY 账本中的新 JPY 账户保留账户及交易原币', () {
    final plan = planExternalAccountCurrencies(
        ImportData(transactions: [tx('现金', 'CNY'), tx('日元', 'JPY')]),
        ledgerCurrency: 'CNY',
        existingCurrencies: {});
    expect(plan.data.accounts.map((a) => a.currency), ['CNY', 'JPY']);
    expect(plan.data.transactions.last.currencyCode, 'JPY');
    expect(plan.data.transactions.last.amount, 2000);
    expect(plan.mappings, isEmpty);
  });
  test('同名多币种拆分，现有账户币种不被覆盖，冲突名称不会复用错误币种', () {
    final plan = planExternalAccountCurrencies(
        ImportData(transactions: [tx('银行', 'USD'), tx('银行', 'JPY')]),
        ledgerCurrency: 'CNY',
        existingCurrencies: {'银行': 'CNY', '银行 USD': 'JPY'});
    expect(plan.data.accounts.map((a) => a.name), ['银行 USD 2', '银行 JPY']);
    expect(plan.data.transactions.first.accountName, '银行 USD 2');
    expect(plan.mappings.length, 2);
  });
  test('缺失币种继承已有账户，否则继承单一明确币种，再回退账本', () {
    final plan = planExternalAccountCurrencies(
        ImportData(transactions: [
          tx('旧银行', null),
          tx('日元', 'JPY'),
          tx('日元', null),
          tx('钱包', null)
        ]),
        ledgerCurrency: 'CNY',
        existingCurrencies: {'旧银行': 'USD'});
    expect(plan.data.transactions.map((t) => t.currencyCode),
        ['USD', 'JPY', 'JPY', 'CNY']);
  });
}
