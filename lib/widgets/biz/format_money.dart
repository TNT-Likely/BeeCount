// 金额格式：最多保留2位小数，移除多余0和末尾小数点
String formatMoneyCompact(double v,
    {int maxDecimals = 2, bool signed = false}) {
  final sign = signed ? (v < 0 ? '-' : '+') : '';
  String s = v.abs().toStringAsFixed(maxDecimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return '$sign$s';
}
