import 'gallery_still_asset.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

class BudgetEditorSample extends StatefulWidget {
  const BudgetEditorSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<BudgetEditorSample> createState() => _BudgetEditorSampleState();
}

class _BudgetEditorSampleState extends State<BudgetEditorSample> {
  final amount = TextEditingController(text: '5000.00'),
      historical = TextEditingController(text: '2000.125'),
      invalid = TextEditingController(text: '0');
  String type = 'total';
  bool selected = false;
  @override
  void dispose() {
    amount.dispose();
    historical.dispose();
    invalid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BeeBudgetEditorForm(
            amountController: amount,
            type: type,
            totalLabel: '总预算',
            categoryTypeLabel: '分类预算',
            categoryLabel: '选择分类',
            categoryHint: '请选择预算分类',
            amountLabel: '预算金额',
            amountHint: '请输入预算金额',
            symbol: '¥',
            categoryName: selected ? '自定义咖啡' : null,
            categoryIcon: selected
                ? const GalleryStillAsset(
                    'assets/v4_gallery/category-coffee.png',
                    label: '自定义分类图片')
                : null,
            onType: (value) => setState(() => type = value),
            onCategory: () => setState(() => selected = true)),
        const SizedBox(height: 16),
        const Text('原身份编辑 · 共享只读 · 历史原始精度'),
        const SizedBox(height: 8),
        BeeBudgetEditorForm(
            amountController: historical,
            type: 'category',
            totalLabel: '总预算',
            categoryTypeLabel: '分类预算',
            categoryLabel: '选择分类',
            categoryHint: '请选择预算分类',
            amountLabel: '预算金额',
            amountHint: '请输入预算金额',
            symbol: '\$',
            categoryName: '自定义咖啡 · 长分类名称完整保留',
            categoryIcon: const BeeLineIcon('Coffee', size: 24),
            editing: true,
            enabled: false),
        const SizedBox(height: 16),
        const Text('已有总预算 · 校验错误'),
        const SizedBox(height: 8),
        BeeBudgetEditorForm(
            amountController: invalid,
            type: 'category',
            totalLabel: '总预算',
            categoryTypeLabel: '分类预算',
            categoryLabel: '选择分类',
            categoryHint: '请选择预算分类',
            amountLabel: '预算金额',
            amountHint: '请输入预算金额',
            symbol: '¥',
            totalUnavailable: true,
            amountError:
                (double.tryParse(invalid.text) ?? 0) <= 0 ? '请输入预算金额' : null,
            onType: (_) {},
            onCategory: () => setState(() => selected = true),
            categoryName: selected ? '自定义咖啡' : null,
            onAmountChanged: (_) => setState(() {})),
        const SizedBox(height: 16),
        widget.liveData ?? const Text('进入App内目录读取真实预算和分类，正式入口才执行写入。')
      ]);
}
