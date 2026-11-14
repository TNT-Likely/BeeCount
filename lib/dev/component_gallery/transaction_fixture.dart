import 'package:flutter/material.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';

/// Presentation-only fixtures shared with HTML. No repository or user data.
class TransactionRowFixture {
  TransactionRowFixture(this.source);
  final Map<String, dynamic> source;
  String get id => source['id'] as String;
  String get category {
    if (source['categoryLabel'] != null) {
      return source['categoryLabel'] as String;
    }
    final subtitle = source['subtitle'] as String?;
    if (subtitle?.contains(' · ') == true) return subtitle!.split(' · ').first;
    if (subtitle?.contains(' / ') == true) return subtitle!.split(' / ').first;
    return source['title'] as String;
  }

  String get title => source['noteFirst'] == true && source['note'] != null
      ? source['note'] as String
      : source['title'] as String;
  String? get note =>
      source['noteFirst'] == true ? null : source['note'] as String?;
  String? get account {
    if (source['accountName'] != null) return source['accountName'] as String;
    final subtitle = source['subtitle'] as String?;
    if (subtitle == null) return null;
    return subtitle.contains(' · ')
        ? subtitle.split(' · ').last
        : subtitle.contains(' / ')
            ? subtitle.split(' / ').last
            : subtitle;
  }

  List<BeeTagData> get tags =>
      ((source['tags'] as List?) ?? []).asMap().entries.map((entry) {
        const colors = [
          Color(0xff977d26),
          Color(0xff477f6c),
          Color(0xff7265a8),
          Color(0xffa8637d),
          Color(0xff3d7f91),
          Color(0xff866e45)
        ];
        final tag = entry.value;
        final label = tag is String ? tag : tag['label'] as String;
        return BeeTagData(
            '$id-tag-${entry.key}', label, colors[entry.key % colors.length]);
      }).toList();
}

final galleryTransactionLabels = BeeTransactionRowLabels(
    fieldsTitle: '完整账单字段',
    moreFields: (count) => '更多$count项',
    category: '分类',
    account: '账户',
    ledger: '账本',
    note: '备注',
    amount: '原币金额',
    converted: '历史折算',
    time: '时间',
    tags: '标签',
    attachments: '附件',
    rules: '统计规则',
    readOnly: '只读',
    access: '访问状态');
