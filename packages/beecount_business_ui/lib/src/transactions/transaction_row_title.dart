/// 明细行第一行的组装结果。
/// [primary] 常驻主文本;[parenNote] 非空时在主文本后追加「  (备注)」小灰字。
class TransactionRowTitle {
  final String primary;
  final String? parenNote;
  const TransactionRowTitle(this.primary, this.parenNote);
}

/// 按备注显示方式组装明细行第一行。
///
/// - [mode]: 'note' = 备注优先(有备注显示备注、纯替换);其它值(含默认 'category')
///   = 分类优先(分类为主,备注挂括号)。
/// - [categoryName]: 分类显示名;转账/调整等无分类的行传 null —— 不受 mode 影响。
/// - [title]: 普通行里即备注;转账/调整里是其标题文案(可能为空串)。
TransactionRowTitle composeTransactionRowTitle({
  required String mode,
  required String? categoryName,
  required String title,
}) {
  // 备注优先:仅普通行(有分类)且确有备注时,备注取代分类作主文本。
  if (mode == 'note' && categoryName != null && title.isNotEmpty) {
    return TransactionRowTitle(title, null);
  }
  // 分类优先(默认),以及转账/调整(categoryName == null)—— 保持原有行为。
  final primary = categoryName ?? title;
  final paren = (categoryName != null && title.isNotEmpty && title != categoryName)
      ? title
      : null;
  return TransactionRowTitle(primary, paren);
}
