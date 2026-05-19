import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/shared_ledger_providers.dart';
import '../../utils/category_utils.dart';
import '../../utils/shared_ledger_picker_filter.dart';
import '../category_icon.dart';

/// 分类过滤器回调类型
/// 返回 true 表示该分类可选，返回 false 表示不可选（置灰）
typedef CategoryFilterCallback = Future<bool> Function(Category category);

/// 显示分类选择器
///
/// [type] 分类类型：'income' 或 'expense'
/// [currentCategoryId] 当前选中的分类ID（用于高亮显示）
/// [includeParentCategories] 是否包含有子分类的一级分类
/// [excludeNames] 排除的分类名称列表
/// [excludeIds] 排除的分类ID列表
/// [showTransactionCount] 是否显示交易笔数
/// [ledgerId] 如果要显示笔数，需要账本ID
/// [expandChildrenByDefault] 是否默认展开二级分类
/// [onlyTopLevel] 是否只显示一级分类（不显示二级分类）
/// [categoryFilter] 自定义过滤器，决定分类是否可选
/// [title] 自定义标题
Future<Category?> showCategorySelector(
  BuildContext context, {
  required String type,
  int? currentCategoryId,
  bool includeParentCategories = false,
  List<String>? excludeNames,
  List<int>? excludeIds,
  bool showTransactionCount = false,
  int? ledgerId,
  bool expandChildrenByDefault = false,
  bool onlyTopLevel = false,
  CategoryFilterCallback? categoryFilter,
  String? title,
}) {
  return showDialog<Category>(
    context: context,
    builder: (context) => CategorySelectorDialog(
      type: type,
      currentCategoryId: currentCategoryId,
      includeParentCategories: includeParentCategories,
      excludeNames: excludeNames,
      excludeIds: excludeIds,
      showTransactionCount: showTransactionCount,
      ledgerId: ledgerId,
      expandChildrenByDefault: expandChildrenByDefault,
      onlyTopLevel: onlyTopLevel,
      categoryFilter: categoryFilter,
      title: title,
    ),
  );
}

class CategorySelectorDialog extends ConsumerStatefulWidget {
  final String type;
  final int? currentCategoryId;
  final bool includeParentCategories;
  final List<String>? excludeNames;
  final List<int>? excludeIds;
  final bool showTransactionCount;
  final int? ledgerId;
  final bool expandChildrenByDefault;
  final bool onlyTopLevel;
  final CategoryFilterCallback? categoryFilter;
  final String? title;

  const CategorySelectorDialog({
    super.key,
    required this.type,
    this.currentCategoryId,
    this.includeParentCategories = false,
    this.excludeNames,
    this.excludeIds,
    this.showTransactionCount = false,
    this.ledgerId,
    this.expandChildrenByDefault = false,
    this.onlyTopLevel = false,
    this.categoryFilter,
    this.title,
  });

  @override
  ConsumerState<CategorySelectorDialog> createState() => _CategorySelectorDialogState();
}

