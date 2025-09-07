import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../data/db.dart';
import '../widgets/primary_header.dart';
import '../widgets/category_icon.dart';
import '../widgets/amount_editor_sheet.dart';

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
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.index = widget.initialKind == 'income' ? 1 : 0;
    // 若需要自动打开金额输入，则在首帧后查询分类并触发
    if (widget.quickAdd && widget.initialCategoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _autoOpened) return;
        final db = ref.read(databaseProvider);
        final c = await (db.select(db.categories)
              ..where((t) => t.id.equals(widget.initialCategoryId!)))
            .getSingleOrNull();
        if (c != null && mounted) {
          // 切换到对应的 tab
          final idx = c.kind == 'income' ? 1 : 0;
          if (_tab.index != idx) _tab.animateTo(idx);
          _autoOpened = true;
          // 直接调用 onPick 逻辑，打开金额输入
          // ignore: use_build_context_synchronously
          await _onPick(context, c, c.kind);
        }
      });
    }
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
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => AmountEditorSheet(
        categoryName: c.name,
        initialDate: DateTime.now(),
        onSubmit: (res) async {
          final repo = ref.read(repositoryProvider);
          final ledgerId = ref.read(currentLedgerIdProvider);
          await repo.addTransaction(
            ledgerId: ledgerId,
            type: kind,
            amount: res.amount,
            categoryId: c.id,
            happenedAt: res.date,
            note: res.note,
          );
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('已记账')));
        },
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

  IconData _iconFor(String n) => iconForCategory(n);

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
