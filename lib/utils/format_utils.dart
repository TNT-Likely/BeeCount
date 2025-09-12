/// 格式化工具函数
/// 
/// 包含各种数据格式化的工具函数
library;

/// 格式化余额显示，大数字用千、万单位
String formatBalance(double balance) {
  final absBalance = balance.abs();
  final sign = balance >= 0 ? '¥' : '-¥';
  
  if (absBalance >= 10000) {
    // 万元以上显示万单位
    final wan = absBalance / 10000;
    return '$sign${wan.toStringAsFixed(1)}万';
  } else if (absBalance >= 1000) {
    // 千元以上显示千单位
    final qian = absBalance / 1000;
    return '$sign${qian.toStringAsFixed(1)}k';
  } else {
    // 千元以下显示原始金额
    return '$sign${absBalance.toStringAsFixed(2)}';
  }
}