import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class CurrencyInfo {
  final String code;
  final String name;
  const CurrencyInfo(this.code, this.name);
}

const List<String> kCurrencyCodes = [
  'CNY',
  'USD',
  'EUR',
  'JPY',
  'HKD',
  'TWD',
  'GBP',
  'AUD',
  'CAD',
  'KRW',
  'SGD',
  'THB',
  'IDR',
  'INR',
  'RUB',
];

/// 获取本地化的货币信息列表
List<CurrencyInfo> getCurrencies(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    CurrencyInfo('CNY', l10n.currencyCNY),
    CurrencyInfo('USD', l10n.currencyUSD),
    CurrencyInfo('EUR', l10n.currencyEUR),
    CurrencyInfo('JPY', l10n.currencyJPY),
    CurrencyInfo('HKD', l10n.currencyHKD),
    CurrencyInfo('TWD', l10n.currencyTWD),
    CurrencyInfo('GBP', l10n.currencyGBP),
    CurrencyInfo('AUD', l10n.currencyAUD),
    CurrencyInfo('CAD', l10n.currencyCAD),
    CurrencyInfo('KRW', l10n.currencyKRW),
    CurrencyInfo('SGD', l10n.currencySGD),
    CurrencyInfo('THB', l10n.currencyTHB),
    CurrencyInfo('IDR', l10n.currencyIDR),
    CurrencyInfo('INR', l10n.currencyINR),
    CurrencyInfo('RUB', l10n.currencyRUB),
  ];
}

String displayCurrency(String code, BuildContext context) {
  final currencies = getCurrencies(context);
  final m = currencies.where((c) => c.code == code).toList();
  if (m.isEmpty) return code;
  return '${m.first.name} (${m.first.code})';
}

/// 获取指定货币代码的本地化名称
String getCurrencyName(String code, BuildContext context) {
  final currencies = getCurrencies(context);
  final m = currencies.where((c) => c.code == code).toList();
  if (m.isEmpty) return code;
  return m.first.name;
}

/// 获取币种符号
String getCurrencySymbol(String code) {
  switch (code) {
    case 'CNY':
      return '¥';
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'JPY':
      return '¥';
    case 'HKD':
      return 'HK\$';
    case 'TWD':
      return 'NT\$';
    case 'GBP':
      return '£';
    case 'AUD':
      return 'A\$';
    case 'CAD':
      return 'C\$';
    case 'KRW':
      return '₩';
    case 'SGD':
      return 'S\$';
    case 'THB':
      return '฿';
    case 'IDR':
      return 'Rp';
    case 'INR':
      return '₹';
    case 'RUB':
      return '₽';
    default:
      return code;
  }
}
