import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../../services/system/logger_service.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/transaction_edit_utils.dart';
import '../../utils/category_utils.dart';
import '../category_icon.dart';
import '../../pages/transaction/category_detail_page.dart';
import '../../pages/tag/tag_detail_page.dart';
import '../../pages/attachment/attachment_preview_page.dart';
import '../../l10n/app_localizations.dart';
import '../../services/attachment_service.dart';

/// 可复用的交易列表组件
/// 支持显示分组的交易列表，包含日期头部和交易项
class TransactionList extends ConsumerStatefulWidget {
  /// 完整交易数据（含标签、附件、账户，无需二次加载）
  final List<TransactionDisplayItem>? transactionsWithDetails;

  /// 交易数据（仅含分类，需二次加载标签和附件）
  final List<({Transaction t, Category? category})>? transactions;

  /// 是否隐藏金额
  final bool hideAmounts;

  /// 是否启用可见性检测用于月份跳转（主要用于首页）
  final bool enableVisibilityTracking;

  /// 月份变化回调（用于首页月份跳转逻辑）
  final Function(String dateKey, bool isVisible)? onDateVisibilityChanged;

  /// 自定义空状态显示
  final Widget? emptyWidget;

  /// 列表控制器（可选，用于精准跳转）
  final FlutterListViewController? controller;

  const TransactionList({
    super.key,
    this.transactionsWithDetails,
    this.transactions,
    required this.hideAmounts,
    this.enableVisibilityTracking = false,
    this.onDateVisibilityChanged,
    this.emptyWidget,
    this.controller,
  }) : assert(transactionsWithDetails != null || transactions != null,
            'Either transactionsWithDetails or transactions must be provided');

  @override
  ConsumerState<TransactionList> createState() => TransactionListState();
}

class TransactionListState extends ConsumerState<TransactionList> {
  late FlutterListViewController _controller;
  List<dynamic> _flatItems = []; // 扁平化的项目列表
  final Map<String, int> _dateIndexMap = {}; // 日期到列表索引的映射

  // 缓存标签数据（仅用于非预加载模式）
  Map<int, List<Tag>> _cachedTagsMap = {};
  List<int> _cachedTransactionIds = [];
  int _lastTagRefreshVersion = 0;

  // 缓存附件数量（仅用于非预加载模式）
  Map<int, int> _cachedAttachmentCounts = {};
  int _lastAttachmentRefreshVersion = 0;

  // 标记是否应使用预加载数据（当 Stream 数据与预加载数据不同时切换）
  bool _usePreloadedData = true;

  /// 是否使用完整预加载数据模式
  /// 条件：1) 有预加载数据 2) 还没切换到 Stream 模式
  bool get _hasFullDetails =>
      widget.transactionsWithDetails != null && _usePreloadedData;

  /// 获取统一格式的交易列表（用于内部处理）
  /// 始终使用 transactions 作为列表数据源，预加载数据只用于详情（标签、附件、账户）
  List<({Transaction t, Category? category})> get _transactionsList {
    return widget.transactions ?? [];
  }

  /// 预加载数据的 ID 集合（用于快速判断某条交易是否有预加载详情）
  Set<int>? _preloadedIds;
  Set<int> get _preloadedIdSet {
    if (_preloadedIds == null && widget.transactionsWithDetails != null) {
      _preloadedIds = widget.transactionsWithDetails!.map((t) => t.t.id).toSet();
    }
    return _preloadedIds ?? {};
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? FlutterListViewController();
    // 始终加载标签和附件（用于非预加载范围的交易）
    _loadTags();
    _loadAttachmentCounts();
  }

