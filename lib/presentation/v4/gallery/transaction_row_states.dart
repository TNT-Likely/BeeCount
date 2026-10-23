import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';

final transactionStateFixtures = rootBundle
    .loadString('assets/v4_gallery/transaction-states.json')
    .then((s) => (jsonDecode(s) as List).cast<Map<String, dynamic>>());

/// Shared visual fixtures with the HTML guide. Real ledger data has a separate binding.
class TransactionRowStates extends StatelessWidget {
  const TransactionRowStates({super.key, required this.onEvent});
  final ValueChanged<String> onEvent;
  @override
  Widget build(BuildContext context) => FutureBuilder<
          List<Map<String, dynamic>>>(
      future: transactionStateFixtures,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const BeeStatus(label: '样例加载失败', tone: BeeTone.error);
        }
        if (!snapshot.hasData) {
          return const BeeSkeleton(label: '加载交易行样例', rows: 2);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                      '时间规则与原组件一致：普通列表 HH:mm:ss；完整日期 yyyy-MM-dd HH:mm；普通零点隐藏，完整日期模式不受时间开关影响。',
                      style: TextStyle(fontSize: 12))),
              ...snapshot.data!.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(s['label'] as String,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).hintColor))),
                        BeeSurface(
                            padding: EdgeInsets.zero,
                            child: BeeTransactionRow(
                              key: ValueKey('state-${s['id']}'),
                              title: s['title'] as String,
                              happenedAt: s['happenedAt'] == null
                                  ? null
                                  : DateTime.parse(s['happenedAt'] as String),
                              showTime: s['showTime'] == true,
                              showFullDate: s['showFullDate'] == true,
                              accountName: s['accountName'] as String?,
                              ledgerName: s['ledgerName'] as String?,
                              note: s['note'] as String?,
                              onTagTap: (t) => onEvent('样式样例：标签 ${t.label}'),
                              onMoreTagsTap: () => onEvent('样式样例：查看全部标签'),
                              onAttachmentTap: () => onEvent('样式样例：查看附件'),
                              amount: s['amount'] as String,
                              subtitle: s['subtitle'] as String?,
                              converted: s['converted'] as String?,
                              kind: BeeTransactionKind.values
                                  .byName(s['kind'] as String),
                              icon: BeeCategoryIcon(
                                  name: s['icon'] as String,
                                  image: s['image'] == null
                                      ? null
                                      : AssetImage(s['image'] as String)),
                              tags: ((s['tags'] as List?) ?? [])
                                  .map((t) => BeeTagData(
                                      t as String,
                                      t,
                                      t == '工作日'
                                          ? const Color(0xffaa8b29)
                                          : const Color(0xff219c9c)))
                                  .toList(),
                              statusLabels:
                                  ((s['status'] as List?) ?? []).cast<String>(),
                              attachmentCount: (s['attachments'] as int?) ?? 0,
                              hidden: s['hidden'] == true,
                              readOnly: s['readOnly'] == true,
                              selected: s['selected'] as bool?,
                              onSelected: (v) => onEvent('样式样例勾选 $v'),
                              onCategoryTap: () => onEvent('样式样例：分类详情'),
                              onTap: () => onEvent('样式样例：账单详情'),
                              onMenu: () => showBeeSheet<void>(context,
                                  title: '交易行操作样例',
                                  child: BeeActionMenu(
                                      actions: const [
                                        BeeAction(
                                            id: 'edit',
                                            label: '编辑账单',
                                            icon: BeeLineIcon('PencilLine')),
                                        BeeAction(
                                            id: 'copy',
                                            label: '复制账单',
                                            icon: BeeLineIcon('BookOpen')),
                                        BeeAction(
                                            id: 'receipt',
                                            label: '生成小票',
                                            icon: BeeLineIcon('ReceiptText'))
                                      ],
                                      onSelected: (v) {
                                        Navigator.pop(context);
                                        onEvent('样式样例 $v');
                                      })),
                              deleteLabel: '删除',
                              onDeleteRequested: () async {
                                await showBeeConfirm(context,
                                    title: '删除这笔账单？',
                                    message: '这里是样式样例，不修改真实账单。',
                                    confirmLabel: '确认',
                                    cancelLabel: '取消',
                                    danger: true);
                              },
                            ))
                      ])))
            ]);
      });
}
