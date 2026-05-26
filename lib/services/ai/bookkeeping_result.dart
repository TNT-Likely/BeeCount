import '../../ai/core/bill_info.dart';

/// AI 记账应用层 · 统一结果。
///
/// 不论单笔还是多笔,5 个调用渠道(chat / image / voice / auto-screenshot /
/// auto-text)的 [AiBookkeeper] 出口都返回这个结构。渠道层只需检查
/// [success] / [isMulti] 然后展示对应 UI(toast / 通知 / 卡片)。
class BookkeepingResult {
  /// 实际保存成功的账单(已附上正确的 ledgerId / 校正后的 category / account)
  final List<BillInfo> savedBills;

  /// 与 [savedBills] 一一对应的交易 ID
  final List<int> transactionIds;

  /// 因创建失败被跳过的笔数(amount 已校验,失败原因通常是 DB 异常)
  final int failedCount;

  const BookkeepingResult({
    this.savedBills = const [],
    this.transactionIds = const [],
    this.failedCount = 0,
  });

  /// 至少有一笔成功入库
  bool get success => transactionIds.isNotEmpty;

  /// 多笔
  bool get isMulti => transactionIds.length > 1;

  /// 入库总笔数
  int get savedCount => transactionIds.length;

  /// 全部账单的金额绝对值之和(用于通知/toast 汇总)
  double get totalAbsAmount =>
      savedBills.fold(0.0, (s, b) => s + (b.amount?.abs() ?? 0));

  /// 首笔账单(用于单笔场景展示)
  BillInfo? get firstBill => savedBills.isEmpty ? null : savedBills.first;

  /// 首笔交易 ID
  int? get firstTransactionId =>
      transactionIds.isEmpty ? null : transactionIds.first;

  /// 失败结果工厂
  static const BookkeepingResult empty = BookkeepingResult();
}
