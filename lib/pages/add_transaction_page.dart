import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../data/db.dart';
import '../widgets/ui/ui.dart';
import 'category_picker.dart';
import '../widgets/biz/amount_editor_sheet.dart';
import '../utils/sync_helpers.dart';
import 'package:flutter/services.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({super.key});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  String _type = 'expense';
  final DateTime _date = DateTime.now();
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

  // _save 已由 AmountEditorSheet 的 onSubmit 替代

  Future<void> _openAmountSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => AmountEditorSheet(
        categoryName: _categoryName ?? '记一笔',
        initialDate: _date,
        initialAmount: null,
        initialNote: null,
        onSubmit: (res) async {
          final repo = ref.read(repositoryProvider);
          final ledgerId = ref.read(currentLedgerIdProvider);
          await repo.addTransaction(
            ledgerId: ledgerId,
            type: _type,
            amount: res.amount,
            categoryId: _categoryId,
            happenedAt: res.date,
            note: res.note,
          );
          // 统一处理：自动/手动同步与状态刷新
          await handleLocalChange(ref, ledgerId: ledgerId, background: true);
          // 刷新：账本笔数与全局统计
          ref.invalidate(countsForLedgerProvider(ledgerId));
          ref.read(statsRefreshProvider.notifier).state++;
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          // 轻触反馈
          HapticFeedback.lightImpact();
          SystemSound.play(SystemSoundType.click);
        },
      ),
    );
  }
}
