import 'package:beecount_ui/beecount_ui.dart' show BeeCardTheme;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../services/system/logger_service.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/transaction_edit_utils.dart';
import '../../utils/category_utils.dart';
import '../category_icon.dart';
import '../../pages/transaction/category_detail_page.dart';
import '../../pages/transaction/transaction_detail_page.dart';
import '../../pages/tag/tag_detail_page.dart';
import '../../pages/attachment/attachment_preview_page.dart';
import '../../widgets/biz/transaction_receipt_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../services/attachment_service.dart';
import '../../utils/month_range.dart';
import '../../presentation/v4/bindings/transaction_list_metadata.dart';
import '../../models/home_transaction_preview.dart';

/// 可复用的交易列表组件
/// 支持显示分组的交易列表，包含日期头部和交易项
class TransactionList extends ConsumerStatefulWidget {
  /// 完整交易数据（含标签、附件、账户，无需二次加载）
  final List<TransactionDisplayItem>? transactionsWithDetails;

  /// 交易数据（仅含分类，需二次加载标签和附件）
  final List<
      ({
        Transaction t,
        Category? category,
        Account? account,
        Account? toAccount
      })>? transactions;

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
  final bool flatSurface;

  /// Whether the incoming collection is full. An explicit preview needs full
  /// day totals; its row count must never be used as a ledger/day aggregate.
  final bool sourceReady;
  final int? ledgerId;
  final Map<String, TransactionDayTotals>? previewDayTotals;
  final Object? sourceError;
  final bool sourceLoading;
  final VoidCallback? onRetrySource;

  const TransactionList({
    super.key,
    this.transactionsWithDetails,
    this.transactions,
    required this.hideAmounts,
    this.enableVisibilityTracking = false,
    this.onDateVisibilityChanged,
    this.emptyWidget,
    this.controller,
    this.flatSurface = false,
    this.sourceReady = true,
    this.ledgerId,
    this.previewDayTotals,
    this.sourceError,
    this.sourceLoading = false,
    this.onRetrySource,
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
  int _lastTagRefreshVersion = 0;

  // 缓存附件数量（仅用于非预加载模式）
  Map<int, int> _cachedAttachmentCounts = {};
  int _lastAttachmentRefreshVersion = 0;
  List<
      ({
        Transaction t,
        Category? category,
        Account? account,
        Account? toAccount
      })> _publishedTransactions = const [];
  List<
      ({
        Transaction t,
        Category? category,
        Account? account,
        Account? toAccount
      })>? _flatSource;
  int _detailsGeneration = 0;
  int? _activeLedgerId;
  bool _loadingDetails = false;
  Object? _detailsError;
  bool _publishedIsPreview = false;
  Map<String, TransactionDayTotals> _publishedDayTotals = const {};
  ({DateTime month, int startDay})? _pendingMonth;

  /// The published phase, distinct from whether raw full-source rows arrived.
  bool get showingPreview => _publishedIsPreview;
  int get loadedTransactionCount => _publishedTransactions.length;

  // D 方案后:不再需要 _cachedAccountNames / _cachedToAccountNames /
  // _lastSharedResourceRefreshVersion — 账户对象由 watchTransactionsWith*
  // 的 LEFT JOIN 直接挂在 tx 记录,Drift 自然响应主表变化 + SharedLedger*
  // 镜像变化。

  // 标记是否应使用预加载数据（当 Stream 数据与预加载数据不同时切换）
  bool _usePreloadedData = true;

  /// 获取统一格式的交易列表（用于内部处理）
  /// 始终使用 transactions 作为列表数据源，预加载数据只用于详情（标签、附件、账户）
  List<
      ({
        Transaction t,
        Category? category,
        Account? account,
        Account? toAccount
      })> get _transactionsList {
    return _publishedTransactions;
  }

  bool _showingTransactionActions = false;

  Future<void> _showTransactionActions(
    Transaction transaction,
    BuildContext rowContext,
  ) async {
    if (_showingTransactionActions) return;
    _showingTransactionActions = true;
    try {
      final action = await _pickTransactionAction(rowContext);
      if (action == 'detail' && mounted) {
        switchToStreamMode();
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => TransactionDetailPage(
                transactionId: transaction.id,
                ledgerId: transaction.ledgerId)));
      } else if (action == 'copy' && mounted) {
        switchToStreamMode();
        await TransactionEditUtils.copyTransaction(context, ref, transaction);
      } else if (action == 'receipt' && mounted) {
        await TransactionReceiptDialog.open(context, ref, transaction);
      }
    } catch (error, stack) {
      logger.error('TransactionList', '打开交易操作失败', error, stack);
      if (mounted) {
        showToast(
            context, AppLocalizations.of(context).transactionCopyUnavailable);
      }
    }
  }

