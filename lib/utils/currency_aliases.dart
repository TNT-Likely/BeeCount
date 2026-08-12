/// 口语 / 符号 / 英文名 → ISO 4217 币种码。
///
/// 智能记账多币种(.docs/multi-currency-ai A4)的解析层:AI 大多数时候会直接
/// 吐 ISO 码,但语音转写、本地小模型、用户自定义 prompt 都可能给出「美元」
/// 「$」「dollar」这类口语表达,这里统一归一。
///
/// **红线:歧义就不猜。** `$` 可能是 USD/AUD/CAD/SGD/HKD/…,`¥` 可能是 CNY 或
/// JPY。没有上下文能唯一确定时返回 `null`,交由调用方回落账本本位币 —— 把一笔
/// JPY 记成 CNY 的代价(金额差 ~20 倍)远高于「没识别出币种」。
///
/// 符号表与英文名表**从 [kCurrencyCodes] 自动派生**,新增币种(#273 已扩到全量
/// 151 种)无需在本文件登记;只有中文别名需要手工维护。
library;

import 'currencies.dart';

/// 该 code 是否是本 App 支持的 ISO 4217 币种。
bool isKnownCurrencyCode(String code) =>
    _allCodes.contains(code.trim().toUpperCase());

/// 把任意币种表达解析成 ISO 码;无法唯一确定时返回 null。
///
/// [disambiguateWith] 消歧上下文,通常传「账本本位币 ∪ 已有账户币种 ∪ 用户
/// 主币种」。歧义候选与它的交集**恰好一个**时才采纳。
String? currencyCodeFromAlias(String raw, {Set<String>? disambiguateWith}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  // 1. 本身就是 ISO 码
  final upper = trimmed.toUpperCase();
  if (_allCodes.contains(upper)) return upper;

  final lower = trimmed.toLowerCase();

  // 2. 中文别名(手工维护;含简繁)
  final zhHit = _zhAliases[trimmed];
  if (zhHit != null) return _pick(zhHit, disambiguateWith);

  // 3. 英文全名(派生自币种表,如 'US Dollar' / 'Japanese Yen')
  final fullHit = _enFullNameToCodes[lower];
  if (fullHit != null) return _pick(fullHit, disambiguateWith);

  // 4. 英文名末词(dollar / yen / pound…;复数 s 去掉再试)
  final word = lower.endsWith('s') ? lower.substring(0, lower.length - 1) : lower;
  final wordHit = _enWordToCodes[word];
  if (wordHit != null) return _pick(wordHit, disambiguateWith);

  // 5. 符号(派生自币种表)
  final symHit = _symbolToCodes[trimmed];
  if (symHit != null) return _pick(symHit, disambiguateWith);

  return null;
}

/// 候选集唯一 → 直接采纳;多个 → 用上下文求交,交集恰好一个才采纳,否则不猜。
String? _pick(Set<String> candidates, Set<String>? context) {
  if (candidates.length == 1) return candidates.first;
  if (context == null || context.isEmpty) return null;
  final ctx = context.map((c) => c.trim().toUpperCase()).toSet();
  final hit = candidates.intersection(ctx);
  return hit.length == 1 ? hit.first : null;
}

// ── 派生表(懒加载,构建一次)────────────────────────────────────────────

final Set<String> _allCodes = kCurrencyCodes.map((c) => c.toUpperCase()).toSet();

/// 符号 → 候选码集合。`getCurrencySymbol` 对长尾币种回退成 code 本身,
/// 那种「符号 == code」的不算符号,跳过(否则 'KES' 会被当符号重复登记)。
final Map<String, Set<String>> _symbolToCodes = () {
  final map = <String, Set<String>>{};
  for (final code in _allCodes) {
    final sym = getCurrencySymbol(code);
    if (sym.isEmpty || sym.toUpperCase() == code) continue;
    (map[sym] ??= <String>{}).add(code);
  }
  // 全角人民币/日元符号与半角同义
  final half = map['¥'];
  if (half != null) map['￥'] = half;
  // 币种表里没有、但书写中常见的写法
  map['US\$'] = {'USD'};
  map['RMB'] = {'CNY'};
  map['rmb'] = {'CNY'};
  map['₤'] = {'GBP'};
  return map;
}();

