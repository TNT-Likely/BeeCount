import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../data/db.dart';
import 'package:drift/drift.dart' as drift;
// Compact top bar instead of PrimaryHeader to remove extra whitespace
import '../widgets/category_icon.dart';
import '../widgets/biz/amount_editor_sheet.dart';
import '../widgets/ui/ui.dart';
import '../styles/colors.dart';
import 'package:flutter/services.dart';
import '../utils/sync_helpers.dart';
import '../services/category_service.dart';


class CategoryPickerPage extends ConsumerStatefulWidget {
  final String initialKind; // 'expense' or 'income'
  // quickAdd: 点击分类后在当前弹窗上叠加金额输入，保存成功后依次关闭两个弹窗
  final bool quickAdd;
  final int? initialCategoryId;
  final String? initialNote; // 用于金额输入弹窗回填备注
  final double? initialAmount;
  final DateTime? initialDate;
  final int? editingTransactionId;
  const CategoryPickerPage(
      {super.key,
      required this.initialKind,
      this.quickAdd = false,
      this.initialCategoryId,
      this.initialNote,
      this.initialAmount,
      this.initialDate,
      this.editingTransactionId});

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
      body: Column(
        children: [
          // 紧凑顶部：去除多余留白 + 选中下划线
          PrimaryHeader(
            title: '',
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            bottom: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: TabBar(
                            controller: _tab,
                            isScrollable: false,
                            labelColor: Colors.black,
                            unselectedLabelColor: BeeColors.black54,
                            indicator: const UnderlineTabIndicator(
                              borderSide:
                                  BorderSide(width: 2, color: Colors.black),
                              insets: EdgeInsets.symmetric(horizontal: 24),
                            ),
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
                            style: TextStyle(color: Colors.black)),
                      )
                    ],
                  ),
                ),
              ],
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
          ),
        ],
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
        initialDate: widget.initialDate ?? DateTime.now(),
        initialAmount: widget.initialAmount,
        initialNote: widget.initialNote,
        onSubmit: (res) async {
          final repo = ref.read(repositoryProvider);
          final ledgerId = ref.read(currentLedgerIdProvider);
          if (widget.editingTransactionId != null) {
            await repo.updateTransaction(
              id: widget.editingTransactionId!,
              type: kind,
              amount: res.amount,
              categoryId: c.id,
              note: res.note,
              happenedAt: res.date,
            );
          } else {
            await repo.addTransaction(
              ledgerId: ledgerId,
              type: kind,
              amount: res.amount,
              categoryId: c.id,
              happenedAt: res.date,
              note: res.note,
            );
          }
          // 统一处理：自动/手动同步与状态刷新（后台静默）
          await handleLocalChange(ref, ledgerId: ledgerId, background: true);
          // 刷新：账本笔数与全局统计
          ref.invalidate(countsForLedgerProvider(ledgerId));
          ref.read(statsRefreshProvider.notifier).state++;
          if (!mounted) return;
          if (ctx.mounted && Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
          // 反馈：轻微触感 + 系统点击音
          HapticFeedback.lightImpact();
          SystemSound.play(SystemSoundType.click);
        },
      ),
    );
  }
}

class _CategoryGrid extends ConsumerStatefulWidget {
  final String kind;
  final ValueChanged<Category> onPick;
  final int? initialId;
  const _CategoryGrid(
      {required this.kind, required this.onPick, this.initialId});

  @override
  ConsumerState<_CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends ConsumerState<_CategoryGrid> {
  final Map<int, GlobalKey> _keys = {};
  bool _scrolled = false;
  int? _selectedId; // 记录当前点击的分类用于高亮

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final q = (db.select(db.categories)
          ..where((c) => c.kind.equals(widget.kind)))
        .watch();
    return StreamBuilder<List<Category>>(
      stream: q,
      builder: (context, snap) {
        final dbCategories = snap.data ?? [];

        // 合并默认分类与数据库分类
        final list = CategoryService.mergeDefaultAndDbCategories<Category>(
          dbCategories: dbCategories,
          kind: widget.kind,
          createCategory: ({required int id, required String name, required String kind, required String icon}) {
            return Category(id: id, name: name, kind: kind, icon: icon);
          },
          getNameFn: (category) => category.name,
          getKindFn: (category) => category.kind,
          getIdFn: (category) => category.id,
        );

        if (list.isEmpty) {
          return const Center(child: Text('暂无分类'));
        }

        // 初次渲染后滚动到初始分类顶部
        if (!_scrolled && widget.initialId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final key = _keys[widget.initialId!];
            final ctx = key?.currentContext;
            if (ctx != null) {
              Scrollable.ensureVisible(ctx,
                  alignment: 0.0, duration: const Duration(milliseconds: 250));
              _scrolled = true;
            }
          });
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
            final selected =
                widget.initialId != null && c.id == widget.initialId;
            final key = _keys.putIfAbsent(c.id, () => GlobalKey());
            return _CategoryItem(
              key: key,
              name: c.name,
              selected: selected || _selectedId == c.id,
              onTap: () async {
                setState(() => _selectedId = c.id);

                // 如果是虚拟分类（ID为-1），需要先创建到数据库
                if (c.id == -1) {
                  final db = ref.read(databaseProvider);
                  final newId = await db.into(db.categories).insert(CategoriesCompanion.insert(
                    name: c.name,
                    kind: c.kind,
                    icon: drift.Value(c.icon),
                  ));

                  // 创建一个新的Category对象，包含真实的数据库ID
                  final realCategory = Category(
                    id: newId,
                    name: c.name,
                    kind: c.kind,
                    icon: c.icon,
                  );
                  widget.onPick(realCategory);
                } else {
                  widget.onPick(c);
                }
              },
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
      {super.key,
      required this.name,
      required this.onTap,
      this.selected = false});

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
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.25)
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
