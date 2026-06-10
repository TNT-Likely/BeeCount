/// 多币种 MVP 的纯函数层:不碰 IO,可单测。
/// 方向约定:EffectiveRate.rate = 「1 quote = rate base」(decimal 字符串)。
/// 红线:汇率缺失就是缺失,绝不静默回落 1.0(README D5,Maybe 的已知 bug 教训)。
library;

class EffectiveRate {
  final String rate;
  final bool manual;
  final String? rateDate; // 自动来源的数据日期;手动为 null
  const EffectiveRate({required this.rate, required this.manual, this.rateDate});
}

/// 倒数:输入「1 base = x quote」,输出「1 quote = ? base」字符串(12 位有效数字)。
String invertRate(num oneBaseEqualsXQuote) {
  if (oneBaseEqualsXQuote <= 0) {
    throw ArgumentError.value(oneBaseEqualsXQuote, 'oneBaseEqualsXQuote', '必须为正数');
  }
  return (1 / oneBaseEqualsXQuote).toStringAsPrecision(12);
}

/// 合成有效汇率:手动 > 最新自动;两边都没有的 quote 不出现在结果里。
Map<String, EffectiveRate> mergeEffectiveRates({
  required List<({String quote, String rate, String rateDate})> autoRates,
  required List<({String quote, String rate})> overrides,
}) {
  final result = <String, EffectiveRate>{};
  for (final a in autoRates) {
    result[a.quote.toUpperCase()] =
        EffectiveRate(rate: a.rate, manual: false, rateDate: a.rateDate);
  }
  for (final o in overrides) {
    result[o.quote.toUpperCase()] = EffectiveRate(rate: o.rate, manual: true);
  }
  return result;
}

class ConvertedNetWorth {
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final Map<String, double> netByCurrency; // 每币种净值折 base(仅可折算的)
  final List<String> missingCurrencies; // 缺汇率 → 被剔除,UI 必须显式标示
  final String? oldestRateDate; // 参与折算的最旧自动日期(脚注用);全手动为 null
  const ConvertedNetWorth({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.netByCurrency,
    required this.missingCurrencies,
    required this.oldestRateDate,
  });
}

/// 通用折算:按币种金额表折到 base。供净资产明细/分组小计/构成图复用。
/// base 自身 rate=1;某币种缺有效汇率(rate 解析失败 / 非正)→ 剔除并列入 missing,
/// 绝不静默按 1.0 折入(README D5)。missing 已排序便于 UI 稳定展示。
({double total, Map<String, double> convertedByCurrency, List<String> missingCurrencies})
    convertAmountsToBase({
  required Map<String, double> amounts, // 币种(任意大小写) -> 原币金额
  required Map<String, EffectiveRate> rates,
  required String base,
}) {
  var total = 0.0;
  final convertedByCurrency = <String, double>{};
  final missing = <String>[];
  final baseUp = base.toUpperCase();
  for (final e in amounts.entries) {
    final code = e.key.toUpperCase();
    double? rate;
    if (code == baseUp) {
      rate = 1.0;
    } else {
      final eff = rates[code];
      if (eff != null) rate = double.tryParse(eff.rate);
    }
    if (rate == null || rate <= 0) {
      missing.add(code);
      continue;
    }
    final converted = e.value * rate;
    convertedByCurrency[code] = converted;
    total += converted;
  }
  missing.sort();
  return (total: total, convertedByCurrency: convertedByCurrency, missingCurrencies: missing);
}

/// 折算聚合(double 仅展示用,不落库 —— README D8)。
ConvertedNetWorth computeConvertedNetWorth({
  required Map<String, ({double totalAssets, double totalLiabilities, double netWorth})> breakdown,
  required Map<String, EffectiveRate> rates,
  required String base,
}) {
  var assets = 0.0, liabilities = 0.0, net = 0.0;
  final netByCurrency = <String, double>{};
  final missing = <String>[];
  String? oldest;
  final baseUp = base.toUpperCase();
  for (final e in breakdown.entries) {
    final code = e.key.toUpperCase();
    double? rate;
    String? rateDate;
    if (code == baseUp) {
      rate = 1.0;
    } else {
      final eff = rates[code];
      if (eff != null) {
        rate = double.tryParse(eff.rate);
        rateDate = eff.rateDate;
      }
    }
    if (rate == null || rate <= 0) {
      missing.add(code);
      continue;
    }
    // 仅参与折算的币种才计入最旧日期(spec:参与折算的最旧自动日期)
    if (rateDate != null && (oldest == null || rateDate.compareTo(oldest) < 0)) {
      oldest = rateDate;
    }
    assets += e.value.totalAssets * rate;
    liabilities += e.value.totalLiabilities * rate;
    net += e.value.netWorth * rate;
    netByCurrency[code] = e.value.netWorth * rate;
  }
  missing.sort();
  return ConvertedNetWorth(
    totalAssets: assets,
    totalLiabilities: liabilities,
    netWorth: net,
    netByCurrency: netByCurrency,
    missingCurrencies: missing,
    oldestRateDate: oldest,
  );
}
