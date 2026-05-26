import 'ai_extraction_context.dart';

/// Prompt 模板拼装。纯函数,无副作用,易于单测。
///
/// 默认模板要求 AI 返回 JSON 数组(单笔也包成 `[{...}]`),通过占位符
/// `{{INPUT_SOURCE}}` / `{{CURRENT_TIME}}` / `{{OCR_TEXT}}` /
/// `{{CATEGORIES}}` / `{{ACCOUNTS}}` 注入运行时变量。
class PromptBuilder {
  const PromptBuilder();

  /// 默认模板。强制 JSON 数组 + 完整字段说明 + 多笔示例。
  static const String defaultTemplate =
      '''{{INPUT_SOURCE}}提取记账信息，返回JSON数组。

当前时间：{{CURRENT_TIME}}

{{OCR_TEXT}}

{{CATEGORIES}}{{ACCOUNTS}}

输出格式：
- 始终返回 JSON 数组，即使只有一笔，也包成 [{...}]
- 识别到多笔独立消费/收入/转账时，数组中每笔一个对象，按时间先后顺序排列
- 「拆开 AA」「拆开报销」「拼单」等场景，每个独立支付/收款都算一笔
- 同一商家的多件商品如果是一次性支付，合并为一笔

字段说明：
1. amount: 金额（支出负数，收入正数）
2. time: ISO8601格式，尽量推断时间：
   - 明确时间（如"14:30"、"2025-11-25"）→直接使用
   - 相对日期（昨天、前天、上周）→推算具体日期
   - 时间段（早上、中午、晚上）→使用合理时刻（早上09:00、中午12:00、晚上19:00）
   - 完全没提时间→使用当前时间
3. note: 备注（必须≤15字，超过则精简），提取优先级：
   - 商家/店铺名（如"星巴克"、"肯德基"）
   - 商品名称（长标题需简化，如"2025春季新款黑色斜纹格纹半身裙"→"黑色半身裙"）
   - 用户描述（如"给女儿买"）
   - 没有则留空
4. category: 从分类列表选择（转账可填"转账"）
5. type: income、expense 或 transfer
6. account: 支付账户（收入/支出可用）
7. from_account: 转出账户（仅转账可用）
8. to_account: 转入账户（仅转账可用）
9. tag/tags: 标签（可选，单个字符串或字符串数组）

示例：
单笔"昨天中午吃饭50" → [{"amount":-50,"time":"2025-11-24T12:00:00","category":"餐饮","type":"expense"}]
单笔"早上在星巴克买咖啡30" → [{"amount":-30,"time":"{{CURRENT_DATE}}T09:00:00","note":"星巴克","category":"咖啡","type":"expense"}]
单笔"商品:2025春季新款黑色半身裙 金额:￥299" → [{"amount":-299,"note":"黑色半身裙","category":"服装","type":"expense"}]
转账"从建行转800到零钱包" → [{"amount":800,"category":"转账","type":"transfer","from_account":"建行","to_account":"零钱包","tag":"自己"}]
多笔"早上地铁5元，中午吃饭40元，晚上买水果35元" → [{"amount":-5,"time":"{{CURRENT_DATE}}T09:00:00","note":"地铁","category":"交通","type":"expense"},{"amount":-40,"time":"{{CURRENT_DATE}}T12:00:00","category":"餐饮","type":"expense"},{"amount":-35,"time":"{{CURRENT_DATE}}T19:00:00","note":"水果","category":"购物","type":"expense"}]

注意：只返回 JSON 数组（即使只有一笔也用数组包裹），尽量推断时间不要返回 null，note 必须 ≤15 字（长标题要精简）''';

  /// Hardcoded fallback 分类(context 不提供时使用)
  static const String _hardcodedCategoryHint = '分类列表：\n'
      '支出：餐饮、交通、购物、娱乐、居家、通讯、水电、医疗、教育\n'
      '收入：工资、理财、红包、奖金、报销、兼职';

  /// 拼装最终 prompt。
  ///
  /// [inputSource] 输入源描述(如 "从以下支付账单文本中" / "分析支付账单截图，从中")
  /// [ocrText] 文本输入(图片场景留空)
  /// [now] 时间锚点,默认 `DateTime.now()` (测试可注入固定时间)
  String build({
    required AiExtractionContext context,
    required String inputSource,
    String ocrText = '',
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    final currentDate = '${ts.year}-${_pad(ts.month)}-${_pad(ts.day)}';
    final currentTime = '$currentDate ${_pad(ts.hour)}:${_pad(ts.minute)}';

    final template = (context.customPromptTemplate != null &&
            context.customPromptTemplate!.trim().isNotEmpty)
        ? context.customPromptTemplate!
        : defaultTemplate;

    return template
        .replaceAll('{{INPUT_SOURCE}}', inputSource)
        .replaceAll('{{CURRENT_TIME}}', currentTime)
        .replaceAll('{{CURRENT_DATE}}', currentDate)
        .replaceAll('{{OCR_TEXT}}', ocrText)
        .replaceAll('{{CATEGORIES}}', _buildCategoryHint(context))
        .replaceAll('{{ACCOUNTS}}', _buildAccountHint(context));
  }

  String _buildCategoryHint(AiExtractionContext ctx) {
    if (ctx.expenseCategories.isEmpty && ctx.incomeCategories.isEmpty) {
      return _hardcodedCategoryHint;
    }
    final parts = <String>[];
    if (ctx.expenseCategories.isNotEmpty) {
      parts.add('支出：${ctx.expenseCategories.join('、')}');
    }
    if (ctx.incomeCategories.isNotEmpty) {
      parts.add('收入：${ctx.incomeCategories.join('、')}');
    }
    return '分类列表：\n${parts.join('\n')}';
  }

  String _buildAccountHint(AiExtractionContext ctx) {
    if (ctx.accounts.isEmpty) return '';
    return '\n账户列表：${ctx.accounts.join('、')}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