  @override
  void didUpdateWidget(covariant TransactionList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 检测预加载数据是否变化（如账本切换），重置状态
    if (widget.transactionsWithDetails != oldWidget.transactionsWithDetails) {
      _preloadedIds = null; // 重置预加载 ID 缓存
      if (widget.transactionsWithDetails != null) {
        _usePreloadedData = true; // 重置为预加载模式
      }
    }

    // 检查 transactions 数据变化，重新加载标签和附件
    if (widget.transactions != null) {
      final newIds = widget.transactions!.map((t) => t.t.id).toList();
      if (!_listEquals(newIds, _cachedTransactionIds)) {
        _loadTags();
        _loadAttachmentCounts();
      }
    }
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _loadTags() async {
    final transactionIds = _transactionsList.map((t) => t.t.id).toList();
    if (transactionIds.isEmpty) {
      setState(() {
        _cachedTagsMap = {};
        _cachedTransactionIds = [];
      });
      return;
    }

    final repo = ref.read(repositoryProvider);
    final tagsMap = await repo.getTagsForTransactions(transactionIds);

    if (mounted) {
      setState(() {
        _cachedTagsMap = tagsMap;
        _cachedTransactionIds = transactionIds;
      });
    }
  }

  Future<void> _loadAttachmentCounts() async {
    final transactionIds = _transactionsList.map((t) => t.t.id).toList();
    if (transactionIds.isEmpty) {
      setState(() {
        _cachedAttachmentCounts = {};
      });
      return;
    }

    final repo = ref.read(repositoryProvider);
    final countsMap = await repo.getAttachmentCountsForTransactions(transactionIds);

    if (mounted) {
      setState(() {
        _cachedAttachmentCounts = countsMap;
      });
    }
  }

  /// 检查某条交易是否有预加载详情
  bool _hasPreloadedDetails(int transactionId) {
    return _usePreloadedData && _preloadedIdSet.contains(transactionId);
  }

  /// 获取预加载的交易详情
  TransactionDisplayItem? _getPreloadedItem(int transactionId) {
    if (!_hasPreloadedDetails(transactionId)) return null;
    return widget.transactionsWithDetails!
        .where((item) => item.t.id == transactionId)
        .firstOrNull;
  }

  /// 获取交易的标签列表（优先使用预加载数据）
  List<Tag> _getTagsForTransaction(int transactionId) {
    final preloaded = _getPreloadedItem(transactionId);
    if (preloaded != null) {
      return preloaded.tags;
    }
    return _cachedTagsMap[transactionId] ?? [];
  }

  /// 获取交易的附件数量（优先使用预加载数据）
  int _getAttachmentCountForTransaction(int transactionId) {
    final preloaded = _getPreloadedItem(transactionId);
    if (preloaded != null) {
      return preloaded.attachmentCount;
    }
    return _cachedAttachmentCounts[transactionId] ?? 0;
  }

  /// 获取交易的账户名称（优先使用预加载数据）
  String? _getAccountNameForTransaction(int transactionId) {
    final preloaded = _getPreloadedItem(transactionId);
    if (preloaded != null) {
      return preloaded.accountName;
    }
    return null;
  }

  /// 获取交易的目标账户名称（优先使用预加载数据，用于转账）
  String? _getToAccountNameForTransaction(int transactionId) {
    final preloaded = _getPreloadedItem(transactionId);
    if (preloaded != null) {
      return preloaded.toAccountName;
    }
    return null;
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose(); // 只在我们创建的controller时才dispose
    }
    super.dispose();
  }

  /// 跳转到列表顶部
  void jumpToTop() {
    try {
      _controller.sliverController.jumpToIndex(0);
    } catch (e) {
      // 跳转失败，忽略错误
    }
  }

