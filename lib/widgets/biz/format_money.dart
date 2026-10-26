import '../../utils/currencies.dart';
import '../../utils/format_utils.dart';

/// Shared by App bindings and AmountText. Currency selection, locale and
/// compact preference are resolved by the host; presentation packages only
/// receive the final display text.
String formatDisplayAmount(double value,
    {String? currencyCode,
    bool showCurrency = false,
    bool useCompactFormat = false,
    bool isChineseLocale = true,
    bool signed = true,
    int decimals = 2}) {
  if ((showCurrency || useCompactFormat) && currencyCode != null) {
    var formatted =
        formatBalance(value, currencyCode, isChineseLocale: isChineseLocale);
    final symbol = getCurrencySymbol(currencyCode.toUpperCase());
    if (!showCurrency && symbol.isNotEmpty && formatted.startsWith(symbol)) {
      formatted = formatted.substring(symbol.length).trimLeft();
    }
    if (useCompactFormat) return formatted;
    final plain =
        formatMoneyCompact(value, maxDecimals: decimals, signed: signed);
    return showCurrency ? '$symbol$plain' : plain;
  }
  return formatMoneyCompact(value, maxDecimals: decimals, signed: signed);
}

// 金额格式：最多保留2位小数，移除多余0和末尾小数点，添加千分号
String formatMoneyCompact(double v,
    {int maxDecimals = 2, bool signed = false, bool trimZeros = true}) {
  String formatWithThousandSeparator(double value) {
    String s = value.abs().toStringAsFixed(maxDecimals);

    // 分离整数和小数部分
    final parts = s.split('.');
    final intPart = parts[0];
    String decPart = parts.length > 1 ? parts[1] : '';

    // 移除小数部分末尾的0
    if (trimZeros) decPart = decPart.replaceFirst(RegExp(r'0+$'), '');

    // 添加千分号
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
    }

    // 组合结果
    if (decPart.isEmpty) {
      return buffer.toString();
    } else {
      return '${buffer.toString()}.$decPart';
    }
  }

  if (signed) {
    // 使用显式符号时，分别处理符号和数值
    final sign = v < 0 ? '-' : '+';
    return '$sign${formatWithThousandSeparator(v)}';
  } else {
    // 不使用显式符号时，保留数值的自然符号
    final sign = v < 0 ? '-' : '';
    return '$sign${formatWithThousandSeparator(v)}';
  }
}
