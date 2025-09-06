import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../data/db.dart';
import '../widgets/primary_header.dart';
import 'category_picker.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({super.key});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  String _type = 'expense';
  final _amountCtrl = TextEditingController();
  final DateTime _date = DateTime.now();
  final _noteCtrl = TextEditingController();
  int? _categoryId;
  String? _categoryName;

  @override
  void initState() {
    super.initState();
    // 页面进入即引导选择分类
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPickCategory();
    });
  }

  Future<void> _startPickCategory() async {
    final picked = await Navigator.of(context).push<Category>(
      MaterialPageRoute(
        builder: (_) => CategoryPickerPage(
          initialKind: _type == 'income' ? 'income' : 'expense',
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _categoryId = picked.id;
        _categoryName = picked.name;
      });
      await _openAmountSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const PrimaryHeader(title: '记一笔'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'expense',
                    label: Text('支出'),
                    icon: Icon(Icons.remove_circle_outline)),
                ButtonSegment(
                    value: 'income',
                    label: Text('收入'),
                    icon: Icon(Icons.add_circle_outline)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final repo = ref.read(repositoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }
    await repo.addTransaction(
      ledgerId: ledgerId,
      type: _type,
      amount: amount,
      happenedAt: _date,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
      categoryId: _categoryId,
    );
    if (!mounted) return;
    Navigator.of(context).pop(); // 关 bottom sheet
    // 不再返回中间页面，保持当前导航栈简单
    Navigator.of(context).maybePop();
  }

  Future<void> _openAmountSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_categoryName ?? '记一笔',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _amountCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '金额',
                  prefixIcon: Icon(Icons.currency_yuan),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: '备注（可选）'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('保存'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
