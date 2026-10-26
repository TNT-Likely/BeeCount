import 'dart:math' as math;
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/v4/bindings/category_selector.dart';
import '../../presentation/v4/bindings/recording_category_icon.dart';
import '../../providers.dart';
import '../../providers/shared_ledger_providers.dart';
import '../../utils/category_utils.dart';

/// 分类过滤器回调类型
/// 返回 true 表示该分类可选，返回 false 表示不可选（置灰）
typedef CategoryFilterCallback = Future<bool> Function(Category category);

/// 显示分类选择器
///
/// [type] 分类类型：'income'、'expense' 或 'all'
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
  FocusManager.instance.primaryFocus?.unfocus();
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
  ConsumerState<CategorySelectorDialog> createState() =>
      _CategorySelectorDialogState();
}

class _CategorySelectorDialogState
    extends ConsumerState<CategorySelectorDialog> {
  late Future<CategorySelectorData> _future;
  late Object _loadedSignature;

  Object _signature() => (
        ref.read(repositoryProvider),
        ref.read(sharedResourceRefreshProvider),
        ref.read(syncGenerationProvider)
      );

  Future<CategorySelectorData> _load() =>
      loadCategorySelectorData(ref.read(repositoryProvider),
          ledgerId: widget.ledgerId,
          onlyTopLevel: widget.onlyTopLevel,
          showTransactionCount: widget.showTransactionCount,
          categoryFilter: widget.categoryFilter);

  @override
  void initState() {
    super.initState();
    _loadedSignature = _signature();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant CategorySelectorDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ledgerId != widget.ledgerId ||
        oldWidget.onlyTopLevel != widget.onlyTopLevel ||
        oldWidget.showTransactionCount != widget.showTransactionCount ||
        oldWidget.categoryFilter != widget.categoryFilter) {
      _future = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(repositoryProvider);
    ref.watch(sharedResourceRefreshProvider);
    ref.watch(syncGenerationProvider);
    final signature = _signature();
    if (signature != _loadedSignature) {
      _loadedSignature = signature;
      _future = _load();
    }
    final l = AppLocalizations.of(context);
    final availableHeight = MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom -
        MediaQuery.viewPaddingOf(context).vertical;
    return BeeDialog(
      title: Text(widget.title ??
          (widget.type == 'all'
              ? l.searchCategoryFilter
              : widget.type == 'income'
                  ? l.categoryIncome
                  : l.categoryExpense)),
      content: SizedBox(
        width: double.maxFinite,
        height: math.min(440, availableHeight * .62),
        child: FutureBuilder<CategorySelectorData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: BeeStatus(
                label: l.v4RecordingCategoriesFailed,
                tone: BeeTone.error,
                action: BeeButton(
                    label: l.v4RecordingRetry,
                    onPressed: () => setState(() {
                          _future = _load();
                        })),
              ));
            }
            final data = snapshot.requireData;
            final records = data.categories
                .where((c) =>
                    (widget.type == 'all' || c.kind == widget.type) &&
                    !(widget.excludeNames?.contains(c.name) ?? false) &&
                    !(widget.excludeIds?.contains(c.id) ?? false))
                .toList();
            final parents = records.where((c) => c.parentId == null).toList();
            BeeCategoryChoice choice(Category category, {bool parent = false}) {
              final children = parent
                  ? records.where((c) => c.parentId == category.id).toList()
                  : <Category>[];
              final count = data.counts[category.id] ?? 0;
              final details = [
                if (widget.type == 'all')
                  category.kind == 'income'
                      ? l.categoryIncome
                      : l.categoryExpense,
                if (widget.showTransactionCount && count > 0)
                  l.tagTransactionCount(count),
              ];
              return BeeCategoryChoice(
                id: '${category.id}',
                label: CategoryUtils.getDisplayName(category.name, context),
                icon: RecordingCategoryIcon(category: category, size: 18),
                enabled: (data.eligible[category.id] ?? true) &&
                    (!parent ||
                        children.isEmpty ||
                        widget.includeParentCategories),
                detail: details.isEmpty ? null : details.join(' · '),
                children: children.map((c) => choice(c)).toList(),
              );
            }

            return BeeCategoryPicker(
              key: ValueKey((
                widget.type,
                widget.ledgerId,
                widget.onlyTopLevel,
                widget.includeParentCategories,
                Object.hashAll(widget.excludeNames ?? []),
                Object.hashAll(widget.excludeIds ?? [])
              )),
              items: parents.map((c) => choice(c, parent: true)).toList(),
              selected: widget.currentCategoryId?.toString(),
              immediate: true,
              expandAllChildren: widget.expandChildrenByDefault,
              searchLabel: l.searchCategoryHint,
              emptyLabel: l.categoryEmpty,
              confirmLabel: l.commonConfirm,
              cancelLabel: l.commonCancel,
              onCancel: () => Navigator.pop(context),
              onConfirm: (id) => Navigator.pop(
                  context, records.firstWhere((c) => '${c.id}' == id)),
            );
          },
        ),
      ),
    );
  }
}
