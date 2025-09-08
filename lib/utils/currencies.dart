class CurrencyInfo {
  final String code;
  final String name;
  const CurrencyInfo(this.code, this.name);
}

const List<CurrencyInfo> kCurrencies = [
  CurrencyInfo('CNY', '人民币'),
  CurrencyInfo('USD', '美元'),
  CurrencyInfo('EUR', '欧元'),
  CurrencyInfo('JPY', '日元'),
  CurrencyInfo('HKD', '港币'),
  CurrencyInfo('TWD', '新台币'),
  CurrencyInfo('GBP', '英镑'),
  CurrencyInfo('AUD', '澳元'),
  CurrencyInfo('CAD', '加元'),
  CurrencyInfo('KRW', '韩元'),
  CurrencyInfo('SGD', '新加坡元'),
  CurrencyInfo('THB', '泰铢'),
  CurrencyInfo('IDR', '印尼卢比'),
  CurrencyInfo('INR', '印度卢比'),
  CurrencyInfo('RUB', '卢布'),
];

String displayCurrency(String code) {
  final m = kCurrencies.where((c) => c.code == code).toList();
  if (m.isEmpty) return code;
  return '${m.first.name} (${m.first.code})';
}
