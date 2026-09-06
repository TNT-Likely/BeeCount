import '../../ai/core/bill_info.dart';

/// 将已落库交易的关联资料组装为 AI 账单卡片数据。
///
/// 账单卡片需要展示交易本身以外的关联资料（账户、标签、分类和币种）。
/// 集中在这里可让编辑回填和未来的卡片刷新保持同一套映射规则。
BillInfo buildBillCardInfoFromTransaction({
  required double amount,
  required DateTime time,
  required String transactionType,
  required int ledgerId,
  String? note,
  String? category,
  String? account,
  String? fromAccount,
  String? toAccount,
  List<String>? tags,
  String? currency,
}) {
  final isTransfer = transactionType == 'transfer';
  return BillInfo(
    amount: amount,
    time: time,
    note: note,
    category: category,
    type: switch (transactionType) {
      'expense' => BillType.expense,
      'transfer' => BillType.transfer,
      _ => BillType.income,
    },
    account: isTransfer ? null : account,
    fromAccount: isTransfer ? fromAccount : null,
    toAccount: isTransfer ? toAccount : null,
    tags: tags,
    currency: currency,
    ledgerId: ledgerId,
    confidence: 1.0,
  );
}
