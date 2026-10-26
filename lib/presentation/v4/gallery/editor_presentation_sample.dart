import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../utils/account_type_utils.dart';

/// Interactive presentation-only fixture. Production state stays in App bindings.
class EditorPresentationSample extends StatefulWidget {
  const EditorPresentationSample({super.key, required this.onEvent});
  final ValueChanged<String> onEvent;
  @override
  State<EditorPresentationSample> createState() =>
      _EditorPresentationSampleState();
}

class _EditorPresentationSampleState extends State<EditorPresentationSample> {
  final note = TextEditingController(text: '午餐');
  final focus = FocusNode();
  String amount = '32.00';
  String? selected = 'cash';
  bool expanded = true, excludeStats = false;
  @override
  void dispose() {
    note.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width <= 340;
    void digit(String v) =>
        setState(() => amount = amount == '0' ? v : amount + v);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RecordingHeader(
          labels: const ['支出', '收入', '转账'],
          selectedIndex: 0,
          onChanged: (value) => widget.onEvent('收支类型 $value'),
          backLabel: '返回',
          onBack: () => widget.onEvent('返回')),
      SizedBox(
          height: 600,
          child: RecordingFrame(
              compact: true,
              narrow: narrow,
              amount: RecordingAmountCard(
                  compact: true,
                  currency: RecordingCurrencyControl(
                      currency: 'CNY', onTap: () => widget.onEvent('选择币种')),
                  ledger: RecordingLedgerControl(
                      name: '日常生活', onTap: () => widget.onEvent('选择账本')),
                  amount: amount,
                  hint: '支持四则运算',
                  symbol: '¥'),
              category: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: List.generate(
                          14,
                          (i) => RecordingCategoryTile(
                              label: ['餐饮', '交通', '购物', '居家'][i % 4],
                              selected: i == 0,
                              icon: const BeeLineIcon('Utensils'),
                              onTap: () => widget.onEvent('分类 $i'))))),
              authors: const RecordingAuthors(authors: [
                RecordingAuthor(name: '林', tooltip: '林 创建'),
                RecordingAuthor(name: '小满', tooltip: '小满 最后编辑')
              ]),
              details: RecordingDetailsCard(
                  noteExpanded: expanded,
                  noteToggle: RecordingNoteToggle(
                      expanded: expanded,
                      label: '展开备注',
                      onTap: () => setState(() => expanded = !expanded)),
                  note: RecordingNoteField(
                      controller: note,
                      focusNode: focus,
                      hint: '备注',
                      historyLabel: '历史备注',
                      onHistory: () => widget.onEvent('历史备注')),
                  account: RecordingAccountControl(
                      label: '微信',
                      icon: const AccountTypeIcon(type: 'wechat', size: 18),
                      onTap: () => widget.onEvent('选择账户')),
                  date: RecordingMetaControl(
                      label: '10月20日', onTap: () => widget.onEvent('选择日期')),
                  tags: Align(
                      alignment: Alignment.centerRight,
                      child: RecordingTagSummary(
                          count: 2,
                          first: BeeTag(
                              tag: const BeeTagData(
                                  'work', '工作日', Color(0xffab8c24)),
                              compact: true))),
                  attachment: RecordingAttachmentControl(
                      label: '添加附件',
                      count: 1,
                      onTap: () => widget.onEvent('添加附件'))),
              keypad: RecordingKeypad(
                  onDigit: digit,
                  onOperator: widget.onEvent,
                  onBackspace: () =>
                      setState(() => amount = amount.length > 1 ? amount.substring(0, amount.length - 1) : '0'),
                  onClear: () => setState(() => amount = '0'),
                  deleteLabel: '退格，长按清空'),
              actions: RecordingActions(saveLabel: '保存', saveNextLabel: '再记一笔', showSaveNext: true, onEquals: () => widget.onEvent('等号计算由页面控制器负责'), onSave: () => widget.onEvent('保存 $amount · ${note.text}'), onSaveNext: () => widget.onEvent('再记一笔')))),
      const SizedBox(height: 18),
      const Text('横向账户 · 隐藏账户钉住与空态'),
      const SizedBox(height: 8),
      BeeAccountStrip(
          items: const [
            BeeAccountStripItem(
                id: 'cash',
                label: '现金',
                icon: AccountTypeIcon(type: 'cash', size: 18)),
            BeeAccountStripItem(
                id: 'old',
                label: '旧钱包',
                hidden: true,
                icon: AccountTypeIcon(type: 'wechat', size: 18))
          ],
          selected: selected,
          unsetLabel: '无账户',
          emptyLabel: '暂无账户',
          hiddenLabel: '已隐藏',
          onSelected: (v) => setState(() => selected = v)),
      const SizedBox(height: 8),
      BeeAccountStrip(
          items: const [],
          selected: null,
          allowUnset: false,
          unsetLabel: '无账户',
          emptyLabel: '暂无账户',
          hiddenLabel: '已隐藏',
          onSelected: (_) {}),
      const SizedBox(height: 18),
      const Text('原金额弹窗 · 同一受控键盘'),
      RecordingLegacyAmount(
          amount: amount,
          currency: RecordingCurrencyControl(
              currency: 'CNY',
              legacy: true,
              onTap: () => widget.onEvent('选择币种')),
          authors: const RecordingAuthors(
              authors: [RecordingAuthor(name: '访客', tooltip: '访客 创建并编辑')]),
          conversion: const RecordingConversionHint(text: '≈ 85.20 CNY')),
      RecordingLegacyKeypad(
          onDigit: digit,
          onBackspace: () => widget.onEvent('退格'),
          onOperator: widget.onEvent,
          onToggleFirst: () => widget.onEvent('切换乘法'),
          onToggleSecond: () => widget.onEvent('切换除法'),
          onDate: () => widget.onEvent('选择日期'),
          dateLabel: '2026/10/20',
          timeLabel: '12:30:00',
          onFinish: () => widget.onEvent('完成'),
          finishLabel: '完成',
          doubleTapLabel: '双击继续',
          continueAdding: true),
      RecordingTagAttachmentBar(
          tags: const [],
          emptyLabel: '选择标签',
          onTags: () => widget.onEvent('选择标签'),
          attachmentCount: 2,
          onAttachments: () => widget.onEvent('附件列表'),
          trailing: RecordingFlagControl(
              active: true,
              label: '账单标记',
              onTap: () => widget.onEvent('账单标记'))),
      RecordingFlagsForm(options: [
        RecordingFlagOption(
            title: '不计收支',
            hint: '保留账单，不计入收支统计',
            value: excludeStats,
            onChanged: (v) => setState(() => excludeStats = v))
      ])
    ]);
  }
}