  /// 切换到 Stream 模式（在用户离开首页时调用）
  /// 这样后续数据变化能正常刷新，且用户看不到切换过程
  void switchToStreamMode() {
    if (_usePreloadedData) {
      // 延迟 100ms 再切换，等导航动画开始后用户看不到
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _usePreloadedData) {
          logger.info('TransactionList', '用户交互，切换到Stream模式');
          _usePreloadedData = false;
          // 开始加载标签和附件（异步，不阻塞）
          _loadTags();
          _loadAttachmentCounts();
        }
      });
    }
  }

  /// 跳转到指定月份
  bool jumpToMonth(DateTime targetMonth) {
    final monthKey =
        '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}';

    // 查找该月份的任意一天
    for (final entry in _dateIndexMap.entries) {
      if (entry.key.startsWith(monthKey)) {
        try {
          _controller.sliverController.jumpToIndex(entry.value);
          return true;
        } catch (e) {
          // 跳转失败，返回false
          return false;
        }
      }
    }

    return false; // 没有找到目标月份
  }

  /// 构建扁平化的项目列表
  void _buildFlatItems() {
    final transactions = _transactionsList;

    // 按天分组
    final dateFmt = DateFormat('yyyy-MM-dd');
    final groups = <String, List<({Transaction t, Category? category})>>{};
    for (final item in transactions) {
      final dt = item.t.happenedAt.toLocal();
      final key = dateFmt.format(DateTime(dt.year, dt.month, dt.day));
      groups.putIfAbsent(key, () => []).add(item);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    // 构建扁平的项目列表和日期索引映射
    _flatItems = <dynamic>[];
    _dateIndexMap.clear();

    for (final key in sortedKeys) {
      final list = groups[key]!;
      // 记录日期头部在扁平化列表中的索引
      _dateIndexMap[key] = _flatItems.length;
      // 添加日期头部
      _flatItems.add(('header', key, list));
      // 添加所有交易项
      for (final item in list) {
        _flatItems.add(('transaction', item, list));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听标签刷新信号，当标签变化时重新加载
    final tagRefreshVersion = ref.watch(tagListRefreshProvider);
    if (tagRefreshVersion != _lastTagRefreshVersion) {
      _lastTagRefreshVersion = tagRefreshVersion;
      // 延迟加载以避免在build中setState
      Future.microtask(() => _loadTags());
    }

    // 监听附件刷新信号，当附件变化时重新加载
    final attachmentRefreshVersion = ref.watch(attachmentListRefreshProvider);
    if (attachmentRefreshVersion != _lastAttachmentRefreshVersion) {
      _lastAttachmentRefreshVersion = attachmentRefreshVersion;
      Future.microtask(() => _loadAttachmentCounts());
    }

    _buildFlatItems();

    // 无数据时展示空状态
    if (_flatItems.isEmpty) {
      return widget.emptyWidget ??
        AppEmpty(
          text: AppLocalizations.of(context).commonEmpty,
          subtext: AppLocalizations.of(context).homeNoRecords,
        );
    }

    // 使用FlutterListView渲染列表
    return FlutterListView(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      delegate: FlutterListViewDelegate(
        (BuildContext context, int index) {
          final item = _flatItems[index];
          final type = item.$1 as String;

          if (type == 'header') {
            // 渲染日期头部
            final dateKey = item.$2 as String;
            final list = item.$3 as List<({Transaction t, Category? category})>;
            double dayIncome = 0, dayExpense = 0;
            for (final it in list) {
              // 转账和平账不计入收支统计
              if (it.t.type == 'income') {
                dayIncome += it.t.amount;
              }
              if (it.t.type == 'expense') {
                dayExpense += it.t.amount;
              }
            }
            final isFirst = index == 0;

            Widget header = Column(
              children: [
                if (!isFirst && BeeTokens.cardInnerDividerHeight(context) > 0)
                  Divider(
                    height: BeeTokens.cardInnerDividerHeight(context),
                    color: BeeTokens.cardInnerDividerColor(context),
                  ),
                DaySectionHeader(
                  dateText: dateKey,
                  income: dayIncome,
                  expense: dayExpense,
                  hide: widget.hideAmounts,
                ),
              ],
            );

            // 如果启用可见性跟踪，则包装VisibilityDetector
            if (widget.enableVisibilityTracking && widget.onDateVisibilityChanged != null) {
              header = VisibilityDetector(
                key: Key('header-$dateKey'),
                onVisibilityChanged: (VisibilityInfo info) {
                  // 当可见比例大于50%时认为可见
                  widget.onDateVisibilityChanged!(dateKey, info.visibleFraction > 0.5);
                },
                child: header,
              );
            }

            return header;
          } else {
            // 渲染交易项
            final it = item.$2 as ({Transaction t, Category? category});
            final allItemsInDay = item.$3 as List<({Transaction t, Category? category})>;
            final isTransfer = it.t.type == 'transfer';
            final isExpense = it.t.type == 'expense';

            // 获取分类显示名称
            final categoryName = CategoryUtils.getDisplayName(it.category?.name, context);

            final subtitle = it.t.note ?? '';

            // 检查是否是当天最后一项
            final isLastInGroup = allItemsInDay.last.t.id == it.t.id;

            // 获取账户名称（仅在账户功能启用且有账户ID时）
            final accountFeatureEnabled = ref.watch(accountFeatureEnabledProvider).valueOrNull ?? true;
            String? accountName;
            String? toAccountName; // 转账目标账户名称

            if (accountFeatureEnabled && it.t.accountId != null) {
              // 优先使用预加载的账户名称
              accountName = _getAccountNameForTransaction(it.t.id);
              if (isTransfer && it.t.toAccountId != null) {
                toAccountName = _getToAccountNameForTransaction(it.t.id);
              }

              // 非预加载模式下通过 Provider 获取
              if (accountName == null && !_hasFullDetails) {
                final accountAsync = ref.watch(accountByIdProvider(it.t.accountId!));
                accountName = accountAsync.valueOrNull?.name;
              }
              if (isTransfer && toAccountName == null && !_hasFullDetails && it.t.toAccountId != null) {
                final toAccountAsync = ref.watch(accountByIdProvider(it.t.toAccountId!));
                toAccountName = toAccountAsync.valueOrNull?.name;
              }
            }

            return Dismissible(
              key: Key('tx-${it.t.id}-$index'), // 添加索引避免key冲突
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await AppDialog.confirm<bool>(
                      context,
                      title: AppLocalizations.of(context).deleteConfirmTitle,
                      message: AppLocalizations.of(context).deleteConfirmMessage,
                    ) ??
                    false;
              },
              onDismissed: (direction) async {
                final repo = ref.read(repositoryProvider);
                await repo.deleteTransaction(it.t.id);

                if (!context.mounted) return;
                final curLedger = ref.read(currentLedgerIdProvider);
                ref.invalidate(countsForLedgerProvider(curLedger));
                ref.read(statsRefreshProvider.notifier).state++;
                PostProcessor.sync(ref, ledgerId: curLedger);

                if (context.mounted) {
                  showToast(context, AppLocalizations.of(context).ledgersDeleted);
                }
              },
              child: Column(
                children: [
                  Builder(
                    builder: (context) {
                      // 获取该交易的标签（优先使用预加载数据）
                      final transactionTags = _getTagsForTransaction(it.t.id);
                      final tagsList = transactionTags
                          .map((t) => (id: t.id, name: t.name, color: t.color))
                          .toList();

                      // 转账账户信息
                      final transferAccountInfo = (accountName != null && toAccountName != null)
                          ? '$accountName → $toAccountName'
                          : null;

                      // 获取附件数量（优先使用预加载数据）
                      final attachmentCount = _getAttachmentCountForTransaction(it.t.id);

                      return TransactionListItem(
                        icon: isTransfer
                          ? Icons.swap_horiz
                          : getCategoryIconData(category: it.category, categoryName: categoryName),
                        category: isTransfer ? null : it.category,
                        title: isTransfer
                          ? (subtitle.isNotEmpty ? subtitle : AppLocalizations.of(context).transferTitle)
                          : (subtitle.isNotEmpty ? subtitle : categoryName),
                        categoryName: isTransfer
                          ? null  // 转账不显示第二行，保持布局一致
                          : (subtitle.isNotEmpty ? null : categoryName),
                        amount: it.t.amount,
                        isExpense: isExpense,
                        isTransfer: isTransfer,
                        hide: widget.hideAmounts,
                        happenedAt: it.t.happenedAt,
                        accountName: isTransfer
                          ? transferAccountInfo  // 转账始终在第三行显示账户信息
                          : accountName,
                        tags: tagsList.isNotEmpty ? tagsList : null,
                        attachmentCount: attachmentCount,
                        onAttachmentTap: attachmentCount > 0
                            ? () async {
                                switchToStreamMode(); // 用户交互，切换到 Stream 模式
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AttachmentPreviewPage.fromTransaction(
                                      transactionId: it.t.id,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        onTagTap: (tagId, tagName) async {
                          switchToStreamMode(); // 用户交互，切换到 Stream 模式
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TagDetailPage(
                                tagId: tagId,
                                tagName: tagName,
                              ),
                            ),
                          );
                        },
                        onTap: () async {
                          switchToStreamMode(); // 用户交互，切换到 Stream 模式
                          await TransactionEditUtils.editTransaction(
                            context,
                            ref,
                            it.t,
                            it.category,
                          );
                        },
                        onCategoryTap: !isTransfer && it.category?.id != null
                            ? () async {
                                switchToStreamMode(); // 用户交互，切换到 Stream 模式
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CategoryDetailPage(
                                      categoryId: it.category!.id,
                                      categoryName: categoryName,
                                    ),
                                  ),
                                );
                              }
                            : null,
                      );
                    },
                  ),
                  if (!isLastInGroup)
                    BeeDivider.short(indent: 56 + 16, endIndent: 16),
                ],
              ),
            );
          }
        },
        childCount: _flatItems.length,
      ),
    );
  }
}