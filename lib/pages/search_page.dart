import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db.dart';
import '../providers.dart';
import '../widgets/biz/biz.dart';
import '../widgets/ui/ui.dart';
import '../styles/colors.dart';

/// 搜索页面
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  List<({Transaction t, Category? category})> _searchResults = [];
  List<({Transaction t, Category? category})> _allTransactions = [];
  bool _isSearching = false;
  String _searchText = '';
  double? _minAmount;
  double? _maxAmount;
  bool _showAmountFilter = false;
  bool _hasInitializedAmountFilter = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchText = _searchController.text.trim();
    });
    _performSearch();
  }

  void _onAmountFilterChanged() {
    setState(() {
      _minAmount = double.tryParse(_minAmountController.text.trim());
      _maxAmount = double.tryParse(_maxAmountController.text.trim());
    });
    _performSearch();
  }

  /// 执行搜索
  void _performSearch() {
    if (_searchText.isEmpty && _minAmount == null && _maxAmount == null) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // 模糊匹配搜索
    final results = _allTransactions.where((item) {
      final transaction = item.t;
      final category = item.category;

      // 文本搜索：备注、分类名称
      bool textMatch = true;
      if (_searchText.isNotEmpty) {
        final searchLower = _searchText.toLowerCase();
        final note = transaction.note?.toLowerCase() ?? '';
        final categoryName = (category?.name ?? '未分类').toLowerCase();
        final amountStr = transaction.amount.toString();

        textMatch = note.contains(searchLower) ||
                   categoryName.contains(searchLower) ||
                   amountStr.contains(searchLower);
      }

      // 金额范围搜索
      bool amountMatch = true;
      if (_minAmount != null || _maxAmount != null) {
        final amount = transaction.amount;
        if (_minAmount != null && amount < _minAmount!) {
          amountMatch = false;
        }
        if (_maxAmount != null && amount > _maxAmount!) {
          amountMatch = false;
        }
      }

      return textMatch && amountMatch;
    }).toList();

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final hide = ref.watch(hideAmountsProvider);

    // 监听金额筛选开关的持久化状态
    ref.listen<AsyncValue<bool>>(searchAmountFilterEnabledProvider, (previous, next) {
      next.whenData((enabled) {
        if (!_hasInitializedAmountFilter) {
          setState(() {
            _showAmountFilter = enabled;
            _hasInitializedAmountFilter = true;
          });
        }
      });
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 使用PrimaryHeader仅作为标题
          PrimaryHeader(
            title: '搜索',
            showBack: true,
          ),
          // 搜索框区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 文本搜索框
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索备注、分类或金额...',
                    prefixIcon: const Icon(Icons.search, color: BeeColors.black54),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                            },
                            icon: const Icon(Icons.clear, color: BeeColors.black54),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 12),
                // 金额筛选切换
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '金额范围筛选',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BeeColors.primaryText,
                        ),
                      ),
                    ),
                    Switch(
                      value: _showAmountFilter,
                      onChanged: (value) async {
                        setState(() {
                          _showAmountFilter = value;
                          if (!value) {
                            _minAmountController.clear();
                            _maxAmountController.clear();
                            _minAmount = null;
                            _maxAmount = null;
                            _performSearch();
                          }
                        });

                        // 保存设置到SharedPreferences
                        final setter = ref.read(searchSettingsSetterProvider);
                        await setter.setAmountFilterEnabled(value);
                      },
                    ),
                  ],
                ),
                // 金额范围输入框
                if (_showAmountFilter) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '最小金额',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          ),
                          onChanged: (value) => _onAmountFilterChanged(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('至', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _maxAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '最大金额',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          ),
                          onChanged: (value) => _onAmountFilterChanged(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // 搜索结果
          Expanded(
            child: StreamBuilder<List<({Transaction t, Category? category})>>(
              stream: repo.transactionsWithCategoryAll(ledgerId: ledgerId),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  _allTransactions = snapshot.data!;
                  // 如果有搜索条件但还没有结果，执行搜索
                  if ((_searchText.isNotEmpty || _minAmount != null || _maxAmount != null) &&
                      _searchResults.isEmpty && !_isSearching) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _performSearch();
                    });
                  }
                }

                if (_isSearching) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (_searchText.isEmpty && _minAmount == null && _maxAmount == null) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 64,
                          color: BeeColors.black54,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '输入关键词开始搜索',
                          style: TextStyle(
                            color: BeeColors.black54,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (_searchResults.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: BeeColors.black54,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '未找到匹配的结果',
                          style: TextStyle(
                            color: BeeColors.black54,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 使用可复用的TransactionList组件显示搜索结果
                return TransactionList(
                  transactions: _searchResults,
                  hideAmounts: hide,
                  enableVisibilityTracking: false, // 搜索页面不需要可见性跟踪
                  emptyWidget: const AppEmpty(
                    text: '未找到匹配的结果',
                    subtext: '请尝试其他关键词或调整筛选条件',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}