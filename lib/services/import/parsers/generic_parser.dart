import '../bill_parser.dart';

/// 通用 CSV 账单解析器
class GenericBillParser implements BillParser {
  @override
  String get name => 'Generic';

  @override
  int findHeaderRow(List<List<String>> rows) {
    if (rows.isEmpty) return -1;

    // 使用列数一致性规则查找表头：
    // 表头行的特征是后续数据行的列数都和表头行一致
    // 如果前面有描述文案，列数通常不一致
    final headerIndex = _findHeaderByColumnConsistency(rows);
    if (headerIndex >= 0) return headerIndex;

    // 兜底：使用第一行
    return 0;
  }

  /// 通过列数一致性查找表头行
  /// 策略：在前30行中，找到第一个列数>=3且后续至少有5行数据列数相同的行
  int _findHeaderByColumnConsistency(List<List<String>> rows) {
    final maxRows = rows.length < 30 ? rows.length : 30;

    for (int i = 0; i < maxRows; i++) {
      final headerCandidateColCount = rows[i].length;

      // 表头至少要有3列才有意义
      if (headerCandidateColCount < 3) continue;

      // 检查后续至少5行的列数是否一致
      int consistentCount = 0;
      final checkRange = rows.length < i + 10 ? rows.length : i + 10;

      for (int j = i + 1; j < checkRange; j++) {
        if (rows[j].length == headerCandidateColCount) {
          consistentCount++;
        }
      }

      // 如果至少有5行数据列数一致，认为找到了表头
      if (consistentCount >= 5) {
        return i;
      }
    }

    return -1; // 未找到
  }

  @override
  Map<String, int> mapColumns(List<String> headerRow) {
    final mapping = <String, int>{};

    for (int i = 0; i < headerRow.length; i++) {
      final key = _normalizeToKey(headerRow[i]);
      if (key != null && !mapping.containsKey(key)) {
        mapping[key] = i;
      }
    }

    return mapping;
  }

  @override
  Map<String, dynamic>? parseRow(
    List<String> row,
    Map<String, int> columnMapping,
  ) {
    // 通用解析器直接使用列映射提取数据
    final result = <String, dynamic>{};

    columnMapping.forEach((field, columnIndex) {
      if (columnIndex < row.length) {
        result[field] = row[columnIndex];
      }
    });

    return result.isEmpty ? null : result;
  }

  @override
  bool validateBillType(List<List<String>> rows) {
    // 通用解析器接受所有格式
    return true;
  }

  /// 将表头文本规范化为字段key
  String? _normalizeToKey(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    final lower = s.toLowerCase();
    final noSpace = lower.replaceAll(RegExp(r'\s+'), '');

    // 英文匹配
    if (noSpace == 'date' || noSpace == 'time' || noSpace == 'datetime') {
      return 'date';
    }
    if (noSpace == 'type' || noSpace == 'inout' || noSpace == 'direction') {
      return 'type';
    }
    if (noSpace == 'amount' ||
        noSpace == 'money' ||
        noSpace == 'price' ||
        noSpace == 'value') {
      return 'amount';
    }
    if (noSpace == 'currency' || noSpace == 'currencycode') {
      return 'currency';
    }
    if (noSpace == 'category' ||
        noSpace == 'cate' ||
        noSpace == 'subject' ||
        noSpace == 'tag') {
      return 'category';
    }
    if (noSpace == 'note' ||
        noSpace == 'memo' ||
        noSpace == 'desc' ||
        noSpace == 'description' ||
        noSpace == 'remark' ||
        noSpace == 'title') {
      return 'note';
    }

    // 中文匹配
    if (_containsAny(s, ['日期', '时间', '交易时间', '账单时间', '创建时间'])) {
      return 'date';
    }
    if (_containsAny(s, ['金额', '金额(元)', '交易金额', '变动金额', '收支金额'])) {
      return 'amount';
    }
    // v30 多币种:币种列(反馈10)。注意在「分类/类型」等之前匹配,
    // 「币种」不含歧义字,顺序无冲突。
    if (_containsAny(s, ['币种', '幣種', '货币', '貨幣'])) {
      return 'currency';
    }
    // 先匹配"交易类型"等更具体的分类字段（避免被"类型"匹配为type）
    // 优先匹配二级分类相关字段（注意：必须先匹配更长的字符串，避免被短字符串提前匹配）
    if (_containsAny(s, ['二级分类', '子分类', '次分类', 'Subcategory', 'Sub Category'])) {
      return 'sub_category';
    }
    if (_containsAny(s, ['分类', '类别', '账目名称', '科目', '交易分类', '交易类型'])) {
      return 'category';
    }
    // 标签匹配（注意：不要和分类混淆，"标签"单独作为tags字段）
    if (noSpace == 'tags' || _containsAny(s, ['标签', 'Tags'])) {
      return 'tags';
    }
    // 附件匹配
    if (noSpace == 'attachments' || _containsAny(s, ['附件', 'Attachments'])) {
      return 'attachments';
    }
    // 再匹配收支类型字段
    if (_containsAny(s, ['类型', '收支', '收/支', '方向'])) {
      return 'type';
    }
    if (_containsAny(
        s, ['备注', '说明', '标题', '摘要', '附言', '商品名称', '商品说明', '交易对方', '商家'])) {
      return 'note';
    }
    // 账户匹配：需要区分普通账户、转出账户、转入账户
    // 注意：必须先匹配具体的转出/转入账户，再匹配通用的"账户"
    if (_containsAny(s, ['转出账户', 'From Account', 'FromAccount'])) {
      return 'from_account';
    }
    if (_containsAny(s, ['转入账户', 'To Account', 'ToAccount'])) {
      return 'to_account';
    }
    if (_containsAny(s, ['账户', 'Account'])) {
      return 'account';
    }

    // 明确忽略的字段
    if (_containsAny(s, [
      '账目编号',
      '编号',
      '单号',
      '流水号',
      '交易号',
      '相关图片',
      '图片',
      '交易单号',
      '订单号'
    ])) {
      return null;
    }

    return null;
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
}
