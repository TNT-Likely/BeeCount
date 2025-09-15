// 金额格式：最多保留2位小数，移除多余0和末尾小数点
String formatMoneyCompact(double v,
    {int maxDecimals = 2, bool signed = false}) {
  if (signed) {
    // 使用显式符号时，分别处理符号和数值
    final sign = v < 0 ? '-' : '+';
    String s = v.abs().toStringAsFixed(maxDecimals);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return '$sign$s';
  } else {
    // 不使用显式符号时，保留数值的自然符号
    String s = v.toStringAsFixed(maxDecimals);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }
}