  Future<String?> _pickTransactionAction(BuildContext rowContext) async {
    try {
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox;
      final row = rowContext.findRenderObject() as RenderBox;
      return await BeePopupMenu.showForAnchor(
        context: context,
        anchor: row.localToGlobal(Offset.zero, ancestor: overlay) & row.size,
        items: [
          BeeMenuItem.action(
            value: 'detail',
            icon: Icons.description_outlined,
            label: AppLocalizations.of(context).v4TransactionDetailTitle,
          ),
          BeeMenuItem.action(
            value: 'copy',
            icon: Icons.copy_outlined,
            label: AppLocalizations.of(context).transactionCopyAction,
          ),
          BeeMenuItem.action(
            value: 'receipt',
            icon: Icons.receipt_long_outlined,
            label: AppLocalizations.of(context).transactionReceiptAction,
          ),
        ],
      );
    } finally {
      _showingTransactionActions = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? FlutterListViewController();
    _refreshDetails();
  }

  List<({Transaction t, Category? category, Account? account, Account? toAccount})>
      get _incomingTransactions =>
          widget.transactions ??
          widget.transactionsWithDetails
              ?.map((item) => (
                    t: item.t,
                    category: item.category,
                    account: item.account,
                    toAccount: item.toAccount,
                  ))
              .toList(growable: false) ??
          const [];

  @override
  void didUpdateWidget(covariant TransactionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceReady != widget.sourceReady ||
        oldWidget.previewDayTotals != widget.previewDayTotals ||
        oldWidget.ledgerId != widget.ledgerId ||
        oldWidget.transactionsWithDetails != widget.transactionsWithDetails ||
        !_sameRows(oldWidget.transactions, widget.transactions)) {
      _refreshDetails();
    }
  }

  bool _sameRows(List<dynamic>? previous, List<dynamic>? current) {
    if (identical(previous, current)) return true;
    if (previous == null ||
        current == null ||
        previous.length != current.length) {
      return false;
    }
    for (var i = 0; i < previous.length; i++) {
      if (previous[i] != current[i]) return false;
    }
    return true;
  }

