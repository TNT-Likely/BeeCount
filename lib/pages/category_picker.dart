import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../data/db.dart';
import '../widgets/primary_header.dart';

class CategoryPickerPage extends ConsumerStatefulWidget {
  final String initialKind; // 'expense' or 'income'
  // quickAdd: 点击分类后在当前弹窗上叠加金额输入，保存成功后依次关闭两个弹窗
  final bool quickAdd;
  final int? initialCategoryId;
  const CategoryPickerPage(
      {super.key,
      required this.initialKind,
      this.quickAdd = false,
      this.initialCategoryId});

  @override
  ConsumerState<CategoryPickerPage> createState() => _CategoryPickerPageState();
}

class _CategoryPickerPageState extends ConsumerState<CategoryPickerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.index = widget.initialKind == 'income' ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PrimaryHeader(
              title: '',
              bottom: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: TabBar(
                          controller: _tab,
                          indicatorColor: Colors.white,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          tabs: const [
                            Tab(text: '支出'),
                            Tab(text: '收入'),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _CategoryGrid(
                      kind: 'expense',
                      onPick: (c) => _onPick(context, c, 'expense'),
                      initialId: widget.initialCategoryId),
                  _CategoryGrid(
                      kind: 'income',
                      onPick: (c) => _onPick(context, c, 'income'),
                      initialId: widget.initialCategoryId),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _onPick(BuildContext context, Category c, String kind) async {
    if (!widget.quickAdd) {
      Navigator.pop(context, c);
      return;
    }
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 12,
          right: 12,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.name,
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额',
                prefixIcon: Icon(Icons.currency_yuan),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: '备注（可选）'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  final repo = ref.read(repositoryProvider);
                  final ledgerId = ref.read(currentLedgerIdProvider);
                  final amount = double.tryParse(amountCtrl.text);
                  if (amount == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('请输入有效金额')),
                    );
                    return;
                  }
                  await repo.addTransaction(
                    ledgerId: ledgerId,
                    type: kind,
                    amount: amount,
                    categoryId: c.id,
                    happenedAt: DateTime.now(),
                    note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                  );
                  if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                  if (Navigator.of(context).canPop())
                    Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已记账')),
                  );
                },
                child: const Text('保存'),
              ),
            ]),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends ConsumerWidget {
  final String kind;
  final ValueChanged<Category> onPick;
  final int? initialId;
  const _CategoryGrid(
      {required this.kind, required this.onPick, this.initialId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final q =
        (db.select(db.categories)..where((c) => c.kind.equals(kind))).watch();
    return StreamBuilder<List<Category>>(
      stream: q,
      builder: (context, snap) {
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('暂无分类'));
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.9,
          ),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final c = list[i];
            final selected = initialId != null && c.id == initialId;
            if (selected &&
                WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
              // 自动触发一次选中，打开金额输入
              Future.microtask(() => onPick(c));
            }
            return _CategoryItem(
              name: c.name,
              selected: selected,
              onTap: () => onPick(c),
            );
          },
        );
      },
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  final bool selected;
  const _CategoryItem(
      {required this.name, required this.onTap, this.selected = false});

  IconData _iconFor(String n) {
    if (n.contains('餐') ||
        n.contains('饭') ||
        n.contains('吃') ||
        n.contains('外卖')) return Icons.restaurant_outlined;
    if (n.contains('交通') ||
        n.contains('出行') ||
        n.contains('打车') ||
        n.contains('地铁') ||
        n.contains('公交') ||
        n.contains('高铁') ||
        n.contains('火车') ||
        n.contains('飞机')) return Icons.directions_transit_outlined;
    if (n.contains('购物') || n.contains('百货'))
      return Icons.shopping_bag_outlined;
    if (n.contains('娱乐') || n.contains('游戏'))
      return Icons.sports_esports_outlined;
    if (n.contains('居家') ||
        n.contains('家') ||
        n.contains('家居') ||
        n.contains('物业') ||
        n.contains('维修')) return Icons.chair_outlined;
    if (n.contains('美妆') ||
        n.contains('化妆') ||
        n.contains('护肤') ||
        n.contains('美容')) return Icons.brush_outlined;
    if (n.contains('通讯') || n.contains('话费') || n.contains('宽带'))
      return Icons.phone_iphone_outlined;
    if (n.contains('礼物') || n.contains('红包') || n.contains('礼金'))
      return Icons.card_giftcard_outlined;
    if (n.contains('水') ||
        n.contains('电') ||
        n.contains('煤') ||
        n.contains('燃气')) return Icons.water_drop_outlined;
    if (n.contains('房') || n.contains('租')) return Icons.home_outlined;
    if (n.contains('工资') ||
        n.contains('收入') ||
        n.contains('奖金') ||
        n.contains('报销') ||
        n.contains('兼职')) return Icons.attach_money_outlined;
    if (n.contains('理财') ||
        n.contains('利息') ||
        n.contains('基金') ||
        n.contains('股票') ||
        n.contains('退款')) return Icons.savings_outlined;
    if (n.contains('教育') || n.contains('学习') || n.contains('培训'))
      return Icons.menu_book_outlined;
    if (n.contains('医疗') || n.contains('医院') || n.contains('药'))
      return Icons.medical_services_outlined;
    if (n.contains('宠物') || n.contains('猫') || n.contains('狗'))
      return Icons.pets_outlined;
    if (n.contains('运动') || n.contains('健身') || n.contains('球'))
      return Icons.fitness_center_outlined;
    if (n.contains('数码') || n.contains('电子') || n.contains('手机'))
      return Icons.devices_other_outlined;
    if (n.contains('旅行') || n.contains('旅游') || n.contains('出差'))
      return Icons.card_travel_outlined;
    if (n.contains('烟') || n.contains('酒') || n.contains('茶'))
      return Icons.local_bar_outlined;
    if (n.contains('母婴') || n.contains('孩子') || n.contains('奶粉'))
      return Icons.child_friendly_outlined;
    if (n.contains('停车') ||
        n.contains('加油') ||
        n.contains('汽车') ||
        n.contains('保养')) return Icons.local_gas_station_outlined;
    return Icons.circle_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.25)
                  : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(name),
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          )
        ],
      ),
    );
  }
}
