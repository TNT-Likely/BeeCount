import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'transaction_fixture.dart';

final transactionStateFixtures = Future.wait([
  'assets/v4_gallery/transaction-states.json',
  'assets/v4_gallery/transaction-c3-cases.json',
].map((path) => rootBundle
        .loadString(path)
        .then((s) => (jsonDecode(s) as List).cast<Map<String, dynamic>>())))
    .then((groups) => groups.expand((g) => g).toList());

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
                      'C3：简单两行，复杂最多三行；账本保留标签，排除规则保留文字。原48状态＋4重点＋8交叉用例；时间偏好沿用原组件，更多项可只读查看完整字段。',
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
                              title: TransactionRowFixture(s).title,
                              labels: galleryTransactionLabels,
                              categoryLabel: TransactionRowFixture(s).category,
                              detailsNote: s['note'] as String?,
                              happenedAt: s['happenedAt'] == null
                                  ? null
                                  : DateTime.parse(s['happenedAt'] as String),
                              showTime: s['showTime'] == true,
                              showFullDate: s['showFullDate'] == true,
                              accountName: TransactionRowFixture(s).account,
                              ledgerName: s['ledgerName'] as String?,
                              note: TransactionRowFixture(s).note,
                              onTagTap: (t) => onEvent('样式样例：标签 ${t.label}'),
                              // No override: the component opens its complete read-only tag list.
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
                              tags: TransactionRowFixture(s).tags,
                              statusLabels:
                                  ((s['status'] as List?) ?? []).cast<String>(),
                              attachmentCount: (s['attachments'] as int?) ?? 0,
                              hidden: s['hidden'] == true,
                              readOnly: s['readOnly'] == true,
                              selected: s['selected'] as bool?,
                              onSelected: (v) => onEvent('样式样例勾选 $v'),
                              onCategoryTap: () => onEvent('样式样例：分类详情'),
                              onTap: () => onEvent(s['readOnly'] == true
                                  ? '样式样例：账单详情'
                                  : '样式样例：编辑账单'),
                              onMenu: () => showBeeSheet<void>(context,
                                  title: '交易行操作样例',
                                  child: BeeActionMenu(
                                      actions: const [
                                        BeeAction(
                                            id: 'detail',
                                            label: '查看详情',
                                            icon: BeeLineIcon('FileText')),
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
