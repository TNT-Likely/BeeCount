import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../widgets/biz/biz.dart';
import '../../widgets/ui/ui.dart';
import '../../styles/tokens.dart';
import '../../utils/category_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/transaction_edit_utils.dart';
import '../../widgets/category_icon.dart';
import 'category_detail_page.dart';

/// 搜索页面
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<({Transaction t, Category? category, Account? account, Account? toAccount})> _searchResults = [];
  List<({Transaction t, Category? category, Account? account, Account? toAccount})> _allTransactions = [];
  bool _isSearching = false;
  String _searchText = '';

  // 筛选条件
  double? _minAmount;
  double? _maxAmount;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _hasScheduledSearch = false; // 防止重复调度搜索

  // 批量操作相关
  bool _isBatchMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchText = _searchController.text.trim();
    });
    _performSearch();
  }

  /// 执行搜索
  void _performSearch() {
    // 如果没有任何搜索条件，清空结果
    if (_searchText.isEmpty && _minAmount == null && _maxAmount == null &&
        _startDate == null && _endDate == null) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _hasScheduledSearch = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasScheduledSearch = false;
    });

    final results = _allTransactions.where((item) {
      final transaction = item.t;
      final category = item.category;

      // 文本搜索
      bool textMatch = true;
      if (_searchText.isNotEmpty) {
        final searchLower = _searchText.toLowerCase();
        final note = transaction.note?.toLowerCase() ?? '';
        final categoryName =
            CategoryUtils.getDisplayName(category?.name, context).toLowerCase();
        final amountStr = transaction.amount.toString();

        textMatch = note.contains(searchLower) ||
            categoryName.contains(searchLower) ||
            amountStr.contains(searchLower);
      }

      // 金额范围搜索
      bool amountMatch = true;
      if (_minAmount != null || _maxAmount != null) {
        final amount = transaction.amount.abs();
        if (_minAmount != null && amount < _minAmount!) {
          amountMatch = false;
        }
        if (_maxAmount != null && amount > _maxAmount!) {
          amountMatch = false;
        }
      }

      // 时间范围搜索
      bool dateMatch = true;
      if (_startDate != null || _endDate != null) {
        final happenedAt = transaction.happenedAt;
        if (_startDate != null) {
          final startOfDay = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          if (happenedAt.isBefore(startOfDay)) {
            dateMatch = false;
          }
        }
        if (_endDate != null) {
          final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
          if (happenedAt.isAfter(endOfDay)) {
            dateMatch = false;
          }
        }
      }

      return textMatch && amountMatch && dateMatch;
    }).toList();

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  /// 从数据库重新加载并执行搜索
  Future<void> _performSearchFromDb() async {
    if (!mounted) return;

    final repo = ref.read(repositoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);

    setState(() {
      _isSearching = true;
    });

    // 从数据库重新获取所有交易
    final allTransactions =
        await repo.transactionsWithCategoryAll(ledgerId: ledgerId).first;

    if (!mounted) return;

    // 更新_allTransactions
    _allTransactions = allTransactions;

    // 执行搜索筛选
    _performSearch();
  }

  /// 切换批量操作模式
  void _toggleBatchMode() {
    setState(() {
      _isBatchMode = !_isBatchMode;
      if (!_isBatchMode) {
        _selectedIds.clear();
      }
    });
  }

  /// 切换选择
  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  /// 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _searchResults.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
        _selectedIds.addAll(_searchResults.map((e) => e.t.id));
      }
    });
  }

  /// 显示筛选弹窗
  Future<void> _showFilterDialog() async {
    final l10n = AppLocalizations.of(context);
    double? tempMinAmount = _minAmount;
    double? tempMaxAmount = _maxAmount;
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(l10n.searchFilterTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 金额筛选
                  Text(l10n.searchAmountFilter, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: l10n.searchMinAmount,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          controller: TextEditingController(text: tempMinAmount?.toString() ?? ''),
                          onChanged: (value) {
                            tempMinAmount = double.tryParse(value);
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('~'),
                      ),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: l10n.searchMaxAmount,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          controller: TextEditingController(text: tempMaxAmount?.toString() ?? ''),
                          onChanged: (value) {
                            tempMaxAmount = double.tryParse(value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 时间筛选
                  Text(l10n.searchDateFilter, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(l10n.searchStartDate),
                    subtitle: Text(tempStartDate != null
                        ? '${tempStartDate!.year}-${tempStartDate!.month.toString().padLeft(2, '0')}-${tempStartDate!.day.toString().padLeft(2, '0')}'
                        : l10n.searchNotSet),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tempStartDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setState(() {
                                tempStartDate = null;
                              });
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today, size: 20),
                          onPressed: () async {
                            final date = await showWheelDatePicker(
                              context,
                              initial: tempStartDate ?? DateTime.now(),
                              mode: WheelDatePickerMode.ymd,
                              minDate: DateTime(2000),
                              maxDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                tempStartDate = date;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(l10n.searchEndDate),
                    subtitle: Text(tempEndDate != null
                        ? '${tempEndDate!.year}-${tempEndDate!.month.toString().padLeft(2, '0')}-${tempEndDate!.day.toString().padLeft(2, '0')}'
                        : l10n.searchNotSet),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tempEndDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setState(() {
                                tempEndDate = null;
                              });
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today, size: 20),
                          onPressed: () async {
                            final date = await showWheelDatePicker(
                              context,
                              initial: tempEndDate ?? DateTime.now(),
                              mode: WheelDatePickerMode.ymd,
                              minDate: DateTime(2000),
                              maxDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                tempEndDate = date;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: () {
                  // 清空筛选
                  setState(() {
                    tempMinAmount = null;
                    tempMaxAmount = null;
                    tempStartDate = null;
                    tempEndDate = null;
                  });
                },
                child: Text(l10n.searchClearFilter),
              ),
              TextButton(
                onPressed: () {
                  this.setState(() {
                    _minAmount = tempMinAmount;
                    _maxAmount = tempMaxAmount;
                    _startDate = tempStartDate;
                    _endDate = tempEndDate;
                  });
                  _performSearch();
                  Navigator.pop(context);
                },
                child: Text(l10n.commonConfirm),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 批量操作完成后刷新
  Future<void> _refreshAfterBatchOperation(int count, String operation) async {
    if (mounted) {
      showToast(context, operation);
      setState(() {
        _selectedIds.clear();
        _isBatchMode = false;
      });
      // 从数据库重新加载最新数据并执行搜索
      await _performSearchFromDb();
    }
  }

  /// 批量删除对话框
  void _showBatchDeleteDialog() {
    final count = _selectedIds.length;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.searchBatchDeleteConfirmTitle),
        content: Text(l10n.searchBatchDeleteConfirmMessage(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeBatchDelete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  /// 执行批量删除
  Future<void> _executeBatchDelete() async {
    final count = _selectedIds.length;
    final l10n = AppLocalizations.of(context);

    try {
      final repo = ref.read(repositoryProvider);
      // 批量删除交易
      for (final id in _selectedIds) {
        await repo.deleteTransaction(id);
      }
      ref.read(budgetRefreshProvider.notifier).state++;
      await _refreshAfterBatchOperation(
          count, l10n.searchBatchDeleteSuccess(count));
    } catch (e) {
      if (mounted) {
        showToast(context, l10n.searchBatchDeleteFailed(e.toString()));
      }
    }
  }

  /// 批量设置备注对话框
  void _showBatchSetNoteDialog() {
    _noteController.clear();
    final count = _selectedIds.length;
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.searchBatchSetNoteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.searchBatchSetNoteMessage(count)),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: l10n.searchBatchSetNoteHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () async {
              final note = _noteController.text.trim();
              Navigator.pop(context);
              await _executeBatchSetNote(note);
            },
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  /// 执行批量设置备注
  Future<void> _executeBatchSetNote(String note) async {
    final repo = ref.read(repositoryProvider);
    final count = _selectedIds.length;
    final l10n = AppLocalizations.of(context);

    try {
      // 批量更新备注
      for (final id in _selectedIds) {
        // 先获取交易详情
        final tx = await repo.getTransactionById(id);
        if (tx != null) {
          // 更新交易（保持其他字段不变）
          await repo.updateTransaction(
            id: id,
            type: tx.type,
            amount: tx.amount,
            categoryId: tx.categoryId,
            note: note.isEmpty ? null : note,
            happenedAt: tx.happenedAt,
            accountId: tx.accountId,
          );
        }
      }
      await _refreshAfterBatchOperation(
          count, l10n.searchBatchSetNoteSuccess(count));
    } catch (e) {
      if (mounted) {
        showToast(context, l10n.searchBatchSetNoteFailed(e.toString()));
      }
    }
  }

  /// 批量调整分类对话框
  Future<void> _showBatchChangeCategoryDialog() async {
    final l10n = AppLocalizations.of(context);

    // 检查选中的交易类型是否一致
    final selectedTransactions = _searchResults
        .where((item) => _selectedIds.contains(item.t.id))
        .toList();

    // 获取所有选中交易的类型
    final types = selectedTransactions.map((item) => item.t.type).toSet();

    // 如果包含转账类型或类型不一致，则不允许修改分类
    if (types.contains('transfer')) {
      showToast(context, l10n.searchBatchCategoryTransferError);
      return;
    }

    if (types.length > 1) {
      showToast(context, l10n.searchBatchCategoryTypeError);
      return;
    }

    // 获取统一的交易类型
    final transactionType = types.first;

    // 显示分类选择器
    final selectedCategory = await showCategorySelector(
      context,
      type: transactionType,
      includeParentCategories: false, // 不包含有子分类的父分类
      showTransactionCount: true, // 显示笔数
      ledgerId: ref.read(currentLedgerIdProvider),
    );

    if (selectedCategory != null) {
      await _executeBatchChangeCategory(selectedCategory.id);
    }
  }

  /// 执行批量调整分类
  Future<void> _executeBatchChangeCategory(int categoryId) async {
    final repo = ref.read(repositoryProvider);
    final count = _selectedIds.length;
    final l10n = AppLocalizations.of(context);

    try {
      // 批量更新分类
      for (final id in _selectedIds) {
        // 先获取交易详情
        final tx = await repo.getTransactionById(id);
        if (tx != null) {
          // 更新交易（保持其他字段不变）
          await repo.updateTransaction(
            id: id,
            type: tx.type,
            amount: tx.amount,
            categoryId: categoryId,
            note: tx.note,
            happenedAt: tx.happenedAt,
            accountId: tx.accountId,
          );
        }
      }
      await _refreshAfterBatchOperation(
          count, l10n.searchBatchChangeCategorySuccess(count));
    } catch (e) {
      if (mounted) {
        showToast(context, l10n.searchBatchChangeCategoryFailed(e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final hide = ref.watch(hideAmountsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          // 使用PrimaryHeader
          PrimaryHeader(
            title: _isBatchMode
                ? l10n.searchBatchModeWithCount(
                    _selectedIds.length, _searchResults.length)
                : l10n.searchTitle,
            showBack: !_isBatchMode,
            actions: _isBatchMode && _searchResults.isNotEmpty
                ? [
                    TextButton(
                      onPressed: _toggleSelectAll,
                      child: Text(
                        _selectedIds.length == _searchResults.length
                            ? l10n.searchDeselectAll
                            : l10n.searchSelectAll,
                        style:
                            TextStyle(color: ref.watch(primaryColorProvider)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _toggleBatchMode,
                      tooltip: l10n.searchExitBatchMode,
                    ),
                  ]
                : null,
          ),
          // 搜索框区域
          if (!_isBatchMode) // 批量模式下隐藏搜索框
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              decoration: BoxDecoration(
                color: BeeTokens.surfaceElevated(context),
                boxShadow: BeeTokens.isDark(context) ? null : [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 搜索框和筛选按钮
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context).searchHint,
                            prefixIcon: Icon(Icons.search,
                                color: BeeTokens.textTertiary(context)),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                    icon: Icon(Icons.clear,
                                        color: BeeTokens.textTertiary(context)),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 筛选按钮
                      IconButton(
                        onPressed: _showFilterDialog,
                        icon: Icon(
                          Icons.filter_list,
                          color: (_minAmount != null || _maxAmount != null ||
                                  _startDate != null || _endDate != null)
                              ? ref.watch(primaryColorProvider)
                              : BeeTokens.iconPrimary(context),
                        ),
                        tooltip: l10n.searchFilterTitle,
                      ),
                    ],
                  ),
                  // 显示已选筛选条件
                  if (_minAmount != null || _maxAmount != null ||
                      _startDate != null || _endDate != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_minAmount != null || _maxAmount != null)
                          Chip(
                            label: Text(
                              '${l10n.searchAmountFilter}: ${_minAmount?.toStringAsFixed(2) ?? '0'} ~ ${_maxAmount?.toStringAsFixed(2) ?? '∞'}',
                              style: TextStyle(fontSize: 12, color: ref.watch(primaryColorProvider)),
                            ),
                            backgroundColor: ref.watch(primaryColorProvider).withValues(alpha: 0.1),
                            side: BorderSide(color: ref.watch(primaryColorProvider), width: 1),
                            deleteIconColor: ref.watch(primaryColorProvider),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _minAmount = null;
                                _maxAmount = null;
                              });
                              _performSearch();
                            },
                          ),
                        if (_startDate != null || _endDate != null)
                          Chip(
                            label: Text(
                              '${l10n.searchDateFilter}: ${_startDate != null ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}' : l10n.searchDateStart} ~ ${_endDate != null ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}' : l10n.searchDateEnd}',
                              style: TextStyle(fontSize: 12, color: ref.watch(primaryColorProvider)),
                            ),
                            backgroundColor: ref.watch(primaryColorProvider).withValues(alpha: 0.1),
                            side: BorderSide(color: ref.watch(primaryColorProvider), width: 1),
                            deleteIconColor: ref.watch(primaryColorProvider),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                              });
                              _performSearch();
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          // 搜索结果
          Expanded(
            child: StreamBuilder<List<({Transaction t, Category? category, Account? account, Account? toAccount})>>(
              stream: repo.transactionsWithCategoryAll(ledgerId: ledgerId),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  _allTransactions = snapshot.data!;
                  if ((_searchText.isNotEmpty ||
                          _minAmount != null ||
                          _maxAmount != null ||
                          _startDate != null ||
                          _endDate != null) &&
                      _searchResults.isEmpty &&
                      !_isSearching &&
                      !_hasScheduledSearch) {
                    _hasScheduledSearch = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _performSearch();
                      }
                    });
                  }
                }

                if (_isSearching) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_searchText.isEmpty &&
                    _minAmount == null &&
                    _maxAmount == null &&
                    _startDate == null &&
                    _endDate == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search,
                            size: 64, color: BeeTokens.textTertiary(context)),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context).searchNoInput,
                          style: TextStyle(
                              color: BeeTokens.textTertiary(context), fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                if (_searchResults.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: BeeTokens.textTertiary(context)),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context).searchNoResults,
                          style: TextStyle(
                              color: BeeTokens.textTertiary(context), fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                // 显示搜索结果列表
                return Column(
                  children: [
                    // 批量操作入口 - 仅在非批量模式且有搜索结果时显示
                    if (!_isBatchMode)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        decoration: BoxDecoration(
                          color: BeeTokens.surfaceElevated(context),
                        ),
                        child: Row(
                          children: [
                            Text(
                              l10n.searchResultsCount(_searchResults.length),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: BeeTokens.textTertiary(context),
                                  ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _toggleBatchMode,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue,
                              ),
                              child: Text(l10n.searchBatchMode),
                            ),
                          ],
                        ),
                      ),
                    // 批量模式下的操作栏
                    if (_isBatchMode)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        decoration: BoxDecoration(
                          color: BeeTokens.surfaceElevated(context),
                        ),
                        child: Column(
                          children: [
                            // 全选按钮
                            Row(
                              children: [
                                Text(
                                  l10n.searchSelectedCount(_selectedIds.length),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: BeeTokens.textTertiary(context),
                                      ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: _toggleSelectAll,
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        ref.watch(primaryColorProvider),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    minimumSize: const Size(0, 32),
                                  ),
                                  child: Text(
                                    _selectedIds.length == _searchResults.length
                                        ? l10n.searchDeselectAll
                                        : l10n.searchSelectAll,
                                  ),
                                ),
                              ],
                            ),
                            // 批量操作按钮 - 始终显示，未选择时禁用
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _selectedIds.isEmpty
                                        ? null
                                        : _showBatchSetNoteDialog,
                                    icon: const Icon(Icons.edit_note, size: 16),
                                    label: Text(l10n.searchBatchSetNote,
                                        style: const TextStyle(fontSize: 13)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          ref.watch(primaryColorProvider),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6, horizontal: 8),
                                      minimumSize: const Size(0, 36),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _selectedIds.isEmpty
                                        ? null
                                        : _showBatchChangeCategoryDialog,
                                    icon: const Icon(Icons.category, size: 16),
                                    label: Text(l10n.searchBatchChangeCategory,
                                        style: const TextStyle(fontSize: 13)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          ref.watch(primaryColorProvider),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6, horizontal: 8),
                                      minimumSize: const Size(0, 36),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _selectedIds.isEmpty
                                        ? null
                                        : _showBatchDeleteDialog,
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16),
                                    label: Text(l10n.commonDelete,
                                        style: const TextStyle(fontSize: 13)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6, horizontal: 8),
                                      minimumSize: const Size(0, 36),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    // 列表
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          final isTransfer = item.t.type == 'transfer';
                          final isExpense = item.t.type == 'expense';

                          // 获取分类显示名称
                          final categoryName = CategoryUtils.getDisplayName(item.category?.name, context);

                          final subtitle = item.t.note ?? '';
                          final isSelected = _selectedIds.contains(item.t.id);

                          final iconData = getCategoryIconData(
                              category: item.category,
                              categoryName: categoryName);

                          return Column(
                            children: [
                              TransactionListItem(
                                icon: iconData,
                                category: item.category,
                                title: subtitle,
                                categoryName: categoryName,
                                amount: item.t.amount,
                                isExpense: isExpense,
                                hide: hide,
                                happenedAt: item.t.happenedAt,
                                showFullDate: true,
                                isSelectionMode: _isBatchMode,
                                isSelected: isSelected,
                                onSelectionChanged: () =>
                                    _toggleSelection(item.t.id),
                                onTap: _isBatchMode
                                    ? null
                                    : () async {
                                        await TransactionEditUtils
                                            .editTransaction(
                                          context,
                                          ref,
                                          item.t,
                                          item.category,
                                        );
                                      },
                                onCategoryTap: _isBatchMode ||
                                        isTransfer ||
                                        item.category?.id == null
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => CategoryDetailPage(
                                              categoryId: item.category!.id,
                                              categoryName: categoryName,
                                            ),
                                          ),
                                        );
                                      },
                              ),
                              if (index < _searchResults.length - 1)
                                BeeDivider.short(
                                    indent: 56 + 16, endIndent: 16),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
