/// 金额规范化：四舍五入到分（两位小数），消除浮点精度误差
///
/// 用于存储金额前调用，防止误差累积
/// 注意：这不会改变用户的实际输入，只是修正浮点表示误差
/// 例如: 用户输入 19.90，计算机可能存储为 19.899999999999999，此函数将其修正回 19.90
double sanitizeAmount(double amount) {
  return double.parse(amount.toStringAsFixed(2));
}

/// 添加千分位分隔符，并移除小数末尾多余的0
String _formatWithThousandSeparator(double value, int maxDecimals) {
  String s = value.abs().toStringAsFixed(maxDecimals);

  // 分离整数和小数部分
  final parts = s.split('.');
  final intPart = parts[0];
  String decPart = parts.length > 1 ? parts[1] : '';

  // 移除小数部分末尾的0
  decPart = decPart.replaceFirst(RegExp(r'0+$'), '');

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
  }
  return '${buffer.toString()}.$decPart';
}

/// 金额格式：最多保留2位小数，移除多余0和末尾小数点，添加千分号
String formatMoneyCompact(double v,
    {int maxDecimals = 2, bool signed = false}) {
  // 修复浮点精度问题：当绝对值小于 0.005 时（四舍五入后为 0），视为 0 处理，避免显示 -0
  if (v.abs() < 0.005) {
    v = 0.0;
  }

  final formatted = _formatWithThousandSeparator(v, maxDecimals);

  if (signed) {
    // 使用显式符号时，分别处理符号和数值
    final sign = v < 0 ? '-' : '+';
    return '$sign$formatted';
  }

  // 不使用显式符号时，保留数值的自然符号
  final sign = v < 0 ? '-' : '';
  return '$sign$formatted';
}