class _CategorySelectorDialogState extends ConsumerState<CategorySelectorDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  Map<int, int> _transactionCounts = {};
  Map<int, bool> _categoryFilterResults = {}; // 存储过滤器结果

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });
    if (widget.showTransactionCount) {
      _loadTransactionCounts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 加载所有分类
  Future<List<Category>> _loadAllCategories() async {
    final repo = ref.read(repositoryProvider);

    // 获取收入和支出分类
    final incomeCategories = await repo.getTopLevelCategories('income');
    final expenseCategories = await repo.getTopLevelCategories('expense');

    // 获取所有二级分类
    var allCategories = <Category>[];
    allCategories.addAll(incomeCategories);
    allCategories.addAll(expenseCategories);

    // 如果只显示一级分类，不加载子分类
    if (!widget.onlyTopLevel) {
      // 为每个一级分类获取子分类(主表路径,共享账本场景下面 filter 会替换)
      for (final category in [...incomeCategories, ...expenseCategories]) {
        final subs = await repo.getSubCategories(category.id);
        allCategories.addAll(subs);
      }
    }

    // §7 共享账本 picker 过滤:Editor + 共享账本 → 走 SharedLedger* 表(下游
    // _buildCategoryGroups 仍按 widget.type 二次过滤,所以这里 topLevelOnly=
    // false 返完整集合,父子关系靠 parent_sync_id 派生 synthetic parent_id)。
    if (repo is LocalRepository) {
      final ctx = await repo.db.loadLedgerPickerContext(widget.ledgerId);
      allCategories = await repo.db
          .filterCategoriesForLedger(allCategories, ctx, topLevelOnly: false);
    }

    // 如果有过滤器，计算每个分类的可选状态
    if (widget.categoryFilter != null) {
      final filterResults = <int, bool>{};
      for (final category in allCategories) {
        filterResults[category.id] = await widget.categoryFilter!(category);
      }
      if (mounted) {
        setState(() {
          _categoryFilterResults = filterResults;
        });
      }
    }

    return allCategories;
  }

  /// 加载每个分类的交易笔数
  Future<void> _loadTransactionCounts() async {
    try {
      final repo = ref.read(repositoryProvider);

      // 获取交易（ledgerId 可选，不传则获取所有账本）
      final transactions = await repo.transactionsWithCategoryAll(ledgerId: widget.ledgerId).first;

      // 统计每个分类的笔数
      final counts = <int, int>{};
      for (final item in transactions) {
        if (item.category != null) {
          counts[item.category!.id] = (counts[item.category!.id] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _transactionCounts = counts;
        });
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 构建分类分组数据
  List<_CategoryGroup> _buildCategoryGroups(List<Category> allCategories) {
    // 按类型筛选
    final typedCategories = allCategories.where((c) => c.kind == widget.type).toList();

    // 应用排除规则
    final filteredCategories = typedCategories.where((c) {
      // 排除指定ID
      if (widget.excludeIds?.contains(c.id) ?? false) return false;

      // 排除指定名称
      if (widget.excludeNames?.contains(c.name) ?? false) return false;

      return true;
    }).toList();

    // 分离父分类和子分类
    final parentCategories = <Category>[];
    final childCategories = <Category>[];
    final parentIds = <int>{};

    // 第一轮：找出所有父分类
    for (final category in filteredCategories) {
      if (category.parentId != null) {
        parentIds.add(category.parentId!);
        childCategories.add(category);
      }
    }

    // 第二轮：获取所有父分类
    for (final category in filteredCategories) {
      if (category.parentId == null) {
        parentCategories.add(category);
      }
    }

    // 构建分组
    final groups = <_CategoryGroup>[];

    for (final parent in parentCategories) {
      final hasChildren = parentIds.contains(parent.id);
      final children = childCategories
          .where((c) => c.parentId == parent.id)
          .toList();

      // 判断父分类是否可选
      bool isParentSelectable = !hasChildren || widget.includeParentCategories;
      // 如果有过滤器，应用过滤器结果
      if (widget.categoryFilter != null && _categoryFilterResults.containsKey(parent.id)) {
        isParentSelectable = isParentSelectable && _categoryFilterResults[parent.id]!;
      }

      // 应用搜索过滤
      if (_searchText.isNotEmpty) {
        final parentName = CategoryUtils.getDisplayName(parent.name, context).toLowerCase();
        final parentMatches = parentName.contains(_searchText);

        final matchedChildren = children.where((c) {
          final childName = CategoryUtils.getDisplayName(c.name, context).toLowerCase();
          return childName.contains(_searchText);
        }).toList();

        // 如果父分类匹配，显示所有子分类
        if (parentMatches) {
          groups.add(_CategoryGroup(
            parent: parent,
            children: children,
            isExpanded: true,
            isParentSelectable: isParentSelectable,
          ));
        } else if (matchedChildren.isNotEmpty) {
          // 如果只有子分类匹配，只显示匹配的子分类
          groups.add(_CategoryGroup(
            parent: parent,
            children: matchedChildren,
            isExpanded: true,
            isParentSelectable: isParentSelectable,
          ));
        }
      } else {
        // 无搜索时，显示所有
        // 判断是否需要展开：如果当前选中的是子分类且属于该父分类，则展开
        bool shouldExpand = widget.expandChildrenByDefault;
        if (widget.currentCategoryId != null && !shouldExpand) {
          // 检查是否有子分类被选中
          shouldExpand = children.any((c) => c.id == widget.currentCategoryId);
        }

        groups.add(_CategoryGroup(
          parent: parent,
          children: children,
          isExpanded: shouldExpand,
          isParentSelectable: isParentSelectable,
        ));
      }
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    // §7 共享账本:WS shared_resource_change 推送后 tick bump 触发 rebuild
    // → 下方 FutureBuilder 拿到新 Future 重查 SharedLedgerCategories。
    // 否则 A 改分类名 B 这边 picker 显示旧名,要重启 app。
    ref.watch(sharedResourceRefreshProvider);
    final l10n = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: BeeTokens.scaffoldBackground(context),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: BeeTokens.scaffoldBackground(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
        children: [
          // 顶部栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: BeeTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(
                  color: BeeTokens.divider(context),
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title ?? (widget.type == 'income'
                              ? l10n.categoryIncome
                              : l10n.categoryExpense),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: BeeTokens.textPrimary(context),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: BeeTokens.iconPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 搜索框
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.searchCategoryHint,
                      prefixIcon: Icon(
                        Icons.search,
                        color: BeeTokens.iconTertiary(context),
                      ),
                      suffixIcon: _searchText.isNotEmpty
                          ? IconButton(
                              onPressed: () => _searchController.clear(),
                              icon: Icon(
                                Icons.clear,
                                color: BeeTokens.iconTertiary(context),
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: BeeTokens.border(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ref.watch(primaryColorProvider),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      filled: true,
                      fillColor: BeeTokens.surface(context),
                    ),
                  ),
                ],
              ),
            ),
          // 分类列表
          Expanded(
            child: FutureBuilder<List<Category>>(
              future: _loadAllCategories(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final groups = _buildCategoryGroups(snapshot.data!);

                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: BeeTokens.textTertiary(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchText.isNotEmpty
                              ? l10n.searchNoResults
                              : l10n.categoryEmpty,
                          style: TextStyle(
                            color: BeeTokens.textTertiary(context),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _CategoryGroupItem(
                      group: group,
                      currentCategoryId: widget.currentCategoryId,
                      showTransactionCount: widget.showTransactionCount,
                      transactionCounts: _transactionCounts,
                      primaryColor: ref.watch(primaryColorProvider),
                      onCategorySelected: (category) {
                        Navigator.pop(context, category);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// 分类分组数据
class _CategoryGroup {
  final Category parent;
  final List<Category> children;
  final bool isExpanded;
  final bool isParentSelectable;

  _CategoryGroup({
    required this.parent,
    required this.children,
    this.isExpanded = false,
    required this.isParentSelectable,
  });
}

/// 分类分组项组件
class _CategoryGroupItem extends StatefulWidget {
  final _CategoryGroup group;
  final int? currentCategoryId;
  final bool showTransactionCount;
  final Map<int, int> transactionCounts;
  final Color primaryColor;
  final Function(Category) onCategorySelected;

  const _CategoryGroupItem({
    required this.group,
    this.currentCategoryId,
    required this.showTransactionCount,
    required this.transactionCounts,
    required this.primaryColor,
    required this.onCategorySelected,
  });

  @override
  State<_CategoryGroupItem> createState() => _CategoryGroupItemState();
}

class _CategoryGroupItemState extends State<_CategoryGroupItem> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.group.isExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final hasChildren = widget.group.children.isNotEmpty;
    final isParentSelectable = widget.group.isParentSelectable;

    return Column(
      children: [
        // 父分类
        _CategoryTile(
          category: widget.group.parent,
          isSelected: widget.currentCategoryId == widget.group.parent.id,
          showTransactionCount: widget.showTransactionCount,
          transactionCount: widget.transactionCounts[widget.group.parent.id] ?? 0,
          primaryColor: widget.primaryColor,
          isParent: hasChildren,
          isExpanded: _isExpanded,
          isSelectable: isParentSelectable,
          onTap: () {
            if (hasChildren) {
              // 如果有子分类，总是展开/收起
              setState(() {
                _isExpanded = !_isExpanded;
              });
            } else if (isParentSelectable) {
              // 如果是可选的普通分类（无子分类），则选择
              widget.onCategorySelected(widget.group.parent);
            }
          },
        ),
        // 子分类（如果展开）
        if (hasChildren && _isExpanded)
          ...widget.group.children.map((child) {
            return _CategoryTile(
              category: child,
              isSelected: widget.currentCategoryId == child.id,
              showTransactionCount: widget.showTransactionCount,
              transactionCount: widget.transactionCounts[child.id] ?? 0,
              primaryColor: widget.primaryColor,
              isChild: true,
              onTap: () {
                widget.onCategorySelected(child);
              },
            );
          }),
      ],
    );
  }
}

/// 分类项组件
class _CategoryTile extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final bool showTransactionCount;
  final int transactionCount;
  final Color primaryColor;
  final bool isParent;
  final bool isChild;
  final bool isExpanded;
  final bool isSelectable;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    this.isSelected = false,
    required this.showTransactionCount,
    required this.transactionCount,
    required this.primaryColor,
    this.isParent = false,
    this.isChild = false,
    this.isExpanded = false,
    this.isSelectable = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 不可选时显示为半透明
    final opacity = !isSelectable ? 0.5 : 1.0;

    return InkWell(
      onTap: isSelectable || isParent ? onTap : null, // 不可选且非父分类时禁用点击
      child: Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
            // 选中状态背景色（通栏）
            color: isSelected
                ? primaryColor.withValues(alpha: 0.08)
                : null,
            border: Border(
              bottom: BorderSide(
                color: BeeTokens.divider(context),
                width: 0.5,
              ),
            ),
          ),
          child: Padding(
            // 子分类添加左边距，父分类正常边距
            padding: EdgeInsets.fromLTRB(
              isChild ? 56 : 16,  // 左边距：子分类56，父分类16
              12,
              16,
              12,
            ),
            child: Row(
              children: [
                // 分类图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor.withValues(alpha: 0.15)
                        : primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    // 选中状态添加边框
                    border: isSelected
                        ? Border.all(color: primaryColor, width: 1.5)
                        : null,
                  ),
                  child: CategoryIconWidget(
                    category: category,
                    size: 24,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                // 分类名称
                Expanded(
                  child: Text(
                    CategoryUtils.getDisplayName(category.name, context),
                    style: TextStyle(
                      fontSize: isChild ? 15 : 16,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : (isChild ? FontWeight.normal : FontWeight.w500),
                      color: isSelected
                          ? primaryColor
                          : BeeTokens.textPrimary(context),
                    ),
                  ),
                ),
                // 交易笔数
                if (showTransactionCount && transactionCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: BeeTokens.surface(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      AppLocalizations.of(context).tagTransactionCount(transactionCount),
                      style: TextStyle(
                        fontSize: 12,
                        color: BeeTokens.textSecondary(context),
                      ),
                    ),
                  ),
                // 选中图标
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check_circle,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                // 展开/收起图标（父分类总是显示）
                if (isParent)
                  Padding(
                    padding: EdgeInsets.only(left: isSelected ? 0 : 8),
                    child: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: BeeTokens.iconSecondary(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