/// 英文全名(小写)→ 候选码集合。
final Map<String, Set<String>> _enFullNameToCodes = () {
  final map = <String, Set<String>>{};
  for (final code in _allCodes) {
    final name = currencyEnglishName(code).toLowerCase();
    if (name == code.toLowerCase()) continue;
    (map[name] ??= <String>{}).add(code);
  }
  return map;
}();

/// 英文名末词(小写)→ 候选码集合。'US Dollar' → 'dollar'(歧义,多国共用)。
final Map<String, Set<String>> _enWordToCodes = () {
  final map = <String, Set<String>>{};
  for (final code in _allCodes) {
    final name = currencyEnglishName(code);
    if (name.toUpperCase() == code) continue;
    final parts = name.toLowerCase().split(RegExp(r'\s+'));
    if (parts.isEmpty) continue;
    (map[parts.last] ??= <String>{}).add(code);
  }
  return map;
}();

/// 中文别名 → 候选码集合。只登记口语高频的;长尾靠 AI 直出 ISO 码。
/// 值是集合:一词多币的(卢比 / 比索 / 里拉)登记成多候选,靠上下文消歧。
const Map<String, Set<String>> _zhAliases = {
  // 无歧义
  '人民币': {'CNY'}, '人民幣': {'CNY'}, '元人民币': {'CNY'}, '软妹币': {'CNY'},
  '美元': {'USD'}, '美金': {'USD'}, '美刀': {'USD'},
  '日元': {'JPY'}, '日圆': {'JPY'}, '日圓': {'JPY'}, '日币': {'JPY'}, '日幣': {'JPY'},
  '欧元': {'EUR'}, '歐元': {'EUR'},
  '英镑': {'GBP'}, '英鎊': {'GBP'},
  '港币': {'HKD'}, '港幣': {'HKD'}, '港元': {'HKD'},
  '新台币': {'TWD'}, '新臺幣': {'TWD'}, '台币': {'TWD'}, '臺幣': {'TWD'},
  '韩元': {'KRW'}, '韓元': {'KRW'}, '韩币': {'KRW'}, '韓幣': {'KRW'},
  '泰铢': {'THB'}, '泰銖': {'THB'},
  '新加坡元': {'SGD'}, '坡币': {'SGD'}, '坡幣': {'SGD'}, '新币': {'SGD'}, '新幣': {'SGD'},
  '澳元': {'AUD'}, '澳币': {'AUD'}, '澳幣': {'AUD'}, '澳大利亚元': {'AUD'},
  '加元': {'CAD'}, '加币': {'CAD'}, '加幣': {'CAD'}, '加拿大元': {'CAD'},
  '瑞郎': {'CHF'}, '瑞士法郎': {'CHF'},
  '卢布': {'RUB'}, '盧布': {'RUB'},
  '越南盾': {'VND'}, '盾': {'VND'},
  '林吉特': {'MYR'}, '马币': {'MYR'}, '馬幣': {'MYR'},
  '印尼盾': {'IDR'}, '印尼盧比': {'IDR'},
  '纽币': {'NZD'}, '紐幣': {'NZD'}, '新西兰元': {'NZD'}, '紐西蘭元': {'NZD'},
  '雷亚尔': {'BRL'}, '雷亞爾': {'BRL'},
  '兰特': {'ZAR'}, '蘭特': {'ZAR'},
  '澳门元': {'MOP'}, '澳門元': {'MOP'}, '澳门币': {'MOP'}, '澳門幣': {'MOP'},
  '印度卢比': {'INR'}, '印度盧比': {'INR'},
  '菲律宾比索': {'PHP'}, '菲律賓披索': {'PHP'},
  '土耳其里拉': {'TRY'},
  '沙特里亚尔': {'SAR'},
  '迪拉姆': {'AED'}, // 严格说 MAD 也叫迪拉姆,但中文语境下几乎专指阿联酋
  // 有歧义 —— 靠 disambiguateWith
  '卢比': {'INR', 'PKR', 'LKR', 'NPR', 'IDR'},
  '盧比': {'INR', 'PKR', 'LKR', 'NPR', 'IDR'},
  '比索': {'PHP', 'MXN', 'ARS', 'CLP', 'COP', 'UYU'},
  '披索': {'PHP', 'MXN', 'ARS', 'CLP', 'COP', 'UYU'},
  '里拉': {'TRY', 'LBP'},
  '法郎': {'CHF', 'XAF', 'XOF', 'XPF'},
};