  /// Keep a same-ledger complete snapshot visible during refresh. A new ledger
  /// can never receive the old ledger's data or a late metadata response.
  Future<void> _refreshDetails({bool force = false}) async {
    final generation = ++_detailsGeneration;
    final incoming = List.of(_incomingTransactions, growable: false);
    final ledger = widget.ledgerId ?? incoming.firstOrNull?.t.ledgerId;
    if (_activeLedgerId != ledger) {
      _activeLedgerId = ledger;
      _publishedTransactions = const [];
      _cachedTagsMap = {};
      _cachedAttachmentCounts = {};
      _publishedDayTotals = const {};
      _publishedIsPreview = false;
      _pendingMonth = null;
    }
    _detailsError = null;
    _loadingDetails = true;
    if (mounted) setState(() {});
    if (!widget.sourceReady && widget.previewDayTotals == null) return;
    final tags = <int, List<Tag>>{};
    final counts = <int, int>{};
    final missing = incoming.map((row) => row.t.id).toSet();
    // Complete cached row details can avoid reads. A limited preview is only
    // publishable with separately supplied full-day totals; it never owns counts.
    if (_usePreloadedData && !force && _publishedTransactions.isEmpty) {
      final current = {for (final row in incoming) row.t.id: row.t};
      for (final cached in widget.transactionsWithDetails ??
          const <TransactionDisplayItem>[]) {
        if (current[cached.t.id] == cached.t && missing.remove(cached.t.id)) {
          tags[cached.t.id] = cached.tags;
          counts[cached.t.id] = cached.attachmentCount;
        }
      }
    }
    try {
      if (missing.isNotEmpty) {
        final repo = ref.read(repositoryProvider);
        final result = await readTransactionListMetadata(
            transactionIds: missing.toList(growable: false),
            isCurrent: () => mounted && generation == _detailsGeneration,
            readTags: repo.getTagsForTransactions,
            readAttachmentCounts: repo.getAttachmentCountsForTransactions);
        tags.addAll(result.tags);
        counts.addAll(result.attachments);
      }
      if (!mounted || generation != _detailsGeneration) return;
      setState(() {
        _publishedTransactions = List.unmodifiable(incoming);
        _cachedTagsMap = tags;
        _cachedAttachmentCounts = counts;
        _loadingDetails = false;
        _detailsError = null;
        _publishedIsPreview = !widget.sourceReady;
        _publishedDayTotals =
            _publishedIsPreview ? Map.of(widget.previewDayTotals!) : const {};
      });
      if (!_publishedIsPreview && _pendingMonth != null) {
        final pending = _pendingMonth!;
        _pendingMonth = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) jumpToMonth(pending.month, startDay: pending.startDay);
        });
      }
    } catch (error, stack) {
      if (!mounted || generation != _detailsGeneration) return;
      logger.error('TransactionList', '加载完整交易信息失败', error, stack);
      setState(() {
        _loadingDetails = false;
        _detailsError = error;
      });
    }
  }

  List<Tag> _getTagsForTransaction(int transactionId) =>
      _cachedTagsMap[transactionId] ?? const [];

  int _getAttachmentCountForTransaction(int transactionId) =>
      _cachedAttachmentCounts[transactionId] ?? 0;

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

  /// Leaving the page permits revalidation, but never makes a visible row
  /// temporarily lose its tags/attachments while the fresh reads are pending.
  void switchToStreamMode() {
    if (!_usePreloadedData) return;
    _usePreloadedData = false;
    _refreshDetails(force: true);
  }

  void forceStreamModeImmediate() {
    if (!mounted) return;
    _usePreloadedData = false;
    _refreshDetails(force: true);
  }

  /// 跳转到指定周期标签月(按账本起始日的周期范围匹配,而非 yyyy-MM 前缀)
  bool jumpToMonth(DateTime targetMonth, {int startDay = 1}) {
    final range = periodForLabel(targetMonth.year, targetMonth.month, startDay);

    // 查找该周期内的任意一天
    for (final entry in _dateIndexMap.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      final d = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      if (!d.isBefore(range.start) && d.isBefore(range.end)) {
        try {
          _controller.sliverController.jumpToIndex(entry.value);
          return true;
        } catch (e) {
          // 跳转失败，返回false
          return false;
        }
      }
    }

    if (_publishedIsPreview || !widget.sourceReady || _loadingDetails) {
      _pendingMonth = (month: targetMonth, startDay: startDay);
    }
    return false; // 没有找到目标月份
  }

  /// 构建扁平化的项目列表
  void _buildFlatItems() {
    final transactions = _transactionsList;
    if (identical(_flatSource, transactions)) return;
    _flatSource = transactions;

    // 按天分组
    final dateFmt = DateFormat('yyyy-MM-dd');
    final groups = <String,
        List<
            ({
              Transaction t,
              Category? category,
              Account? account,
              Account? toAccount
            })>>{};
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

    // 底部留白，避免被悬浮 Tab 栏遮挡
    if (_flatItems.isNotEmpty) {
      _flatItems.add(('loadStatus', null, null));
      _flatItems.add(('bottomSpacer', null, null));
    }
  }

  @override
  Widget build(BuildContext context) {
    // A relationship refresh is one snapshot, never two independent paints.
    final tagVersion = ref.watch(tagListRefreshProvider);
    final attachmentVersion = ref.watch(attachmentListRefreshProvider);
    if (tagVersion != _lastTagRefreshVersion ||
        attachmentVersion != _lastAttachmentRefreshVersion) {
      _lastTagRefreshVersion = tagVersion;
      _lastAttachmentRefreshVersion = attachmentVersion;
      Future.microtask(() {
        if (mounted) _refreshDetails(force: true);
      });
    }

    // D 方案后:不再 watch sharedResourceRefreshProvider 触发 _loadAccountNames
    // —— account / toAccount 由 Drift JOIN + SharedLedger* table-watch 自动
    // 推送,UI 直接读 it.account?.name。

    _buildFlatItems();

    if (_flatItems.isEmpty &&
        (_detailsError != null || widget.sourceError != null)) {
      final l = AppLocalizations.of(context);
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l.commonError),
        TextButton(onPressed: _retry, child: Text(l.v4RecordingRetry)),
      ]));
    }
    if (_flatItems.isEmpty && (_loadingDetails || !widget.sourceReady)) {
      return const Center(
          child: SizedBox.square(
              dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    // 无数据时展示空状态
    if (_flatItems.isEmpty) {
      return widget.emptyWidget ??
          AppEmpty(
            text: AppLocalizations.of(context).commonEmpty,
            subtext: AppLocalizations.of(context).homeNoRecords,
          );
    }

    // 使用FlutterListView渲染列表
    final list = FlutterListView(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      delegate: FlutterListViewDelegate(
        (BuildContext context, int index) {
          final item = _flatItems[index];
          final type = item.$1 as String;

          if (type == 'loadStatus') return _buildLoadStatus(context);

          if (type == 'bottomSpacer') {
            // 悬浮 Tab 栏高度(56) + 浮动间距(12) + 安全区 + 额外间距
            final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
            return SizedBox(height: 56 + 12 + bottomPadding + 16);
          }

          if (type == 'header') {
            // 渲染日期头部
            final dateKey = item.$2 as String;
            final list = item.$3 as List<
                ({
                  Transaction t,
                  Category? category,
                  Account? account,
                  Account? toAccount
                })>;
            double dayIncome = 0, dayExpense = 0;
            for (final it in list) {
              // 转账不计入收支统计
              if (it.t.type == 'income') {
                dayIncome += it.t.nativeAmount ?? it.t.amount;
              }
              if (it.t.type == 'expense') {
                dayExpense += it.t.nativeAmount ?? it.t.amount;
              }
            }
            if (_publishedIsPreview) {
              final complete = _publishedDayTotals[dateKey]!;
              dayIncome = complete.income;
              dayExpense = complete.expense;
            }
            final isFirst = index == 0;

            Widget header = Column(
              children: [
                if (!isFirst) const SizedBox(height: 10),
                DaySectionHeader(
                  dateText: dateKey,
                  income: dayIncome,
                  expense: dayExpense,
                  hide: widget.hideAmounts,
                  flatSurface: widget.flatSurface,
                ),
              ],
            );

            // 如果启用可见性跟踪，则包装VisibilityDetector
            if (widget.enableVisibilityTracking &&
                widget.onDateVisibilityChanged != null) {
              header = VisibilityDetector(
                key: Key('header-$dateKey'),
                onVisibilityChanged: (VisibilityInfo info) {
                  // 当可见比例大于50%时认为可见
                  widget.onDateVisibilityChanged!(
                      dateKey, info.visibleFraction > 0.5);
                },
                child: header,
              );
            }

            return header;
          } else {
            // 渲染交易项
            final it = item.$2 as ({
              Transaction t,
              Category? category,
              Account? account,
              Account? toAccount
            });
            final allItemsInDay = item.$3 as List<
                ({
                  Transaction t,
                  Category? category,
                  Account? account,
                  Account? toAccount
                })>;
            final isTransfer = it.t.type == 'transfer';
            final isExpense = it.t.type == 'expense';

            // 获取分类显示名称
            final categoryName =
                CategoryUtils.getDisplayName(it.category?.name, context);

            final subtitle = it.t.note ?? '';

            // 检查是否是当天最后一项
            final isLastInGroup = allItemsInDay.last.t.id == it.t.id;

            // 账户名 — D 方案:account / toAccount 已经由 watchTransactionsWith*
            // 的 LEFT JOIN(+ SharedLedger* hydration)直接挂在 tx 记录上,
            // 跟 category 同款。UI 只读 it.account?.name,Drift 自动响应主表
            // accounts 行变化 + 镜像表 sharedLedgerAccounts 变化,无需任何
            // 命令式 cache / setState / provider fallback。
            final accountFeatureEnabled =
                ref.watch(accountFeatureEnabledProvider).valueOrNull ?? true;
            String? accountName;
            String? toAccountName;
            if (accountFeatureEnabled) {
              accountName = it.account?.name;
              if (isTransfer) toAccountName = it.toAccount?.name;
            }

            return Container(
              key: Key('tx-${it.t.id}-$index'),
              margin: widget.flatSurface
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 17),
              decoration: BoxDecoration(
                  color: BeeCardTheme.of(context).surface,
                  borderRadius: BorderRadius.vertical(
                      top: !widget.flatSurface &&
                              allItemsInDay.first.t.id == it.t.id
                          ? const Radius.circular(22)
                          : Radius.zero,
                      bottom: !widget.flatSurface && isLastInGroup
                          ? const Radius.circular(22)
                          : Radius.zero)),
              clipBehavior: Clip.antiAlias,
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
                      final transferAccountInfo =
                          (accountName != null && toAccountName != null)
                              ? '$accountName → $toAccountName'
                              : null;

                      // 获取附件数量（优先使用预加载数据）
                      final attachmentCount =
                          _getAttachmentCountForTransaction(it.t.id);

                      return TransactionListItem(
                        // Flat lists inherit the frame's 15px gutter. Standalone
                        // cards start at 17px, so add 4px to match the 21px header.
                        horizontalInset: widget.flatSurface ? 0 : 4,
                        onDelete: () async {
                          final repo = ref.read(repositoryProvider);
                          await repo.deleteTransaction(it.t.id);

                          if (!context.mounted) return;
                          final curLedger = ref.read(currentLedgerIdProvider);
                          ref.invalidate(countsForLedgerProvider(curLedger));
                          ref.read(statsRefreshProvider.notifier).state++;
                          ref.read(budgetRefreshProvider.notifier).state++;
                          PostProcessor.sync(ref, ledgerId: curLedger);

                          if (context.mounted) {
                            showToast(context,
                                AppLocalizations.of(context).ledgersDeleted);
                          }
                        },
                        icon: getCategoryIconData(
                            category: it.category, categoryName: categoryName),
                        category: it.category,
                        title: isTransfer
                            ? (subtitle.isNotEmpty
                                ? subtitle
                                : AppLocalizations.of(context).transferTitle)
                            : subtitle,
                        categoryName: isTransfer ? null : categoryName,
                        amount: it.t.amount,
                        currencyCode: it.t.currencyCode,
                        nativeAmount: it.t.nativeAmount,
                        isExpense: isExpense,
                        isTransfer: isTransfer,
                        hide: widget.hideAmounts,
                        happenedAt: it.t.happenedAt,
                        accountName: isTransfer
                            ? transferAccountInfo // 转账始终在第三行显示账户信息
                            : accountName,
                        tags: tagsList.isNotEmpty ? tagsList : null,
                        attachmentCount: attachmentCount,
                        excludeFromStats: it.t.excludeFromStats,
                        excludeFromBudget: it.t.excludeFromBudget,
                        onAttachmentTap: attachmentCount > 0
                            ? () async {
                                switchToStreamMode(); // 用户交互，切换到 Stream 模式
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AttachmentPreviewPage.fromTransaction(
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
                        onLongPressStart: (_) =>
                            _showTransactionActions(it.t, context),
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
        keepPosition: true,
        onItemKey: (index) {
          final item = _flatItems[index];
          return item.$1 == 'transaction'
              ? 'transaction-${(item.$2 as TransactionRowData).t.id}'
              : '${item.$1}-${widget.ledgerId}-${item.$2}';
        },
      ),
    );
    return list;
  }

  void _retry() {
    if (widget.sourceError != null) {
      widget.onRetrySource?.call();
    }
    if (widget.sourceError == null || _detailsError != null) {
      _refreshDetails(force: true);
    }
  }

  Widget _buildLoadStatus(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_detailsError != null || widget.sourceError != null) {
      return Padding(
          key: const ValueKey('transaction-feed-error'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(l.commonError),
            TextButton(onPressed: _retry, child: Text(l.v4RecordingRetry)),
          ]));
    }
    if (_loadingDetails ||
        _publishedIsPreview ||
        !widget.sourceReady ||
        widget.sourceLoading) {
      return const Padding(
          key: ValueKey('transaction-feed-loading'),
          padding: EdgeInsets.all(16),
          child: Center(
              child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))));
    }
    return const SizedBox.shrink();
  }
}
