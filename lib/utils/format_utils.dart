/// 格式化工具函数
///
/// 包含各种数据格式化的工具函数
library;

import 'currencies.dart';

/// 格式化余额显示，支持多语言单位和多币种
///
/// [balance] 金额
/// [currencyCode] 币种代码 (如 'CNY', 'USD')
/// [isChineseLocale] 是否为中文环境，中文显示万单位，其他语言显示k/M单位
String formatBalance(double balance, String currencyCode,
    {bool isChineseLocale = true}) {
  final absBalance = balance.abs();
  final currencySymbol = getCurrencySymbol(currencyCode);
  final sign = balance >= 0 ? currencySymbol : '-$currencySymbol';

  if (isChineseLocale) {
    // 中文环境：使用万作为单位
    if (absBalance >= 10000) {
      final wan = absBalance / 10000;
      return '$sign${wan.toStringAsFixed(1)}万';
    } else if (absBalance >= 1000) {
      final qian = absBalance / 1000;
      return '$sign${qian.toStringAsFixed(1)}千';
    } else {
      return '$sign${absBalance.toStringAsFixed(2)}';
    }
  } else {
    // 其他语言环境：使用k、M作为单位
    if (absBalance >= 1000000) {
      final million = absBalance / 1000000;
      return '$sign${million.toStringAsFixed(1)}M';
    } else if (absBalance >= 1000) {
      final thousand = absBalance / 1000;
      return '$sign${thousand.toStringAsFixed(1)}k';
    } else {
      return '$sign${absBalance.toStringAsFixed(2)}';
    }
  }
}
