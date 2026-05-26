/// 账单类型
///
/// AI 多模态记账底座 · 数据模型。底座 (Layer 1) 把 text/image/audio 输入
/// 转换成 `List<BillInfo>` 后,应用层 (Layer 2 `AiBookkeeper`) 逐笔落库。
/// 字段全部可空,反映 AI 提取的实际不确定性;校验/兜底统一在
/// `JsonResponseParser._sanitize` 里完成。
enum BillType {
  /// 收入
  income,

  /// 支出
  expense,

  /// 转账
  transfer,
}

/// 账单信息
class BillInfo {
  /// 金额(支出为负、收入为正、转账为正)
  final double? amount;

  /// 发生时间
  final DateTime? time;

  /// 备注(注意 ≤15 字,prompt 已要求 AI 自行精简长标题)
  final String? note;

  /// 分类名称(从用户分类列表中匹配,或 AI 自行命名)
  final String? category;

  /// 收入/支出/转账
  final BillType? type;

  /// 支付账户(收入/支出场景)
  final String? account;

  /// 转出账户(转账场景)
  final String? fromAccount;

  /// 转入账户(转账场景)
  final String? toAccount;

  /// 标签列表
  final List<String>? tags;

  /// 账本 ID(由应用层注入,AI 不感知)
  final int? ledgerId;

  /// 置信度 0.0 - 1.0
  final double confidence;

  const BillInfo({
    this.amount,
    this.time,
    this.note,
    this.category,
    this.type,
    this.account,
    this.fromAccount,
    this.toAccount,
    this.tags,
    this.ledgerId,
    this.confidence = 0.0,
  });

  /// 信息完整度:amount + time 都有。
  ///
  /// 注意:经过 [JsonResponseParser._sanitize] 之后,time 字段一定非空
  /// (parser 内部已 fallback 到 `DateTime.now()`),所以此 getter 主要用于
  /// 测试或边界排查,业务代码不需要再判 `isComplete`。
  bool get isComplete => amount != null && time != null;

  /// 派生新实例,缺省沿用原值。
  BillInfo copyWith({
    double? amount,
    DateTime? time,
    String? note,
    String? category,
    BillType? type,
    String? account,
    String? fromAccount,
    String? toAccount,
    List<String>? tags,
    int? ledgerId,
    double? confidence,
  }) {
    return BillInfo(
      amount: amount ?? this.amount,
      time: time ?? this.time,
      note: note ?? this.note,
      category: category ?? this.category,
      type: type ?? this.type,
      account: account ?? this.account,
      fromAccount: fromAccount ?? this.fromAccount,
      toAccount: toAccount ?? this.toAccount,
      tags: tags ?? this.tags,
      ledgerId: ledgerId ?? this.ledgerId,
      confidence: confidence ?? this.confidence,
    );
  }

  /// 从 AI 返回的 JSON 对象构造。
  ///
  /// 容错:
  /// - `note` 兼容老字段名 `merchant`
  /// - `from_account` / `to_account` 兼容 camelCase
  /// - `tag` / `tags` 兼容单字符串和字符串数组
  /// - `time` 字符串内嵌空格会自动 strip 再 parse(应对 AI 偶发吐
  ///   `"2222 2-1-26T18:08:00"` 这类格式),仍不可解析时返回 null,
  ///   由 [JsonResponseParser._sanitize] 兜底成当前时间。
  factory BillInfo.fromJson(Map<String, dynamic> json) {
    return BillInfo(
      amount: (json['amount'] as num?)?.toDouble(),
      time: _parseTime(json['time']),
      note: json['note'] as String? ?? json['merchant'] as String?,
      category: json['category'] as String?,
      type: _parseBillType(json['type']),
      account: json['account'] as String?,
      fromAccount:
          json['from_account'] as String? ?? json['fromAccount'] as String?,
      toAccount: json['to_account'] as String? ?? json['toAccount'] as String?,
      tags: _parseTags(json['tags'] ?? json['tag']),
      ledgerId: json['ledgerId'] as int?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
    );
  }

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'time': time?.toIso8601String(),
        'note': note,
        'category': category,
        'type': type?.name,
        'account': account,
        'from_account': fromAccount,
        'to_account': toAccount,
        'tags': tags,
        'ledgerId': ledgerId,
        'confidence': confidence,
      };

  static DateTime? _parseTime(dynamic value) {
    if (value is! String) return null;
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct;
    // AI 偶发会在 ISO8601 里夹空格(如 `"2222 2-1-26T18:08:00"`),strip 重试
    return DateTime.tryParse(raw.replaceAll(RegExp(r'\s+'), ''));
  }

  static BillType? _parseBillType(dynamic value) {
    if (value == null) return null;
    final str = value.toString().toLowerCase();
    if (str.contains('income') || str == '收入') return BillType.income;
    if (str.contains('expense') || str == '支出') return BillType.expense;
    if (str.contains('transfer') || str == '转账' || str == '轉帳') {
      return BillType.transfer;
    }
    return null;
  }

  static List<String>? _parseTags(dynamic value) {
    if (value == null) return null;
    final tags = <String>[];
    if (value is String) {
      tags.addAll(value
          .split(RegExp(r'[,\n，、;；|]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty));
    } else if (value is List) {
      tags.addAll(value
          .map((item) => item.toString().trim())
          .where((s) => s.isNotEmpty));
    }
    return tags.isEmpty ? null : tags;
  }

  @override
  String toString() {
    return 'BillInfo(amount: $amount, time: $time, note: $note, category: $category, '
        'type: $type, account: $account, fromAccount: $fromAccount, '
        'toAccount: $toAccount, tags: $tags)';
  }
}
