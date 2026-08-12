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

  /// 本次入库里「拿不到汇率、按 1:1 暂记」的外币币种(去重、已排序)。
  ///
  /// 多币种降级路径(.docs/multi-currency-ai A5):自动通道无人值守,缺汇率
  /// 不能阻断,只能先落 `nativeAmount = amount` 再靠统计页 L11 横幅补折算。
  /// 有 UI 的渠道(对话/语音/选图)据此在结果上补一行提示;自动截图/通知
  /// 渠道忽略它,只打日志。
  final List<String> unconvertedCurrencies;

  const BookkeepingResult({
    this.savedBills = const [],
    this.transactionIds = const [],
    this.failedCount = 0,
    this.unconvertedCurrencies = const [],
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
